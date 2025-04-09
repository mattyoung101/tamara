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
#include <string>
#include <vector>

USING_YOSYS_NAMESPACE;

namespace tamara {

#define WIRE(A, B, num) auto wire##num = top->addWire(NEW_ID);

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
        log("Current tasks:\n");
        log("- mkvoter <bits>\n");
        log("- replicateNot\n");
        log("- mkMultiVoter\n");
        log(" - count\n");
    }

    void execute(std::vector<std::string> args, RTLIL::Design *design) override {
        log_header(design, "Running TaMaRa debug task\n\n");
        log_push();

        if (args.size() <= 1) {
            log_error("Must specify debug task.\n");
        }

        const auto &task = args[1];

        // sadly we can't switch on strings
        if (task == "mkvoter") {
            auto bits = static_cast<int>(std::stol(args[2]));
            log("Generating a %d bit voter\n", bits);
            auto *top = design->addModule(NEW_ID);

            VoterBuilder builder(top);

            // add inputs
            // note: these don't have the $ symbol, because they are top-level ports
            auto *a = top->addWire(ID(a), bits);
            auto *b = top->addWire(ID(b), bits);
            auto *c = top->addWire(ID(c), bits);
            a->port_input = true;
            b->port_input = true;
            c->port_input = true;

            // add outputs
            auto *out = top->addWire(ID(out), bits);
            auto *err = top->addWire(ID(err)); // error is always 1 bit
            out->port_output = true;
            err->port_output = true;

            // add wires to ports
            top->fixup_ports();

            // build voter
            builder.build(a, b, c, out);
            builder.finalise(err);

            top->check();
        } else if (task == "replicateNot") {
            log("Hack to test replicating a NOT gate\n");

            auto *top = design->top_module();
            if (top == nullptr) {
                log_error("No top module\n");
            }

            auto *notGate = findNot(top);
            auto node = std::make_shared<tamara::ElementCellNode>(notGate, 0);
            node->replicate(top);

            // fake cone so we can try inserting a voter
            auto cone = tamara::LogicCone(notGate);
            // cone.insertVoter(top);
        } else if (task == "count") {
            log("%zu\n", design->top_module()->cells().size() + design->top_module()->wires().size());
        } else {
            log_error("Unhandled debug task: '%s'\n", task.c_str());
        }

        log_pop();
    }

    static RTLIL::Cell *findNot(RTLIL::Module *module) {
        for (const auto &cell : module->cells()) {
            if (cell->type == ID($logic_not)) {
                log("Found NOT gate: %s\n", log_id(cell->name));
                return cell;
            }
        }
        log_error("Could not find NOT gate in top module: %s\n", log_id(module->name));
        return nullptr;
    }
} const TamaraDebug;

} // namespace tamara
