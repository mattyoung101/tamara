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
#include "tamara/util.hpp"
#include <vector>

USING_YOSYS_NAMESPACE

PRIVATE_NAMESPACE_BEGIN

using namespace tamara;

//! This is the main TaMaRa TMR command, which starts the TMR process.
struct TamaraTmrPass : public Pass {

    TamaraTmrPass()
        : Pass("tamara_tmr", "Perform TaMaRa TMR voter insertion") {
    }

    void help() override {
        //   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
        log("\n");
        log("    tamara_tmr\n");
        log("\n");

        log("TaMaRa is an automated triple modular redundancy flow for Yosys.\n");
        log("The 'tamara_tmr' command processes exactly one selected module in the\n");
        log("design, which should be the top module. It will apply TMR and insert\n");
        log("majority voters.\n\n");

        log("The 'tamara_tmr' command should be run after synthesis but before\n");
        log("techmapping. It must be run after the 'tamara_propagate command.\n");
    }

    void execute(std::vector<std::string> args, RTLIL::Design *design) override {
        log_header(design, "Starting TaMaRa automated triple modular redundancy\n\n");
        log_push();

        // first check we have run propagate
        if (!design->scratchpad_get_bool("tamara_propagate.didRun")) {
            log_error("You have not yet run tamara_propagate! See 'help tamara_propagate'.\n");
        }

        // we can only operate on one module
        if (design->selected_modules().size() == 0 || design->selected_modules().size() > 1) {
            log_error("TaMaRa currently can only process exactly one selected module, which should "
                      "be the top module. You have %zu modules selected.\n",
                design->selected_modules().size());
        }

        auto *const module = design->selected_modules()[0];
        log_header(design, "Applying TMR to module: %s\n", log_id(module->name));

        // start at the output port, do a BFS backwards to build up our logic cones
        auto outputs = getOutputPorts(module);
        log("Module has %zu output ports\n", outputs.size());

        for (const auto &output : outputs) {
            // TODO should we skip the cell if it's not labelled tamara_triplicate?
        }

        // FIXME we want to flatten all the TMR modules, I'm not sure if this is the way to do it
        Pass::call(design, "flatten");

        log_pop();
    }

private:
    //! Determines if the cells annotations are suitable to triplicate
    static constexpr bool shouldTriplicate(const RTLIL::Cell *cell) {
        return cell->has_attribute(TRIPLICATE_ANNOTATION) && !cell->has_attribute(IGNORE_ANNOTATION);
    }

    //! Returns output wires for a module
    static std::vector<RTLIL::Wire *> getOutputPorts(RTLIL::Module *module) {
        std::vector<RTLIL::Wire *> out {};
        for (const auto &wire : module->wires()) {
            if (wire->port_output) {
                out.push_back(wire);
            }
        }
        return out;
    }

    static LogicCone startLogicConeSearch(RTLIL::Design *design, RTLIL::Wire *output) {

    }

} const TamaraTmrPass;

PRIVATE_NAMESPACE_END
