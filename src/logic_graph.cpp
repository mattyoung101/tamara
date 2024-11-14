// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2024 Matt Young.
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
#include <memory>
#include <variant>

USING_YOSYS_NAMESPACE;

using namespace tamara;

#define COLOUR(the_colour) (termcolour::colour(termcolour::Colour::the_colour).c_str())
#define RESET() (termcolour::reset().c_str())

uint32_t LogicCone::g_cone_ID = 0;

namespace {

//! Static message for when logRTLILName with an optional evaluates to none
const char *const NONE_MESSAGE = "None";

//! An IO is simply a wire at the edge of the circuit
constexpr bool isWireIO(RTLIL::Wire *wire, RTLILWireConnections &connections) {
    return connections[wire].empty() || wire->port_input || wire->port_output;
}

//! Returns the RTLIL ID for a RTLILAnyPtr
RTLIL::IdString getRTLILName(const RTLILAnyPtr &ptr) {
    return std::visit(
        [](auto &&arg) {
            using T = std::decay_t<decltype(arg)>;
            if constexpr (std::is_same_v<T, RTLIL::Cell *>) {
                return arg->name;
            }
            if constexpr (std::is_same_v<T, RTLIL::Wire *>) {
                return arg->name;
            }
        },
        ptr);
}

//! Returns the RTLIL ID for a TMRGraphNode::Ptr
RTLIL::IdString getRTLILName(const TMRGraphNode::Ptr &ptr) {
    return getRTLILName(ptr->getRTLILObjPtr());
}

//! Override of getRTLILName that returns a char* through log_id
const char *logRTLILName(const TMRGraphNode::Ptr &ptr) {
    return log_id(getRTLILName(ptr));
}

//! Override of getRTLILName that returns a char* through log_id. If the optional is not present, returns
//! "None".
const char *logRTLILName(const std::optional<TMRGraphNode::Ptr> &optional) {
    if (!optional.has_value()) {
        return NONE_MESSAGE;
    }
    return log_id(getRTLILName(*optional));
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
                log_assert(isDFF(arg));
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
inline bool shouldAddNeighbours(const TMRGraphNode::Ptr &node) {
    return dynamic_pointer_cast<IONode>(node) == nullptr && dynamic_pointer_cast<FFNode>(node) == nullptr;
}

//! Replicates the node if it's not an IONode. We can't replicate IONodes as they are inputs to the entire
//! circuit.
void replicateIfNotIO(const TMRGraphNode::Ptr &node, RTLIL::Module *module) {
    if (dynamic_pointer_cast<IONode>(node) == nullptr) {
        log("Input node %s is not IONode, replicating it\n", log_id(getRTLILName(node)));
        node->replicate(module);
    } else {
        log("Input node %s is IONode, it will NOT be replicated\n", log_id(getRTLILName(node)));
    }
}

//! Connects the given replica port to the voter port, in the context of the module.
void connect(RTLIL::Module *module, const RTLILAnyPtr &replica, RTLIL::Wire *voter) {
    // Impl note: This could also be part of voter_builder, but I decided to keep it here because I want all
    // of the RTLILAnyPtr crap to be contained within this file.

    CellTypes cellTypes(module->design);

    std::visit(
        [&, cellTypes](auto &&arg) {
            using T = std::decay_t<decltype(arg)>;
            if constexpr (std::is_same_v<T, RTLIL::Cell *>) {
                // this re-declaration is mainly for the benefit of clangd
                RTLIL::Cell *cell = arg;

                // locate output port
                bool foundOutput = false;
                for (const auto &connection : cell->connections()) {
                    auto [idString, sigSpec] = connection;

                    // determine if output port
                    if (cellTypes.cell_output(cell->type, idString)) {
                        // found it
                        if (foundOutput) {
                            log_error("Cell %s has multiple output ports! Connection may not be handled "
                                      "correctly!\n",
                                log_id(cell->name));
                        }
                        foundOutput = true;

                        log("connect: Changing output connection %s\n in RTLILAnyPtr(Wire*) %s\n to voter "
                            "wire "
                            "%s\n",
                            log_id(idString), log_id(cell->name), log_id(voter->name));
                        cell->setPort(idString, voter);
                        cell->check();
                    }
                }
            }
            if constexpr (std::is_same_v<T, RTLIL::Wire *>) {
                // this re-declaration is mainly for the benefit of clangd
                RTLIL::Wire *wire = arg;
                log("connect: Creating connection between wire %s -> voter %s\n", log_id(wire->name),
                    log_id(voter->name));
                module->connect(wire, voter);
            }
        },
        replica);

    module->check();
}

//! RTLILWireConnections maps a -> (b, c, d, e); but what this function does is find "a" given say b, or c, or
//! d. Returns empty list if no results found.
//! Note: This is REALLY expensive currently on the order of O(n^2).
std::vector<RTLILAnyPtr> rtlilInverseLookup(RTLILWireConnections &connections, Wire *target) {
    std::vector<RTLILAnyPtr> out;
    for (const auto &pair : connections) {
        const auto &[key, value] = pair;
        for (const auto &item : value) {
            // TODO this currently only checks cells, but maybe we want wires too?
            if (std::holds_alternative<Cell*>(item) && std::get<Cell*>(item)->name == target->name) {
                out.push_back(key);
            }
        }
    }
    return out;
}

} // namespace

TMRGraphNode::Ptr TMRGraphNode::newLogicGraphNeighbour(
    const RTLILAnyPtr &ptr, RTLILWireConnections &connections) {
    // based on example 3 of https://en.cppreference.com/w/cpp/utility/variant/visit
    auto localId = id;
    auto selfPtr = getSelfPtr();
    return std::visit(
        [&, localId, selfPtr](auto &&arg) {
            using T = std::decay_t<decltype(arg)>;
            if constexpr (std::is_same_v<T, RTLIL::Cell *>) {
                // my god this is ugly, we need to check if it's a DFF as well
                if (isDFF(arg)) {
                    return static_cast<TMRGraphNode::Ptr>(std::make_shared<FFNode>(arg, selfPtr, localId));
                }
                return static_cast<TMRGraphNode::Ptr>(
                    std::make_shared<ElementCellNode>(arg, selfPtr, localId));
            }
            if constexpr (std::is_same_v<T, RTLIL::Wire *>) {
                if (isWireIO(arg, connections)) {
                    // this is actually an IO
                    return static_cast<TMRGraphNode::Ptr>(std::make_shared<IONode>(arg, selfPtr, localId));
                }
                // it's a wire, but just a regular element node -> not an IO
                return static_cast<TMRGraphNode::Ptr>(
                    std::make_shared<ElementWireNode>(arg, selfPtr, localId));
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

std::vector<TMRGraphNode::Ptr> TMRGraphNode::computeNeighbours(
    RTLIL::Module *module, RTLILWireConnections &connections) {
    auto obj = getRTLILObjPtr();
    auto neighbours = connections[obj];
    log("    %s '%s' has %zu neighbours\n", identify().c_str(), log_id(getRTLILName(obj)), neighbours.size());

    // now, construct Yosys types into our logic graph types
    std::vector<TMRGraphNode::Ptr> out {};
    for (const auto &neighbour : neighbours) {
        out.push_back(newLogicGraphNeighbour(neighbour, connections));
    }
    return out;
}

void LogicCone::verifyInputNodes() const {
    for (const auto &node : inputNodes) {
        if (dynamic_pointer_cast<IONode>(node) == nullptr && dynamic_pointer_cast<FFNode>(node) == nullptr) {
            log_error("TaMaRa internal error: Logic cone input node should be either IONode or FFNode, but "
                      "instead it was %s %s!\n",
                node->identify().c_str(), log_id(getRTLILName(node)));
        }
    }
}

std::vector<RTLILAnyPtr> LogicCone::collectReplicasRTLIL(const RTLILAnyPtr &obj) {
    std::vector<TMRGraphNode::Ptr> allObjects;
    allObjects.reserve(cone.size() + inputNodes.size());
    for (const auto &element : cone) {
        allObjects.push_back(element);
    }
    for (const auto &element : inputNodes) {
        allObjects.push_back(element);
    }
    allObjects.push_back(outputNode);

    for (const auto &element : allObjects) {
        // log("check if %s == %s\n", logRTLILName(element), logRTLILName(obj));
        if (getRTLILName(element) == getRTLILName(obj)) {
            return element->getReplicas();
        }
    }
    log_error("TaMaRa internal error: Unable to find any replicas for RTLIL object %s in cone %d!\n",
        logRTLILName(obj), id);
}

void LogicCone::search(RTLIL::Module *module, RTLILWireConnections &connections) {
    // check that we're starting the search from scratch on this cone
    log_assert(frontier.empty());
    log_assert(cone.empty()); // NOLINT(bugprone-unused-return-value)
    log_assert(inputNodes.empty());

    frontier.push(outputNode);

    // keep track of the first node in the search, we always want to compute neighbours for this even if we
    // normally wouldn't (because it's an FFNode/IONode)
    bool first = true;

    log("%sStarting search for cone %u%s\n", COLOUR(Blue), id, RESET());
    while (!frontier.empty()) {
        auto node = frontier.front();
        frontier.pop();
        log("    Consider %s '%s' in cone %u (%zu items remain)\n", node->identify().c_str(),
            log_id(getRTLILName(node)), id, frontier.size());

        if (shouldAddNeighbours(node) || first) {
            // locate neighbours and add to BFS queue
            auto neighbours = node->computeNeighbours(module, connections);
            for (const auto &neighbour : neighbours) {
                frontier.push(neighbour);
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
                log_id(getRTLILName(node)), RESET());
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

void LogicCone::insertVoter(RTLIL::Module *module) {
    log("%sInserting voter into logic cone %u%s\n", COLOUR(Blue), id, RESET());
    log_assert(!voter.has_value() && "Cone already has a voter!");
    if (cone.empty()) {
        log("%sSkipping voter insertion into cone %u - internal elements empty%s\n", COLOUR(Red), id,
            RESET());
        return;
    }

    voter = VoterBuilder::build(module);
}

void LogicCone::wire(
    RTLIL::Module *module, std::optional<Wire *> errorSink, RTLILWireConnections &connections) {
    log("%sWiring logic cone %u%s\n", COLOUR(Blue), id, RESET());
    if (cone.empty()) {
        // TODO in this case, we probably will have wiring to do, just not to the voter
        log("%sSkipping wiring of cone %u - internal elements empty%s\n", COLOUR(Red), id, RESET());
        return;
    }

    // connect voter between output and firstReplicated
    log_assert(voter.has_value() && "Voter not yet inserted!");
    log_assert(voterCutPoint.has_value() && "Voter cut point not set!");

    log("Going to splice voter between LogicCone output %s and cut point %s\n", logRTLILName(outputNode),
        logRTLILName(voterCutPoint));

    auto replicas = voterCutPoint->get()->getReplicas();
    log_assert(replicas.size() == 2 && "Unexpected replica size");

    // we also add the original node to the list of replicas, so that we can connect it up to the voter
    // since we already have one original node, + 2 replicas, this is a total of 3 :)
    // this is a little bit confusing for the terminology since it's not _technically_ a replica
    replicas.push_back(voterCutPoint->get()->getRTLILObjPtr());

    int i = 0;
    for (const auto &replica : replicas) {
        log("%sConnecting voter port %s %s %s to replica %s %s\n", COLOUR(Yellow), RESET(),
            log_id(voter.value()[i]->name), COLOUR(Yellow), RESET(), logRTLILName(replica));
        connect(module, replica, voter.value()[i]);
        i++;
    }
    module->check();

    // now, wire the cone's output node to the voter's OUT connection
    connect(module, outputNode->getRTLILObjPtr(), voter->out);

    // now, we need to track down and re-wire those wires which we replicated (currently, they will have
    // multiple drivers)
    log("%sFixing up wires we replicated (that will now have multiple drivers)%s\n", COLOUR(Cyan), RESET());
    for (const auto &element : cone) {
        auto wirePtr = std::dynamic_pointer_cast<ElementWireNode>(element);
        if (wirePtr == nullptr) {
            // not a wire
            continue;
        }

        // let's determine if this wire is actually connected to something we've replicated
        auto *wire = std::get<Wire *>(wirePtr->getRTLILObjPtr());
        auto connectedNodes = connections[wire];

        for (const auto &connected : connectedNodes) {
            // this is a cell which is connected to that wire
            // FIXME this will blow up for wire-wire connections I expect
            auto *cell = std::get<RTLIL::Cell *>(connected);

            // if the cell has a (* tamara_cone *) annotation, it's been touched by replicate()
            if (cell->has_attribute(CONE_ANNOTATION)) {
                log("Found replicated cell '%s' connected to wire node '%s'\n", log_id(cell->name),
                    log_id(wire->name));

                // now we can collect replicas for the cell, and replicas for the wire, and tie them together!
                auto cellReplicas = collectReplicasRTLIL(cell);
                auto wireReplicas = element->getReplicas();

                log_assert(cellReplicas.size() == wireReplicas.size()
                    && "Cannot pair cell replicas with wire replicas!");

                // remember we just asserted that cellReplicas == wireReplicas size
                for (size_t j = 0; j < cellReplicas.size(); j++) {
                    auto *cellReplica = std::get<Cell *>(cellReplicas[j]);
                    auto *wireReplica = std::get<Wire *>(wireReplicas[j]);
                    log("Connect %s to %s\n", log_id(cellReplica->name), log_id(wireReplica->name));

                    connect(module, cellReplica, wireReplica);
                    cell->check();
                    cellReplica->check();

                    // FIXME now I think we need to connect the other side of the wire??
                    // because this makes the DFF connect to the wire, but now we need to make the wire
                    // connect to the cell
                }
            }
        }

        // now, we also need to do the reverse to connect up the other side
        log("looking for cells that connect to %s\n", log_id(wire->name));
        auto reverse = rtlilInverseLookup(connections, wire);
        for (const auto &item : reverse) {
            log("reverse for %s: %s\n", log_id(wire->name), logRTLILName(item));
        }

        module->check();
    }
}

std::vector<LogicCone> LogicCone::buildSuccessors(RTLILWireConnections &connections) {
    log("%sConsidering potential successors for cone %u%s\n", COLOUR(Blue), id, RESET());
    std::vector<LogicCone> out {};
    for (const auto &node : inputNodes) {
        log("Considering %s %s as a successor cone... ", node->identify().c_str(),
            log_id(getRTLILName(node)));

        // check if it has a neighbour
        if (connections[node->getRTLILObjPtr()].size() > 0) {
            // we have neighbours, this is a valid successor
            log("%sConfirmed.%s\n", COLOUR(Green), RESET());
            out.push_back(newLogicCone(node->getRTLILObjPtr()));
        } else {
            log("%sHas no additional neighbours, not a valid successor.%s\n", COLOUR(Red), RESET());
        }
    }

    return out;
}
