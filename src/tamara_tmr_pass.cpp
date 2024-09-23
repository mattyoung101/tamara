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
#include <unordered_set>
#include <vector>

USING_YOSYS_NAMESPACE;

namespace tamara {

//! This is the main TaMaRa TMR command, which starts the TMR process.
struct TamaraTMRPass : public Pass {

    TamaraTMRPass()
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

        // first check we have run propagate
        if (!design->scratchpad_get_bool("tamara_propagate.didRun")) {
            log_error("You have not yet run tamara_propagate! See 'help tamara_propagate'.\n");
        }

        // we can only operate on one module
        if (design->top_module() == nullptr) {
            log_error("No top module selected\n");
        }

        auto *const module = design->top_module();
        log("Applying TMR to top module: %s\n", log_id(module->name));
        log_push();

        // analyse wire connections, this is used later by the logic cone code for neighbour calculations
        // I thought that we might be able to get this through RTLIL directly, but I think we have to compute
        // it ourselves.
        // the main trouble is we have to compute it in reverse: that is, we want to know which _wires_ have
        // which _cells_ associated with them, but RTLIL will only tell us which _cells_ have which _wires_
        // associated with them.
        log_header(design, "Analysing wire connections\n");
        auto neighbours = analyseConnections(module);

        // debug dump
        // nlohmann::json jsonDump(analysis); // TODO needs custom data type

        // figure out where our output ports are, these will be the start of the BFS
        log_header(design, "Computing logic graph\n");
        auto outputs = getOutputPorts(module);
        log("Module has %zu output ports, %zu selected cells\n", outputs.size(),
            module->selected_cells().size());

        for (const auto &output : outputs) {
            // TODO should we skip the cell if it's not labelled tamara_triplicate?
            auto cone = LogicCone(output);
            // start at the output port, do a BFS backwards to build up our logic cones
            cone.search(module, neighbours);
        }

        log_pop();
    }

private:
    //! Determines if the cells annotations are suitable to triplicate
    static constexpr bool shouldConsiderForTMR(const RTLIL::AttrObject *obj) {
        return obj->has_attribute(TRIPLICATE_ANNOTATION) && !obj->has_attribute(IGNORE_ANNOTATION);
    }

    //! Inserts a value into the hashmap, or adds it then inserts if not present
    // TODO make this a templated function in utils.hpp
    static constexpr void addConnection(
        RTLILWireConnections &connections, RTLIL::Wire *key, const RTLILAnyPtr &value) {
        if (!connections.contains(key)) {
            connections[key] = std::unordered_set<RTLILAnyPtr>();
        }
        connections[key].insert(value);
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

    //! Analyses connections betweens wires and the other wires or cells they're connected to
    static RTLILWireConnections analyseConnections(const RTLIL::Module *module) {
        RTLILWireConnections connections {};
        for (const auto &cell : module->selected_cells()) {
            // cells that are ignored by TaMaRa should never be neighbours
            if (!shouldConsiderForTMR(cell)) {
                continue;
            }

            log("Checking connections for cell: %s\n", log_id(cell->name));

            // find wires that this is connected to
            for (const auto &connection : cell->connections()) {
                const auto &[name, signal] = connection;
                if (!signal.is_wire()) {
                    log("Signal %s is not wire, skipping\n", log_id(name));
                    continue;
                }

                auto *const wire = signal.as_wire();

                // if (!wire->port_output && !wire->port_input) {
                //     log_error("Wire %s is neither input nor output?!\n", log_id(wire->name));
                // }

                // consider direction, since we're doing BFS backwards: only add outputs
                //if (wire->port_output) {
                    addConnection(connections, wire, cell);
                    log("[neighbour] wire %s --> cell %s\n", log_id(wire->name), log_id(cell->name));
                //} else {
                //    log("Skipping input wire %s\n", log_id(wire->name));
                //}
            }
            log("\n");
        }

        // also add global connections
        log("Checking global module connections\n");
        for (const auto &connection : module->connections()) {
            const auto &[lhs, rhs] = connection;

            if (rhs.is_wire() && lhs.is_wire()) {
                auto *const lhsWire = lhs.as_wire();
                auto *const rhsWire = rhs.as_wire();
                if (shouldConsiderForTMR(lhsWire) && shouldConsiderForTMR(rhsWire)) {
                    log("[neighbour] %s --> %s\n", log_id(lhsWire->name), log_id(rhsWire->name));

                    // build connection between RHS -> LHS (since we do backwards BFS)
                    addConnection(connections, rhsWire, lhsWire);
                }
            } else {
                // TODO get name, if possible?
                log("Either RHS or LHS SigSpec is not a wire, skipping\n");
            }
        }

        log("\nDone, located %zu neighbours\n", connections.size());

        return connections;
    }

} const TamaraTMRPass;

} // namespace tamara
