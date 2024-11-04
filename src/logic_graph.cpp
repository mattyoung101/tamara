// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2024 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#include "tamara/logic_graph.hpp"
#include "kernel/log.h"
#include "kernel/rtlil.h"
#include "kernel/yosys_common.h"
#include "tamara/util.hpp"
#include "tamara/voter_builder.hpp"
#include <cstdint>
#include <memory>
#include <variant>

USING_YOSYS_NAMESPACE;

using namespace tamara;

uint32_t LogicCone::g_cone_ID = 0;

namespace {

//! An IO is simply a wire with no neighbours (since it should be at the edge of the circuit)
constexpr bool isWireIO(RTLIL::Wire *wire, RTLILWireConnections &connections) {
    // FIXME this check is broken, we need to check if the wire is an output/input of the module as well
    // this is what causes #1 on the github
    return connections[wire].empty();
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

//! Returns the RTLIL ID for a TMRGraphNode::Ptr
RTLIL::IdString getRTLILName(const TMRGraphNode::Ptr &ptr) {
    return getRTLILName(ptr->getRTLILObjPtr());
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

//! Verifies all terminals in LogicCone::search are legal.
void LogicCone::verifyInputNodes() const {
    for (const auto &node : inputNodes) {
        if (dynamic_pointer_cast<IONode>(node) == nullptr && dynamic_pointer_cast<FFNode>(node) == nullptr) {
            log_error("TaMaRa internal error: Logic cone input node should be either IONode or FFNode, but "
                      "instead it was %s %s!\n",
                node->identify().c_str(), log_id(getRTLILName(node)));
        }
    }
}

void LogicCone::search(RTLIL::Module *module, RTLILWireConnections &connections) {
    log_assert(frontier.empty());
    log_assert(cone.empty()); // NOLINT(bugprone-unused-return-value)
    log_assert(inputNodes.empty());

    frontier.push(outputNode);

    // keep track of the first node in the search, we always want to compute neighbours for this even if we
    // normally wouldn't (because it's an FFNode/IONode)
    bool first = true;

    log("Starting search for cone %u\n", id);
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
                log("    Add %s to cone (now has %zu items)\n", node->identify().c_str(), cone.size());
            } else {
                log("    Skip adding %s to cone (first: %s)\n", node->identify().c_str(),
                    first ? "true" : "false");
            }
        } else {
            // found terminal, start wrapping up search -> don't add neighbours, and don't add elements to
            // cone
            log("    %s %s is a terminal, wrapping up search\n", node->identify().c_str(),
                log_id(getRTLILName(node)));
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
    log("Search complete for cone %u, have %zu items\n", id, cone.size());
}

void LogicCone::replicate(RTLIL::Module *module) {
    // don't replicate cones that don't have any internal elements
    if (cone.empty()) {
        log("Cone %u has no internal elements - skipping replication\n", id);
        return;
    }

    log("Replicating %zu collected items for logic cone %u\n", cone.size(), id);
    for (const auto &item : cone) {
        item->replicate(module);
    }

    // special case for end points (IOs and FFs) -> only replicate FFs, don't replicate IOs
    // FIXME we may not want to replicate input terminals, because it produces duplicates?
    log("Checking terminals\n");
    for (const auto &node : inputNodes) {
        replicateIfNotIO(node, module);
    }
    replicateIfNotIO(outputNode, module);
}

void LogicCone::insertVoter(RTLIL::Module *module) {
    log("Inserting voter into logic cone %u\n", id);
    voter = VoterBuilder::build(module);
}

void LogicCone::wire(RTLIL::Module *module) {
    log("Wiring logic cone %u\n", id);
    log_assert(voter.has_value());
}

std::vector<LogicCone> LogicCone::buildSuccessors(RTLILWireConnections &connections) {
    log("Considering potential successors for cone %u\n", id);
    std::vector<LogicCone> out {};
    for (const auto &node : inputNodes) {
        log("Considering %s %s as a successor cone... ", node->identify().c_str(),
            log_id(getRTLILName(node)));

        // check if it has a neighbour
        if (connections[node->getRTLILObjPtr()].size() > 0) {
            // we have neighbours, this is a valid successor
            log("Confirmed.\n");
            out.push_back(newLogicCone(node->getRTLILObjPtr()));
        } else {
            log("Has no additional neighbours, not a valid successor.\n");
        }
    }

    return out;
}
