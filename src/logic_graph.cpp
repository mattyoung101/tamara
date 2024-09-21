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
#include <memory>

USING_YOSYS_NAMESPACE;

using namespace tamara;

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

void IONode::replicate([[maybe_unused]] RTLIL::Module * module) {
    // this shouldn't happen
    log_error("TaMaRa internal error: Cannot replicate IO node!\n");
}

std::vector<TMRGraphNode::Ptr> ElementNode::computeNeighbours() {
    // TODO
    return {};
}

std::vector<TMRGraphNode::Ptr> IONode::computeNeighbours() {
    // TODO
    return {};
}

void LogicCone::search(RTLIL::Module *module, RTLIL::Wire *output) {
    log_assert(frontier.empty());
    log_assert(cone.empty()); // NOLINT(bugprone-unused-return-value)

    // we can fill in the output directly (we're working from output backwards)
    outputNode = std::make_shared<IONode>(output, id);
    frontier.push(outputNode);
}

static void replicateIfNotIO(const TMRGraphNode::Ptr &node, RTLIL::Module *module) {
    if (dynamic_pointer_cast<IONode>(node) != nullptr) {
        // not an IO node, we're safe to replicate
        log("LogicCone terminal is NOT an IO, replicating it (must be FF)\n");
        node->replicate(module);
    } else {
        log("LogicCone terminal IS an IO, it will not be replicated\n");
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
    VoterBuilder::build(module);
}
