// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2025 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#include "tamara/fix_walker.hpp"
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

    for (auto &walker : walkers) {
        log("Running FixWalker %s\n", walker->name().c_str());

        // avoid processing things twice
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
                        walker->processWire(wire, wireDriversCount[wire], wireDrivenByCount[wire]);
                        processed.insert(wire);
                    }
                }
            }
        }
        for (auto *wire : module->wires()) {
            if (!processed.contains(wire)) {
                walker->processWire(wire, wireDriversCount[wire], wireDrivenByCount[wire]);
                processed.insert(wire);
            }
        }

        log("Processed %zu unique items for FixWalker %s\n", processed.size(), walker->name().c_str());
    }
}

void MultiDriverFixer::processWire(RTLIL::Wire *wire, int driverCount, int drivenCount) {
    // this wire must have exactly 3 inputs and exactly 3 outputs (we aim to resolve this)
    if (driverCount == 3 && drivenCount == 3) {
        log("Found potential candidate for MultiDriverFixer: '%s'. Checking further.\n", log_id(wire->name));

        // TODO now we need a way to locate our inputs and outputs!
        // either we run analyseWireConnections again, or we use the logic from check.cc in yosys

        // all inputs and outputs must be TMR replicas (so should all have the "tamara_cone" attribute and be
        // from the same cone)
        // all inputs must be of the same cell type
        // all outputs must be of the same cell type
    }
}

} // namespace tamara
