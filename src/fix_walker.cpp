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
#include "kernel/yosys_common.h"
#include "tamara/util.hpp"
#include <string>

USING_YOSYS_NAMESPACE;

namespace {

using namespace tamara;

/// Finds the RTLILAnyPtr object in the collection that has the partial contents of the string "name". If not
/// found, crashes.
template <std::ranges::range T>
RTLILAnyPtr findByApproxName(const T &cells, const std::string &name) {
    for (const auto &cell : cells) {
        auto cellName = std::string(getRTLILName(cell).c_str());
        if (cellName.find(name) != std::string::npos) {
            // found it
            return cell;
        }
    }
    log_error("TaMaRa internal error: Could not find partial name '%s' in list of size %zu\n", name.c_str(),
        cells.size());
}

/// Locates the input port name of the cell "cell" connected to the wire "target". Throws an error if not
/// found.
RTLIL::IdString locateInputPortConnectedToTarget(
    RTLIL::Wire *target, RTLIL::Cell *cell, const CellTypes &cellTypes) {
    for (const auto &connection : cell->connections()) {
        const auto &[name, signal] = connection;
        auto *connWire = sigSpecToWire(signal);

        if (cellTypes.cell_input(cell->type, name) && connWire == target) {
            // YS_DEBUGTRAP;
            // return cell->getPort(name);
            return name;
        }
    }

    log_error("TaMaRa internal error: Could not find input port connected to wire '%s' in cell '%s'\n",
        log_id(target->name), log_id(cell->name));
}

} // namespace

namespace tamara {

void FixWalkerManager::add(const std::shared_ptr<FixWalker> &walker) {
    walkers.push_back(walker);
}

void FixWalkerManager::execute(RTLIL::Module *module) {
    // also pre-compute another copy of RTLILWireConnections
    auto [connections, signalConnections] = analyseConnections(module);

    for (auto &walker : walkers) {
        log("Running FixWalker %s\n", walker->name().c_str());

        // avoid processing things twice (for each walker)
        ankerl::unordered_dense::set<RTLIL::AttrObject *> processed;

        walker->processModule(module);
        for (auto *cell : module->cells()) {
            if (!processed.contains(cell)) {
                walker->processCell(cell);
                processed.insert(cell);

                for (const auto &connection : cell->connections()) {
                    const auto &[name, signal] = connection;
                    auto *wire = sigSpecToWire(signal);

                    if (wire != nullptr && !processed.contains(wire) && connections.contains(wire)) {
                        // PERF calling this repeatedly is very slow: O(n^3) !!
                        auto inverse = rtlilInverseLookup(connections, wire);
                        walker->processWire(wire, inverse.size(), connections.at(wire).size(), connections);
                        processed.insert(wire);
                    }
                }
            }
        }
        for (auto *wire : module->wires()) {
            if (!processed.contains(wire) && connections.contains(wire)) {
                // PERF calling this repeatedly is very slow: O(n^3) !!
                auto inverse = rtlilInverseLookup(connections, wire);
                walker->processWire(wire, inverse.size(), connections.at(wire).size(), connections);
                processed.insert(wire);
            }
        }

        log("Processed %zu unique items for FixWalker %s\n", processed.size(), walker->name().c_str());
    }
}

void MultiDriverFixer::processWire(
    RTLIL::Wire *wire, size_t driverCount, size_t drivenCount, const RTLILWireConnections &connections) {
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
    RTLILAnyPtrSet inputs = connections.at(wire);
    // PERF We should re-use this from processWire since rtlilInverseLookup is O(n^2)
    auto outputs = rtlilInverseLookup(connections, wire);
    log_assert(inputs.size() == outputs.size() && !inputs.empty() && !outputs.empty());
    log_assert(inputs.size() == 3 && outputs.size() == 3);

    // ok, so we're gonna have 3 nodes: the original, replica1, and replica2 on either side
    // our mission is to link:
    //      LHS_replica1 -> wire1    -> RHS_replica1
    //      LHS_replica2 -> wire2    -> RHS_replica2
    //      LHS_orig     -> wireOrig -> RHS_orig

    auto lhsReplica1 = findByApproxName(inputs, "replica1");
    auto rhsReplica1 = findByApproxName(outputs, "replica1");
    log("Wire '%s':\n  LHS replica1: %s\n  RHS replica1: %s\n", log_id(wire->name),
        getRTLILName(lhsReplica1).c_str(), getRTLILName(rhsReplica1).c_str());

    auto lhsReplica2 = findByApproxName(inputs, "replica2");
    auto rhsReplica2 = findByApproxName(outputs, "replica2");
    log("Wire '%s':\n  LHS replica2: %s\n  RHS replica2: %s\n", log_id(wire->name),
        getRTLILName(lhsReplica2).c_str(), getRTLILName(rhsReplica2).c_str());

    // TODO is this std::get ok?? can we be sure it's a cell??
    reconnect(wire, std::get<RTLIL::Cell *>(lhsReplica1), std::get<RTLIL::Cell *>(rhsReplica1));
    reconnect(wire, std::get<RTLIL::Cell *>(lhsReplica2), std::get<RTLIL::Cell *>(rhsReplica2));

    // technically, we don't need to connect orig, it can keep connecting via the incorrect wire; so just skip
    // it
}

// NOLINTNEXTLINE(readability-convert-member-functions-to-static, bugprone-easily-swappable-parameters)
void MultiDriverFixer::reconnect(RTLIL::Wire *target, RTLIL::Cell *input, RTLIL::Cell *output) {
    CellTypes cellTypes(target->module->design);

    // find the port in the cell that is connected to the problematic wire
    // so input is basically going to be a cell that has an output going into our wire

    log("Reconnecting target '%s'\n  input '%s'\n  output '%s'\n", log_id(target->name), log_id(input->name),
        log_id(output->name));

    for (const auto &connection : input->connections()) {
        const auto &[name, signal] = connection;
        // TODO I don't like this, I think it might be causing problems. why not operate with connWire
        // directly?
        auto *connWire = sigSpecToWire(signal);

        if (cellTypes.cell_output(input->type, name) && connWire == target) {
            // ok, now we need to find the opposite: for the output cell, which input port is connected
            // to the problematic wire?
            auto outputCellPort = locateInputPortConnectedToTarget(target, output, cellTypes);

            // we need to apparently make an intermediary wire too
            auto *wire = input->module->addWire(NEW_ID_SUFFIX("MultiDriverFixer"), connWire->width);
            DUMPASYNC;

            // finalise the connection
            // FIXME I think this can cause problems on some circuits
            input->setPort(name, wire);
            DUMPASYNC;
            output->setPort(outputCellPort, wire);
            DUMPASYNC;

            input->check();
            output->check();
            input->module->check();

            // we can safely return, we don't have to worry about multiple ports like in the last
            // iteration of this code because we know there can only be one connection between this
            // cell and the problematic wire; and this is the one (we checked connWire == target)
            return;
        }
    }

    log_error("TaMaRa internal error: Could not find an output port from input cell '%s' that connects to "
              "wire '%s'\n",
        log_id(input->name), log_id(target->name));
}

} // namespace tamara
