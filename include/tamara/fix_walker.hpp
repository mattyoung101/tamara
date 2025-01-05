// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2025 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#pragma once
#include "kernel/rtlil.h"
#include "kernel/yosys_common.h"
#include "tamara/util.hpp"
#include <memory>
#include <string>
#include <vector>

USING_YOSYS_NAMESPACE;

namespace tamara {

/// A FixWalker is a tool that walks over the RTLIL netlist, after it has been initially processed by TaMaRa,
/// and applies fix-ups to make it valid.
class FixWalker {
public:
    FixWalker() = default;
    FixWalker(const FixWalker &) = default;
    FixWalker(FixWalker &&) = delete;
    FixWalker &operator=(const FixWalker &) = default;
    FixWalker &operator=(FixWalker &&) = delete;
    virtual ~FixWalker() = default;

    /// Processes the given module.
    virtual void processModule(RTLIL::Module *module) { };

    /// Processes the given cell in a module.
    virtual void processCell(RTLIL::Cell *cell) { };

    /// Processes the given wire in a module.
    virtual void processWire(RTLIL::Wire *wire, int driverCount, int drivenCount, const RTLILWireConnections &connections) { };

    virtual std::string name() {
        return "ERROR";
    };
};

/// A manager for executing a list of @ref FixWalker instances on a design.
class FixWalkerManager {
public:
    FixWalkerManager() = default;

    /// Adds a @ref FixWalker to be executed
    void add(const std::shared_ptr<FixWalker> &walker);

    /// Executes all added @ref FixWalkers on a design.
    void execute(RTLIL::Module *module);

private:
    std::vector<std::shared_ptr<FixWalker>> walkers;
};

/// A @ref FixWalker that looks for wires with multiple drivers; where the inputs are replicated nodes, and
/// the outputs are voters.
class MultiDriverFixer : public FixWalker {
public:
    MultiDriverFixer() = default;

    void processWire(RTLIL::Wire *wire, int driverCount, int drivenCount, const RTLILWireConnections &connections) override;

    std::string name() override {
        return "MultiDriverFixer";
    }

private:
    void rewire(RTLIL::Wire *wire, const RTLILWireConnections &connections);

    /// Disconnects the ports that point to the problematic wire, "target", given a set of input nodes that
    /// are connected to this wire (the variable "inputs")
    void disconnectProblematicWires(RTLIL::Wire *target, const std::unordered_set<RTLILAnyPtr> &inputs);
};

}; // namespace tamara
