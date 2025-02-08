// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2024-2025 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#include "tamara/logic_graph.hpp"
#include "kernel/celltypes.h"
#include "kernel/log.h"
#include "kernel/rtlil.h"
#include "kernel/yosys_common.h"
#include "tamara/termcolour.hpp"
#include "tamara/util.hpp"
#include "tamara/voter_builder.hpp"
#include <cstdint>
#include <cstring>
#include <memory>
#include <optional>
#include <unordered_set>
#include <variant>
#include <vector>

USING_YOSYS_NAMESPACE;

using namespace tamara;

#define COLOUR(the_colour) (termcolour::colour(termcolour::Colour::the_colour).c_str())
#define RESET() (termcolour::reset().c_str())

uint32_t LogicCone::g_cone_ID = 0;
std::unordered_set<std::string> LogicCone::exploredSuccessors = {};

namespace {

//! Static message for when logRTLILName with an optional evaluates to none
const char *const NONE_MESSAGE = "None";

//! With the given map, either returns the existing value for the key "K", or the default value "def".
template <class K, class V>
constexpr V getOrDefault(const std::unordered_map<K, V> &map, const K &key, V def) {
    if (map.contains(key)) {
        return map.at(key);
    }
    return def;
}

//! An IO is simply a wire at the edge of the circuit
bool isWireIO(RTLIL::Wire *wire, const RTLILWireConnections &connections) {
    return (connections.contains(wire) && connections.at(wire).empty()) || wire->port_input
        || wire->port_output;
}

//! Returns the RTLIL ID for a TMRGraphNode::Ptr
RTLIL::IdString getNodeName(const TMRGraphNode::Ptr &ptr) {
    return getRTLILName(ptr->getRTLILObjPtr());
}

//! Override of getRTLILName that returns a char* through log_id
const char *logRTLILName(const TMRGraphNode::Ptr &ptr) {
    return log_id(getNodeName(ptr));
}

//! Override of getRTLILName that returns a char* through log_id. If the optional is not present, returns
//! "None".
const char *logRTLILName(const std::optional<TMRGraphNode::Ptr> &optional) {
    if (!optional.has_value()) {
        return NONE_MESSAGE;
    }
    return log_id(getNodeName(*optional));
}

//! Override for getRTLILName that returns a char* through log_id
const char *logRTLILName(const RTLILAnyPtr &ptr) {
    return log_id(getRTLILName(ptr));
}

//! Instantiates a new logic cone from the RTLILAnyPtr.
LogicCone newLogicCone(const RTLILAnyPtr &ptr) {
    return std::visit(
        [](auto &&arg) {
            using T = std::decay_t<decltype(arg)>;
            if constexpr (std::is_same_v<T, RTLIL::Cell *>) {
                // make sure we have a DFF if it's an RTLIL::Cell
                if (!isDFF(arg)) {
                    log_error(
                        "TaMaRa internal error: Tried to instantiate logic cone with a non-DFF RTLIL::Cell");
                }
                return LogicCone(arg);
            }
            if constexpr (std::is_same_v<T, RTLIL::Wire *>) {
                return LogicCone(arg);
            }
        },
        ptr);
}

//! Determines if neighbours should be added to a node during backwards BFS.
//! Currently we only add neighbours if it's NOT a IONode or FFNode (which are considered terminals).
bool shouldAddNeighbours(const TMRGraphNode::Ptr &node) {
    return dynamic_pointer_cast<IONode>(node) == nullptr && dynamic_pointer_cast<FFNode>(node) == nullptr;
}

//! Replicates the node if it's not an IONode. We can't replicate IONodes as they are inputs to the entire
//! circuit.
void replicateIfNotIO(const TMRGraphNode::Ptr &node, RTLIL::Module *module) {
    if (dynamic_pointer_cast<IONode>(node) == nullptr) {
        log("Input node %s is not IONode, replicating it\n", log_id(getNodeName(node)));
        node->replicate(module);
    } else {
        log("Input node %s is IONode, it will NOT be replicated\n", log_id(getNodeName(node)));
    }
}

/// Taking an RTLILAnyPtr that came from a call to replicate(), returns the relevant output wire associated
/// with it
RTLIL::Wire *extractReplicaWire(const RTLILAnyPtr &ptr) {
    log("extractReplicaWire(%s)\n", logRTLILName(ptr));
    return std::visit(
        [](auto &&arg) {
            using T = std::decay_t<decltype(arg)>;
            if constexpr (std::is_same_v<T, RTLIL::Cell *>) {
                RTLIL::Cell *cell = arg; // this is for the benefit of clangd
                // log("Locating output wire for %s\n", log_id(cell->name));

                CellTypes cellTypes(cell->module->design);

                for (const auto &connection : cell->connections()) {
                    const auto &[name, signal] = connection;

                    // is this the output wire?
                    if (cellTypes.cell_output(cell->type, name)) {
                        // find the wire it's connected to
                        auto *conn = sigSpecToWire(signal);
                        NOTNULL(conn);

                        // FIXME what about cells with multiple outputs?

                        // Now what we should do is make a new wire, which will be our output
                        // then rip up the existing wire and redirect it
                        // then return this wire
                        auto *wire
                            = cell->module->addWire(NEW_ID_SUFFIX("extractReplicaWire"), GetSize(signal));

                        // rip up the existing wire, and add our own
                        cell->setPort(name, wire);

                        log("Generated replacement wire '%s' for cell '%s'\n", log_id(wire->name),
                            log_id(cell->name));

                        return wire;
                    }
                }
                log_error("TaMaRa internal error: Failed to locate output wire for cell '%s'\n",
                    log_id(cell->name));
            }
            if constexpr (std::is_same_v<T, RTLIL::Wire *>) {
                // if it's just a wire, we can return that
                return dynamic_cast<RTLIL::Wire *>(arg);
            }
        },
        ptr);
}

/// Locates all the RTLIL::SigChunks that may feed the given wire
std::vector<RTLIL::SigChunk> findAttachedSigChunks(RTLIL::Wire *wire) {
    std::vector<RTLIL::SigChunk> out;

    // first, let's check all global module connections
    for (const auto &conn : wire->module->connections()) {
        const auto &[lhs, rhs] = conn;

        // look for SigBits, being careful that they're not const (otherwise the wire ptr is null)
        if (lhs.is_chunk() && !lhs.is_fully_const()) {
            // we found that the LHS is a SigBit, does it refer to this wire?
            NOTNULL(lhs.as_chunk().wire);
            if (lhs.as_chunk().wire == wire) {
                // FIXME is this the correct side?
                out.push_back(lhs.as_chunk());
            }
        }
    }

    // no luck with global module connections, we're going to need to check each cell individually
    for (const auto &cell : wire->module->cells()) {
        CellTypes cellTypes(wire->module->design);

        for (const auto &conn : cell->connections()) {
            const auto &[name, signal] = conn;

            // look for SigBit, being careful that they're not const (otherwise the wire ptr is null)
            if (signal.is_chunk() && !signal.is_fully_const()) {
                NOTNULL(signal.as_chunk().wire);
                if (signal.as_chunk().wire == wire) {
                    out.push_back(signal.as_chunk());
                }
            }
        }
    }

    return out;
}

} // namespace

