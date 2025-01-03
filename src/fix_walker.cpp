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
dict<RTLIL::SigBit, int> computeWireDriversCount(RTLIL::Module *module) {
    dict<RTLIL::SigBit, int> wireDriversCount; // this has to be a dict, SigBit isn't hashable in std

    // first, pre-calculate the wireDriversCount lookup
    // this logic is borrowed from Yosys check.cc
    SigMap sigmap(module);
    for (auto *cell : module->cells()) {
        for (const auto &conn : cell->connections()) {
            SigSpec sig = sigmap(conn.second);
            bool input = cell->input(conn.first);
            bool output = cell->output(conn.first);

            for (auto bit : sig) {
                if (output && !input && (bit.wire != nullptr)) {
                    wireDriversCount[bit]++;
                }
            }
        }
    }
    return wireDriversCount;
}
} // namespace

namespace tamara {

void FixWalkerManager::add(const std::shared_ptr<FixWalker> &walker) {
    walkers.push_back(walker);
}

void FixWalkerManager::execute(RTLIL::Module *module) {
    auto wireDriversCount = computeWireDriversCount(module);

    for (auto &walker : walkers) {
        log("Running FixWalker %s\n", walker->name().c_str());

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
                        walker->processWire(wire, wireDriversCount[wire]);
                        processed.insert(wire);
                    }
                }
            }
        }
        for (auto *wire : module->wires()) {
            if (!processed.contains(wire)) {
                walker->processWire(wire, wireDriversCount[wire]);
                processed.insert(wire);
            }
        }

        log("Processed %zu unique items for FixWalker %s\n", processed.size(), walker->name().c_str());
    }
}

void MultiDriverFixer::processWire(RTLIL::Wire *wire, int driverCount) {
    if (driverCount == 3) {
        log("Found potential candidate for MultiDriverFixer: '%s'. Checking further.\n", log_id(wire->name));

        // must have exactly 3 inputs and exactly 3 outputs
        // all inputs and outputs must be TMR replicas
        // all inputs must be of the same cell type
        // all outputs must be of the same cell type
    }
}

} // namespace tamara
