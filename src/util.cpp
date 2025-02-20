// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2025 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#include "tamara/util.hpp"
#include "kernel/celltypes.h"
#include "kernel/log.h"
#include "kernel/rtlil.h"
#include "kernel/yosys_common.h"
#include "tamara/termcolour.hpp"
#include <cmath>
#include <vector>

USING_YOSYS_NAMESPACE;

using namespace tamara;

namespace {

//! Determines if the cells annotations are suitable to triplicate
bool shouldConsiderForTMR(const RTLIL::AttrObject *obj) {
    return !obj->has_attribute(IGNORE_ANNOTATION);
}

}; // namespace

bool tamara::isDFF(const RTLIL::Cell *cell) {
    // this logic is borrowed from Yosys wreduce.cc
    return cell->type.in(ID($dff), ID($dffe), ID($adff), ID($adffe), ID($sdff), ID($sdffe), ID($sdffce),
        ID($dlatch), ID($adlatch));
}

RTLIL::Wire *tamara::sigSpecToWire(const RTLIL::SigSpec &sigSpec) {
    if (sigSpec.is_wire()) {
        return sigSpec.as_wire();
    }
    if (sigSpec.is_bit()) {
        return sigSpec.as_bit().wire;
    }
    if (!sigSpec.chunks().empty()) {
        // FIXME this is somewhat questionable and should be tested on more designs
        return sigSpec.chunks().front().wire;
    }

    // unhandled!
    return nullptr;
}

std::pair<RTLILWireConnections, RTLILAnySignalConnections> tamara::analyseConnections(
    const RTLIL::Module *module) {
    RTLILWireConnections wireConnections {};
    RTLILAnySignalConnections signalConnections {};

    // usage of CellTypes is based off Yosys' show command
    CellTypes cellTypes(module->design);

    for (const auto &cell : module->selected_cells()) {
        // cells that are ignored by TaMaRa should never be neighbours
        if (!shouldConsiderForTMR(cell)) {
            log("Skipping cell %s, not marked tamara_triplicate\n", log_id(cell->name));
            continue;
        }

        log("Checking connections for cell: %s (%zu connections)\n", log_id(cell->name),
            cell->connections().size());

        // find wires that this is connected to
        for (const auto &connection : cell->connections()) {
            const auto &[name, signal] = connection;

            Wire *wire = sigSpecToWire(signal);
            if (wire == nullptr) {
                log_warning("Trouble accessing wire from connection '%s'\n", log_id(name));
                continue;
            }

            // this is an output from the cell, so connect wire -> cell (remember we work backwards)
            if (cellTypes.cell_output(cell->type, name)) {
                wireConnections[wire].insert(cell);
                signalConnections[wire].insert(signal);
                log("[neighbour wire] wire %s --> cell %s\n", log_id(wire->name), log_id(cell->name));
                log("[neighbour signal] wire %s --> signal %s\n", log_id(wire->name), log_signal(signal));
            }

            // this is an input to the cell, so connect cell -> wire (remember we work backwards)
            if (cellTypes.cell_input(cell->type, name)) {
                wireConnections[cell].insert(wire);
                signalConnections[cell].insert(signal);
                log("[neighbour wire] cell %s --> wire %s\n", log_id(cell->name), log_id(wire->name));
                log("[neighbour signal] cell %s --> signal %s\n", log_id(cell->name), log_signal(signal));
            }
        }
        log("\n");
    }

    // also add global connections
    log("Checking global module connections\n");
    for (const auto &connection : module->connections()) {
        const auto &[lhs, rhs] = connection;

        auto *lhsWire = sigSpecToWire(lhs);
        auto *rhsWire = sigSpecToWire(rhs);

        // provided lhsWire is defined, we can still insert the rhs (even if rhsWire is nullptr)
        if (lhsWire != nullptr) {
            signalConnections[lhsWire].insert(rhs);
            log("[neighbour signal] %s -> %s\n", log_id(lhsWire->name), log_signal(rhs));
        }

        if (lhsWire != nullptr && rhsWire != nullptr) {
            if (shouldConsiderForTMR(lhsWire) && shouldConsiderForTMR(rhsWire)) {
                log("[neighbour wire] %s --> %s\n", log_id(lhsWire->name), log_id(rhsWire->name));

                // apparently we don't actually need to reverse this, we're ok to just map lhs -> rhs
                // despite doing backwards BFS
                wireConnections[lhsWire].insert(rhsWire);
            }
        } else {
            log("Either RHS(%s) or LHS(%s) SigSpec is not a wire, skipping\n", log_signal(rhs),
                log_signal(lhs));
        }
    }

    log("\nDone, located %zu neighbours from %zu cells\n", wireConnections.size(),
        module->selected_cells().size());

    return std::make_pair(wireConnections, signalConnections);
}

RTLILAnySignalConnections tamara::analyseCellOutputs(RTLIL::Module *module) {
    RTLILAnySignalConnections out;

    CellTypes cellTypes(module->design);

    for (const auto &cell : module->cells()) {
        for (const auto &connection : cell->connections()) {
            const auto &[name, signal] = connection;

            // is this an output wire?
            if (cellTypes.cell_output(cell->type, name)) {
                out[cell].insert(signal);
            }
        }
    }

    return out;
}

std::vector<RTLILAnyPtr> tamara::rtlilInverseLookup(const RTLILWireConnections &connections, Wire *target) {
    // PERF: This is REALLY expensive currently on the order of O(n^2).
    std::vector<RTLILAnyPtr> out;
    for (const auto &pair : connections) {
        const auto &[key, value] = pair;

        for (const auto &item : value) {
            if (getRTLILName(item) == target->name) {
                out.push_back(key);
            }
        }
    }
    return out;
}

std::vector<RTLILAnyPtr> tamara::signalInverseLookup(
    const RTLILAnySignalConnections &connections, const RTLIL::SigSpec &target) {
    // PERF: This is REALLY expensive currently on the order of O(n^2).
    std::vector<RTLILAnyPtr> out;
    for (const auto &pair : connections) {
        const auto &[key, value] = pair;

        for (const auto &item : value) {
            if (item == target) {
                out.push_back(key);
            }
        }
    }
    return out;
}

RTLIL::IdString tamara::getRTLILName(const RTLILAnyPtr &ptr) {
    return std::visit(
        [](auto &&arg) {
            using T = std::decay_t<decltype(arg)>;
            if constexpr (std::is_same_v<T, RTLIL::Cell *>) {
                return arg->name;
            }
            if constexpr (std::is_same_v<T, RTLIL::Wire *>) {
                return arg->name;
            }
        },
        ptr);
}

RTLILConnections tamara::analyseAll(RTLIL::Module *module) {
    RTLILConnections out;
    auto [wires, signals] = analyseConnections(module);
    out.wires = wires;
    out.signals = signals;
    out.cellOutputs = analyseCellOutputs(module);
    return out;
}

void tamara::dumpAsync(const std::string &file, size_t line) {
    size_t lastSlash = file.find_last_of('/');
    auto filename = (lastSlash == std::string::npos) ? file : file.substr(lastSlash + 1);
    Yosys::run_pass("show -colors 420 -format svg -prefix ./dump_" + filename + ":" + std::to_string(line));
}