TMRGraphNode::Ptr TMRGraphNode::newLogicGraphNeighbour(const RTLILAnyPtr &ptr,
    const RTLILWireConnections &connections, const std::optional<RTLIL::SigSpec> &sigSpec) const {
    // based on example 3 of https://en.cppreference.com/w/cpp/utility/variant/visit
    auto localId = id;
    return std::visit(
        [&, localId](auto &&arg) {
            using T = std::decay_t<decltype(arg)>;
            if constexpr (std::is_same_v<T, RTLIL::Cell *>) {
                // my god this is ugly, we need to check if it's a DFF as well
                if (isDFF(arg)) {
                    return static_cast<TMRGraphNode::Ptr>(std::make_shared<FFNode>(arg, localId));
                }
                return static_cast<TMRGraphNode::Ptr>(std::make_shared<ElementCellNode>(arg, localId));
            }
            if constexpr (std::is_same_v<T, RTLIL::Wire *>) {
                if (!sigSpec.has_value()) {
                    log_warning("No SigSpec passed with wire '%s' to newLogicGraphNeighbour. This may cause "
                                "problems later.\n",
                        log_id(arg->name));
                }
                if (isWireIO(arg, connections)) {
                    // this is actually an IO
                    return static_cast<TMRGraphNode::Ptr>(std::make_shared<IONode>(arg, localId));
                }
                // it's a wire, but just a regular element node -> not an IO
                return static_cast<TMRGraphNode::Ptr>(std::make_shared<ElementWireNode>(arg, localId));
            }
        },
        ptr);
}

