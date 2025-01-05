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
#include <unordered_set>
#include <vector>

USING_YOSYS_NAMESPACE;

using namespace tamara;

namespace {

//! Inserts a value into the hashmap, or adds it then inserts if not present
constexpr void addConnection(RTLILWireConnections &connections, RTLILAnyPtr key, const RTLILAnyPtr &value) {
    if (!connections.contains(key)) {
        connections[key] = std::unordered_set<RTLILAnyPtr>();
    }
    connections[key].insert(value);
}

//! Determines if the cells annotations are suitable to triplicate
constexpr bool shouldConsiderForTMR(const RTLIL::AttrObject *obj) {
    return !obj->has_attribute(IGNORE_ANNOTATION);
}

}; // namespace

RTLILWireConnections tamara::analyseConnections(const RTLIL::Module *module) {
    RTLILWireConnections connections {};

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
                addConnection(connections, wire, cell);
                log("[neighbour] wire %s --> cell %s\n", log_id(wire->name), log_id(cell->name));
            }

            // this is an input to the cell, so connect cell -> wire (remember we work backwards)
            if (cellTypes.cell_input(cell->type, name)) {
                addConnection(connections, cell, wire);
                log("[neighbour] cell %s --> wire %s\n", log_id(cell->name), log_id(wire->name));
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

        if (lhsWire != nullptr && rhsWire != nullptr) {
            if (shouldConsiderForTMR(lhsWire) && shouldConsiderForTMR(rhsWire)) {
                log("[neighbour] %s --> %s\n", log_id(lhsWire->name), log_id(rhsWire->name));

                // apparently we don't actually need to reverse this, we're ok to just map lhs -> rhs
                // despite doing backwards BFS
                addConnection(connections, lhsWire, rhsWire);
            }
        } else {
            log("Either RHS(%s) or LHS(%s) SigSpec is not a wire, skipping\n", log_signal(rhs),
                log_signal(lhs));
        }
    }

    log("\nDone, located %zu neighbours from %zu cells\n", connections.size(),
        module->selected_cells().size());
    // log_error("dump\n");

    return connections;
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
