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

TMRGraphNode::Ptr TMRGraphNode::yosysToLogicGraph(const RTLILAnyPtr &ptr) {
    // based on example 3 of https://en.cppreference.com/w/cpp/utility/variant/visit
    //
    // this is completely insane, holy shit
    //
    // why do we have to do this? for some reason we can't just pass the class member `id`??
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
                return static_cast<TMRGraphNode::Ptr>(std::make_shared<ElementNode>(arg, selfPtr, localId));
            }
            if constexpr (std::is_same_v<T, RTLIL::Wire *>) {
                // FIXME it may not be an IO - we need to check
                return static_cast<TMRGraphNode::Ptr>(std::make_shared<IONode>(arg, selfPtr, localId));
            }
        },
        ptr);
}

void ElementNode::replicate(RTLIL::Module *module) {
    auto id = std::to_string(getConeID());

    auto *replica1 = module->addCell(NEW_ID_SUFFIX(cell->name.str() + "_replica1_cone_" + id), cell);
    auto *replica2 = module->addCell(NEW_ID_SUFFIX(cell->name.str() + "_replica2_cone_" + id), cell);

    replica1->set_string_attribute(REPLICA_ANNOTATION, "1");
    replica2->set_string_attribute(REPLICA_ANNOTATION, "2");

    replica1->set_string_attribute(CONE_ANNOTATION, id);
    replica2->set_string_attribute(CONE_ANNOTATION, id);

    cell->set_bool_attribute(ORIGINAL_ANNOTATION);

    cell->check();
    replica1->check();
    replica2->check();
    module->check();

    replicas.push_back(replica1);
    replicas.push_back(replica2);
}

void IONode::replicate([[maybe_unused]] RTLIL::Module *module) {
    // this shouldn't happen
    log_error("TaMaRa internal error: Cannot replicate IO node!\n");
}

std::vector<TMRGraphNode::Ptr> TMRGraphNode::computeNeighbours(
    RTLIL::Module *module, RTLILWireConnections &connections) {
    auto neighbours = connections[getRTLILObjPtr()];
    log("    %s has %zu neighbours\n", identify().c_str(), neighbours.size());

    // now, construct Yosys types into our logic graph types
    std::vector<TMRGraphNode::Ptr> out{};
    for (const auto &neighbour : neighbours) {
        out.push_back(yosysToLogicGraph(neighbour));
    }
    return out;
}

void LogicCone::search(RTLIL::Module *module, RTLILWireConnections &connections) {
    log_assert(frontier.empty());
    log_assert(cone.empty()); // NOLINT(bugprone-unused-return-value)

    frontier.push(outputNode);

    log("Starting search for cone %u\n", id);
    while (!frontier.empty()) {
        auto node = frontier.front();
        frontier.pop();
        log("    Consider %s in cone %u (%zu items remain)\n", node->identify().c_str(), id, frontier.size());

        // add to logic cone (TODO only if not IO)
        if (dynamic_pointer_cast<IONode>(node) == nullptr) {
            log("    Add %s to cone\n", node->identify().c_str());
            cone.push_back(node);
        } else {
            log("    Skip adding %s to cone (must be IONode)\n", node->identify().c_str());
        }

        // locate neighbours
        auto neighbours = node->computeNeighbours(module, connections);

        // add to queue
        for (const auto &neighbour : neighbours) {
            frontier.push(neighbour);
        }
        log("\n");
    }
    log("Search complete for cone %u\n", id);
}

void LogicCone::replicateIfNotIO(const TMRGraphNode::Ptr &node, RTLIL::Module *module) const {
    if (dynamic_pointer_cast<IONode>(node) != nullptr) {
        // not an IO node, we're safe to replicate
        log("Logic cone %u terminal is NOT an IO, replicating it (assuming FF)\n", id);
        node->replicate(module);
    } else {
        log("Logic cone %u terminal is an IO, it will not be replicated\n", id);
    }
}

void LogicCone::replicate(RTLIL::Module *module) {
    log("Replicating %zu collected items for logic cone %u\n", cone.size(), id);
    for (const auto &item : cone) {
        item->replicate(module);
    }

    // special case for end points (IOs and FFs) -> only replicate FFs, don't replicate IOs
    replicateIfNotIO(inputNode, module);
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