void ElementCellNode::replicate(RTLIL::Module *module) {
    log("    Replicating %s %s\n", identify().c_str(), log_id(cell->name));
    if (cell->has_attribute(CONE_ANNOTATION)) {
        log_warning("When replicating %s %s in cone %u: Already replicated in logic cone %s\n",
            identify().c_str(), log_id(cell->name), getConeID(),
            cell->get_string_attribute(CONE_ANNOTATION).c_str());
    }

    auto id = std::to_string(getConeID());

    auto *replica1 = module->addCell(NEW_ID_SUFFIX(cell->name.str() + "__replica1_cone" + id + "__"), cell);
    auto *replica2 = module->addCell(NEW_ID_SUFFIX(cell->name.str() + "__replica2_cone" + id + "__"), cell);

    replica1->set_string_attribute(CONE_ANNOTATION, id);
    replica2->set_string_attribute(CONE_ANNOTATION, id);
    cell->set_string_attribute(CONE_ANNOTATION, id);

    cell->set_bool_attribute(ORIGINAL_ANNOTATION);

    cell->check();
    replica1->check();
    replica2->check();
    module->check();

    replicas.push_back(replica1);
    replicas.push_back(replica2);
}

void ElementWireNode::replicate(RTLIL::Module *module) {
    log("    Replicating ElementWireNode %s\n", log_id(wire->name));
    if (wire->has_attribute(CONE_ANNOTATION)) {
        log_warning("When replicating ElementWireNode %s in cone %u: Already replicated in logic cone %s\n",
            log_id(wire->name), getConeID(), wire->get_string_attribute(CONE_ANNOTATION).c_str());
    }

    auto id = std::to_string(getConeID());

    auto *replica1 = module->addWire(NEW_ID_SUFFIX(wire->name.str() + "__replica1_cone" + id + "__"), wire);
    auto *replica2 = module->addWire(NEW_ID_SUFFIX(wire->name.str() + "__replica2_cone" + id + "__"), wire);

    replica1->set_string_attribute(CONE_ANNOTATION, id);
    replica2->set_string_attribute(CONE_ANNOTATION, id);
    wire->set_string_attribute(CONE_ANNOTATION, id);

    wire->set_bool_attribute(ORIGINAL_ANNOTATION);

    module->check();

    replicas.push_back(replica1);
    replicas.push_back(replica2);
}

void IONode::replicate([[maybe_unused]] RTLIL::Module *module) {
    // this shouldn't happen since we call replicateIfNotIO
    log_error("TaMaRa internal error: Cannot replicate IO node!\n");
}

std::vector<TMRGraphNode::Ptr> TMRGraphNode::computeNeighbours(const RTLILWireConnections &connections) {
    auto obj = getRTLILObjPtr();
    auto neighbours = getOrDefault(connections, obj, std::unordered_set<RTLILAnyPtr>());
    log("    %s '%s' has %zu neighbours\n", identify().c_str(), log_id(getRTLILName(obj)), neighbours.size());

    // now, construct Yosys types into our logic graph types
    std::vector<TMRGraphNode::Ptr> out {};
    out.reserve(neighbours.size());
    for (const auto &neighbour : neighbours) {
        // we're passing nullopt here for the sigSpec, since we may not have an easy way of getting to it
        out.push_back(newLogicGraphNeighbour(neighbour, connections, std::nullopt));
    }
    return out;
}

void LogicCone::verifyInputNodes() const {
    for (const auto &node : inputNodes) {
        if (dynamic_pointer_cast<IONode>(node) == nullptr && dynamic_pointer_cast<FFNode>(node) == nullptr) {
            log_error("TaMaRa internal error: Logic cone input node should be either IONode or FFNode, but "
                      "instead it was %s %s!\n",
                node->identify().c_str(), log_id(getNodeName(node)));
        }
    }
}

