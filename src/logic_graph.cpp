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

USING_YOSYS_NAMESPACE;

using namespace tamara;

uint32_t LogicCone::g_cone_ID = 0;

//! Fast(er) check that wires are equal by names.
static constexpr bool areWiresEqual(const RTLIL::Wire *a, const RTLIL::Wire *b) {
    if (a->name.hash() == b->name.hash()) {
        return a->name == b->name;
    }
    return false;
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

    // TODO we should probs skip these checks in prod to save time
    cell->check();
    replica1->check();
    replica2->check();
    module->check();

    // TODO store replicas somehow?
}

void IONode::replicate([[maybe_unused]] RTLIL::Module *module) {
    // this shouldn't happen
    log_error("TaMaRa internal error: Cannot replicate IO node!\n");
}

std::vector<TMRGraphNode::Ptr> ElementNode::computeNeighbours(
    RTLIL::Module *module, RTLILWireConnections &connections) {
    // TODO
    return {};
}

std::vector<TMRGraphNode::Ptr> IONode::computeNeighbours(
    RTLIL::Module *module, RTLILWireConnections &connections) {
    auto neighbours = connections[io];
    log_assert(!neighbours.empty());
    log("    IONode has %zu neighbours\n", neighbours.size());

    // now, construct Yosys types into our logic graph types

    // for (const auto &connection : module->connections()) {
    //     const auto &[lhs, rhs] = connection;
    //
    //     // since we're working backwards from output to input, we check that RHS == IO, and LHS is our
    //     // neighbour
    //     if (areWiresEqual(rhs.as_wire(), io)) {
    //         log("    Found neighbour for IO %s in cone %u: %s\n", log_id(io->name), getConeID(),
    //             log_id(lhs.as_wire()->name));
    //     } else {
    //         log("    Connection %s is NOT a neighbour of %s (is wire: %s)\n", log_id(rhs.as_wire()->name),
    //             log_id(io->name), rhs.is_wire() ? "yes" : "no");
    //     }
    // }
    return {};
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

        auto neighbours = node->computeNeighbours(module, connections);
        log("    Node has %zu neighbours\n", neighbours.size());
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
