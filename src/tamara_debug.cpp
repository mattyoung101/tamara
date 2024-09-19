// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2024 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#include "kernel/log.h"
#include "kernel/register.h"
#include "kernel/rtlil.h"
#include "kernel/yosys_common.h"
#include "tamara/logic_graph.hpp"
#include "tamara/voter_builder.hpp"
#include <vector>

USING_YOSYS_NAMESPACE

PRIVATE_NAMESPACE_BEGIN

//! The tamara_debug command is used for debugging various TaMaRa features.
struct TamaraDebug : public Pass {

    TamaraDebug()
        : Pass("tamara_debug", "Used to debug various TaMaRa features") {
    }

    void help() override {
        //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
        log("\n");
        log("    tamara_debug [task]\n");
        log("\n");

        log("Executes the debug task specified.\n");
    }

    void execute(std::vector<std::string> args, RTLIL::Design *design) override {
        log_header(design, "Running TaMaRa debug task\n\n");
        log_push();

        if (args.size() <= 1) {
            log_error("Must specify debug task.\n");
        }

        const auto task = args[1];

        // sadly we can't switch on strings
        if (task == "forcePropagateDone") {
            log("Forcing propagate to be marked as done\n");
            design->scratchpad_set_bool("tamara_propagate.didRun", true);
        } else if (task == "mkvoter") {
            log("Generating one voter\n");
            tamara::VoterBuilder::build(design);
        } else if (task == "replicateNot") {
            log("Hack to test replicating a NOT gate\n");

            auto *top = design->top_module();
            if (top == nullptr) {
                log_error("No top module\n");
            }

            auto *notGate = findNot(top);
            auto node = std::make_shared<tamara::ElementNode>(notGate, 0);
            node->replicate(top);
        } else {
            log_error("Unhandled debug task: '%s'\n", task.c_str());
        }

        log_pop();
    }

    static RTLIL::Cell *findNot(RTLIL::Module *module) {
        for (const auto &cell : module->cells()) {
            if (cell->type == ID($logic_not)) {
                log("Found not gate: %s\n", log_id(cell->name));
                return cell;
            }
        }
        log_error("Could not find not gate in top module: %s\n", log_id(module->name));
        return nullptr;
    }
} const TamaraDebug;

PRIVATE_NAMESPACE_END