void LogicCone::search(const RTLILWireConnections &connections) {
    // check that we're starting the search from scratch on this cone
    log_assert(frontier.empty());
    log_assert(cone.empty()); // NOLINT(bugprone-unused-return-value)
    log_assert(inputNodes.empty());

    frontier.push(outputNode);

    // keep track of the first node in the search, we always want to compute neighbours for this even if we
    // normally wouldn't (because it's an FFNode/IONode)
    bool first = true;

    std::unordered_set<std::string> visited;

    log("%sStarting search for cone %u%s\n", COLOUR(Blue), id, RESET());
    while (!frontier.empty()) {
        auto node = frontier.front();
        frontier.pop();
        log("    Consider %s '%s' in cone %u (%zu items remain)\n", node->identify().c_str(),
            log_id(getNodeName(node)), id, frontier.size());

        if (shouldAddNeighbours(node) || first) {
            // locate neighbours and add to BFS queue
            auto neighbours = node->computeNeighbours(connections);
            for (const auto &neighbour : neighbours) {
                std::string name = getNodeName(node).c_str();

                if (!visited.contains(name)) {
                    frontier.push(neighbour);
                    visited.insert(name);
                    // log("    Neighbour %s '%s' hash 0x%zX\n", neighbour->identify().c_str(),
                    //     log_id(getNodeName(neighbour)), std::hash<TMRGraphNode::Ptr>()(neighbour));
                }
            }

            // since this is not a terminal node, we can go ahead and add it to the cone. remember, we don't
            // want to add terminals to the cone on either its input or output.
            //
            // add to logic cone if not IO, this is because we don't want to replicate IOs, but we do
            // replicate Elements and FFs. we can't replicate IOs because they're outputs/inputs of course.
            // also don't add the first element to the cone, as it'll cause duplicates elsewhere.
            if (dynamic_pointer_cast<IONode>(node) == nullptr && !first) {
                cone.push_back(node);
                log("    %sAdd %s to cone (now has %zu items)%s\n", COLOUR(Green), node->identify().c_str(),
                    cone.size(), RESET());
            } else {
                log("    %sSkip adding %s to cone (first: %s)%s\n", COLOUR(Red), node->identify().c_str(),
                    first ? "true" : "false", RESET());
            }

            // select voter cut point: the first node that we find on the backwards BFS (not the initial node)
            if (!voterCutPoint.has_value() && !first) {
                voterCutPoint = node;
                log("    %sSet voter cut point to this node%s\n", COLOUR(Cyan), RESET());
            }
        } else {
            // found terminal, start wrapping up search -> don't add neighbours, and don't add elements to
            // cone
            log("    %s%s %s is a terminal, wrapping up search%s\n", COLOUR(Yellow), node->identify().c_str(),
                log_id(getNodeName(node)), RESET());
        }

        if (!frontier.empty()) {
            // search would continue
            log("\n");
        } else {
            // we're terminating search
            inputNodes.push_back(node);
        }

        first = false;
    }

    verifyInputNodes();
    log("%sSearch complete for cone %u, have %zu items\n%s", COLOUR(Blue), id, cone.size(), RESET());
}

void LogicCone::replicate(RTLIL::Module *module) {
    // don't replicate cones that don't have any internal elements (prevents duplication)
    if (cone.empty()) {
        log("%sCone %u has no internal elements - skipping replication%s\n", COLOUR(Red), id, RESET());
        return;
    }
    log_assert(frontier.empty() && "Search might not be finished");

    log("%sReplicating %zu collected items for logic cone %u%s\n", COLOUR(Blue), cone.size(), id, RESET());
    for (const auto &item : cone) {
        item->replicate(module);
    }

    // special case for end points (IOs and FFs) -> only replicate FFs, don't replicate IOs
    log("%sChecking terminals%s\n", COLOUR(Cyan), RESET());
    for (const auto &node : inputNodes) {
        replicateIfNotIO(node, module);
    }
    replicateIfNotIO(outputNode, module);
}

std::optional<RTLIL::Wire *> LogicCone::insertVoter(
    VoterBuilder &builder, const std::vector<RTLILAnyPtr> &replicas) {
    log("%sInserting voter into logic cone %u%s\n", COLOUR(Blue), id, RESET());
    if (cone.empty()) {
        log("%sSkipping voter insertion into cone %u - internal elements empty%s\n", COLOUR(Red), id,
            RESET());
        return std::nullopt;
    }

    log("Going to splice voter between LogicCone output %s and cut point %s\n", logRTLILName(outputNode),
        logRTLILName(voterCutPoint));

    log("out_w voterCutPoint\n");
    // NOTE: It is VERY important that out_w runs first, otherwise the wires are not connected correctly (c
    // gets overwritten basically)
    auto *out_w = extractReplicaWire(voterCutPoint->get()->getRTLILObjPtr());
    log("a_w replicas[0]\n");
    auto *a_w = extractReplicaWire(replicas.at(0));
    log("b_w replicas[1]\n");
    auto *b_w = extractReplicaWire(replicas.at(1));
    log("c_w replicas[2]\n");
    auto *c_w = extractReplicaWire(replicas.at(2));
    builder.build(a_w, b_w, c_w, out_w);

    return out_w;
}

