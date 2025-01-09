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
#include <algorithm>
#include <string>

USING_YOSYS_NAMESPACE;

namespace {

using namespace tamara;

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
    // TODO also note we may have this the wrong way around ("drivers" vs "driven by")
    auto wireDriversCount = computeWireIOCount(module, true);
    auto wireDrivenByCount = computeWireIOCount(module, false);
    log("Wire drivers count: %zu  Wire driven by count: %zu\n", wireDriversCount.size(),
        wireDrivenByCount.size());

    // also pre-compute another copy of RTLILWireConnections
    auto connections = analyseConnections(module);

    SigMap sigmap(module);

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
                    SigSpec sig = sigmap(signal);
                    auto *wire = sigSpecToWire(sig);

                    if (wire != nullptr && !processed.contains(wire)) {
                        walker->processWire(
                            wire, wireDriversCount[wire], wireDrivenByCount[wire], connections);
                        processed.insert(wire);
                    }
                }
            }
        }
        for (auto *wire : module->wires()) {
            if (!processed.contains(wire)) {
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
    std::unordered_set<RTLILAnyPtr> inputs = connections.at(wire);
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

    auto lhsReplica2 = findByApproxName(inputs, "replica2");
    auto rhsReplica2 = findByApproxName(outputs, "replica2");

    // TODO is this std::get ok?? can we be sure it's a cell??
    reconnect(wire, std::get<RTLIL::Cell *>(lhsReplica1), std::get<RTLIL::Cell *>(rhsReplica1));
    reconnect(wire, std::get<RTLIL::Cell *>(lhsReplica2), std::get<RTLIL::Cell *>(rhsReplica2));

    // TODO how do we find orig? it'll be the only index left we assume? I guess technically we don't need to?
}

// NOLINTNEXTLINE(readability-convert-member-functions-to-static, bugprone-easily-swappable-parameters)
void MultiDriverFixer::reconnect(RTLIL::Wire *target, Cell *input, Cell *output) {
    CellTypes cellTypes(target->module->design);

    // find the port in the cell that is connected to the problematic wire
    // so input is basically going to be a cell that has an output going into our wire

    for (const auto &connection : input->connections()) {
        const auto &[name, signal] = connection;
        auto *connWire = sigSpecToWire(signal);

        if (cellTypes.cell_output(input->type, name) && connWire == target) {
            // ok, now we need to find the opposite: for the output cell, which input port is connected
            // to the problematic wire?
            // FIXME I think this is outputting the wrong SigSpec! maybe we want to return the port name?
            auto outputCellPort = locateInputPortConnectedToTarget(target, output, cellTypes);

            // we need to apparently make an intermediary wire too
            // TODO is the width on this correct?
            auto *wire = input->module->addWire(NEW_ID_SUFFIX("MultiDriverFixer"));

            // finalise the connection
            input->setPort(name, wire);
            // log("Set port '%s' in input cell '%s' to port '%s' in output cell '%s'\n", log_id(name),
            //     log_id(input->name), log_signal(outputCellPort), log_id(output->name));
            output->setPort(outputCellPort, wire);

            input->check();
            output->check();
            input->module->check();

            // and now connect the intermediary to the RHS
            // input->module->connect(wire, outputCellPort);

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
