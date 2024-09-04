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
#include "tamara/voter_builder.hpp"
#include <vector>

USING_YOSYS_NAMESPACE

PRIVATE_NAMESPACE_BEGIN

//! The tamara_debug command is used for debugging various TaMaRa features.
struct TamaraDebug : public Pass {

    TamaraDebug() : Pass("tamara_debug", "Used to debug various TaMaRa features") {
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
            // TODO
        } else {
            log_error("Unhandled debug task: '%s'\n", task.c_str());
        }

        log_pop();
    }
} const TamaraDebug;

PRIVATE_NAMESPACE_END