void LogicCone::wire(RTLIL::Module *module, std::optional<Wire *> errorSink,
    RTLILWireConnections &connections, VoterBuilder &builder) {
    log("%sWiring logic cone %u%s\n", COLOUR(Blue), id, RESET());
    if (cone.empty()) {
        // TODO in this case, we probably will have wiring to do, just not to the voter
        log("%sSkipping wiring of cone %u - internal elements empty%s\n", COLOUR(Red), id, RESET());
        return;
    }

    // connect voter between output and firstReplicated
    log_assert(voterCutPoint.has_value() && "Voter cut point not set!");
    auto replicas = voterCutPoint->get()->getReplicas();
    log_assert(replicas.size() == 2 && "Expected 2 replicas");

    // we also add the original node to the list of replicas, so that we can connect it up to the voter
    // since we already have one original node, + 2 replicas, this is a total of 3 :)
    // this is a little bit confusing for the terminology since it's not _technically_ a replica
    replicas.push_back(voterCutPoint->get()->getRTLILObjPtr());

    // handle voter insertion
    auto voterOutWire = insertVoter(builder, replicas);

    // connected output wire
    if (voterOutWire.has_value()) {
        log("Connecting cone output '%s' to voter output '%s'\n", logRTLILName(outputNode),
            log_id(voterOutWire.value()->name));

        // FIXME sketchy std::get call (this breaks in shiftreg.ys)
        // specifically it seems to fail if there are multiple logic cones, so we need to think about what we
        // do here (tracked as #22)
        auto *outNodeWire = std::get<Wire *>(outputNode->getRTLILObjPtr());
        DUMP_RTLIL;
        DUMP;

        // TODO what we need here is a copy of the original connection data
        // maybe we DO need RTLILSignalConnections, but as an entirely separate thing?
        // we need to know what bits were ORIGINALLY connected from, in crc_min, $xor -> out

        // check if we have an attached SigChunk (see https://github.com/mattyoung101/tamara/issues/13)
        // in that case, special wiring will be required
        auto attachedSigChunks = findAttachedSigChunks(outNodeWire);
        if (!attachedSigChunks.empty()) {
            log("Special wiring required (outNodeWire '%s' has %zu attached SigChunks)\n",
                log_id(outNodeWire->name), attachedSigChunks.size());

            // now, we need to determine if we have enough free SigBits to wire in our voter signal
            auto potentiallyFreeSigChunks = outNodeWire->width - attachedSigChunks.size();
            if (potentiallyFreeSigChunks != static_cast<size_t>(voterOutWire.value()->width)) {
                log_error("TaMaRa internal error: Unable to find enough free SigChunks to route voter signal "
                          "to output wire '%s'. Required %d, but have %zu potentially free. This may be user "
                          "error.\n",
                    log_id(outNodeWire->name), voterOutWire.value()->width, potentiallyFreeSigChunks);
            }

            TODO;

            // TODO one additional problem is that we need to not just route the wire to a "free" SigBit, but
            // to the CORRECT SigBit.

            // what we might be able to do is just to connect the voter signal to the bit which is NOT taken?
            // how do we do that?
        } else {
            log("Using regular wiring\n");
            module->connect(outNodeWire, voterOutWire.value());
        }
    } else {
        log("No voter inserted (cone probably empty), skipping output connection\n");
    }
    module->check();

    // now, clean up by running the FixWalkers
    log("\n%sFixing up wiring%s\n", COLOUR(Blue), RESET());
    fixWalkers.execute(module);
}

std::vector<LogicCone> LogicCone::buildSuccessors(const RTLILWireConnections &connections) {
    log("%sConsidering potential successors for cone %u%s\n", COLOUR(Blue), id, RESET());
    std::vector<LogicCone> out {};
    // reserve worst-case size, minor performance improvement?
    out.reserve(inputNodes.size());

    for (const auto &node : inputNodes) {
        std::string name = getNodeName(node).c_str();
        log("Considering %s %s as a successor cone... ", node->identify().c_str(), name.c_str());

        // check if it has a neighbour that we haven't already made a cone out of yet
        if (connections.contains(node->getRTLILObjPtr()) && connections.at(node->getRTLILObjPtr()).size() > 0
            && !exploredSuccessors.contains(name)) {
            // we have neighbours, this is a valid successor
            log("%sConfirmed.%s\n", COLOUR(Green), RESET());
            out.push_back(newLogicCone(node->getRTLILObjPtr()));
            exploredSuccessors.insert(name);
        } else {
            log("%sHas no additional neighbours, not a valid successor.%s\n", COLOUR(Red), RESET());
        }
    }

    return out;
}
