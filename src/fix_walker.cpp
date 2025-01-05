// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2025 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#include "tamara/fix_walker.hpp"
#include "kernel/celltypes.h"
#include "kernel/log.h"
#include "kernel/rtlil.h"
#include "kernel/sigtools.h"
#include "kernel/yosys_common.h"
#include "tamara/util.hpp"

USING_YOSYS_NAMESPACE;

namespace {

/// Computes the number of wires that either drive, or are driving, another wire in the module.
/// @param isOutput true if we're considering output wires, false if input wires (TODO is this the right?)
dict<RTLIL::SigBit, int> computeWireIOCount(RTLIL::Module *module, bool isOutput) {
    dict<RTLIL::SigBit, int> count; // this has to be a dict, SigBit isn't hashable in std

    // first, pre-calculate the wireDriversCount lookup
    // this logic is borrowed from Yosys check.cc
    SigMap sigmap(module);
    for (auto *cell : module->cells()) {
        for (const auto &conn : cell->connections()) {
            SigSpec sig = sigmap(conn.second);
            bool input = cell->input(conn.first);
            bool output = cell->output(conn.first);

            for (auto bit : sig) {
                bool shouldConsider = isOutput ? (output && !input) : (input && !output);
                if (shouldConsider && (bit.wire != nullptr)) {
                    count[bit]++;
                }
            }
        }
    }
    return count;
}
} // namespace

namespace tamara {

void FixWalkerManager::add(const std::shared_ptr<FixWalker> &walker) {
    walkers.push_back(walker);
}

void FixWalkerManager::execute(RTLIL::Module *module) {
    // TODO also note we may have this the wrong way around ("drivers" vs "driven by")
    auto wireDriversCount = computeWireIOCount(module, true);
    auto wireDrivenByCount = computeWireIOCount(module, false);
    log("Wire drivers count: %zu  Wire driven by count: %zu\n", wireDriversCount.size(),
        wireDrivenByCount.size());

    // also pre-compute another copy of RTLILWireConnections
    auto connections = analyseConnections(module);

    for (auto &walker : walkers) {
        log("Running FixWalker %s\n", walker->name().c_str());

        // avoid processing things twice (for each walker)
        std::unordered_set<RTLIL::AttrObject *> processed;

        walker->processModule(module);
        for (auto *cell : module->cells()) {
            if (!processed.contains(cell)) {
                walker->processCell(cell);
                processed.insert(cell);

                for (const auto &connection : cell->connections()) {
                    const auto &[name, signal] = connection;
                    auto *wire = sigSpecToWire(signal);

                    if (wire != nullptr && !processed.contains(wire)) {
                        // FIXME this implicitly calls a constructor that causes an assert failure because the
                        // width is 2; it doesn't want to let us construct a SigBit I suspect it's a problem
                        // with multi-bit designs
                        // This might be an issue with how we iterate over the connections, we might need to
                        // iterate over each bit in the connections
                        walker->processWire(
                            wire, wireDriversCount[wire], wireDrivenByCount[wire], connections);
                        processed.insert(wire);
                    }
                }
            }
        }
        for (auto *wire : module->wires()) {
            if (!processed.contains(wire)) {
                // FIXME this will also likely explode
                walker->processWire(wire, wireDriversCount[wire], wireDrivenByCount[wire], connections);
                processed.insert(wire);
            }
        }

        log("Processed %zu unique items for FixWalker %s\n", processed.size(), walker->name().c_str());
    }
}

void MultiDriverFixer::processWire(
    RTLIL::Wire *wire, int driverCount, int drivenCount, const RTLILWireConnections &connections) {
    // this wire must have exactly 3 inputs and exactly 3 outputs (we aim to resolve this)
    if (driverCount == 3 && drivenCount == 3) {
        log("Found potential candidate for MultiDriverFixer: '%s'. Checking further... ", log_id(wire->name));

        // all inputs and outputs must be TMR replicas (so should all have the "tamara_cone" attribute and be
        // from the same cone)
        // all inputs must be of the same cell type (OPTIONAL, TODO do later)
        // all outputs must be of the same cell type (OPTIONAL, TODO do later)

        if (!connections.contains(wire)) {
            log("Not present in RTLILWireConnections\n");
            return;
        }

        // all inputs must be TMR replicas
        for (const auto &conn : connections.at(wire)) {
            auto *attr = toAttrObject(conn);
            if (!attr->has_attribute(CONE_ANNOTATION)) {
                log("Missing cone annotation.\n");
                return;
            }
        }

        // all outputs must be TMR replicas; we can find this out by doing an inverse lookup
        auto inverse = rtlilInverseLookup(connections, wire);
        for (const auto &node : inverse) {
            auto *attr = toAttrObject(node);
            if (!attr->has_attribute(CONE_ANNOTATION)) {
                log("Missing cone annotation.\n");
                return;
            }
        }

        log("Confirmed.\n");

        // confirmed it, so now we need to apply our re-wiring logic
        rewire(wire, connections);
    }
}

// NOLINTNEXTLINE(readability-convert-member-functions-to-static) We prefer to keep this as a member func.
void MultiDriverFixer::rewire(RTLIL::Wire *wire, const RTLILWireConnections &connections) {
    // compute our inputs and outputs
    auto inputs = connections.at(wire);
    // PERF We should re-use this from processWire since rtlilInverseLookup is O(n^2)
    auto outputs = rtlilInverseLookup(connections, wire);
    log_assert(inputs.size() == outputs.size() && !inputs.empty() && !outputs.empty());

    // first, for each input, we need to find the port that is connected to the problematic wire (the variable
    // "wire") and disconnect it
    disconnectProblematicWires(wire, inputs);
}

// NOLINTNEXTLINE(readability-convert-member-functions-to-static) We prefer to keep this as a member func.
void MultiDriverFixer::disconnectProblematicWires(
    RTLIL::Wire *target, const std::unordered_set<RTLILAnyPtr> &inputs) {

    CellTypes cellTypes(target->module->design);

    // find the port in the cell that is connected to the problematic wire
    // so input is basically going to be a cell that has an output going into our wire
    for (const auto &input : inputs) {
        // FIXME potentially sketchy - can we really be sure this is a cell?
        auto *cell = std::get<RTLIL::Cell *>(input);

        for (const auto &connection : cell->connections()) {
            const auto &[name, signal] = connection;
            auto *connWire = sigSpecToWire(signal);

            if (cellTypes.cell_output(cell->type, name) && connWire == target) {
                // found it, now disconnect
                //
                // cell->connections_.erase(name);
                // cell->check();
                // DUMP;
                // TODO we don't want to erase the connection entirely, we just want to get rid of the RHS
                // YS_DEBUGTRAP;

                // we can safely return, we don't have to worry about multiple ports like in the last
                // iteration of this code because we know there can only be one connection between this cell
                // and the problematic wire; and this is the one (we checked connWire == target)
                return;
            }
        }
    }

    log_error("TaMaRa internal error: Could not find problematic target wire '%s' from %zu inputs\n",
        log_id(target->name), inputs.size());
}

} // namespace tamara
