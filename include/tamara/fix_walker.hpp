// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2025 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#pragma once
#include "kernel/yosys_common.h"

USING_YOSYS_NAMESPACE;

namespace tamara {

/// A FixWalker is a tool that walks over the RTLIL netlist, after it has been initially processed by TaMaRa,
/// and applies fix-ups to make it valid.
class FixWalker {
public:
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
    virtual void processWire(RTLIL::Wire *wire) { };
};

/// A @ref FixWalker that looks for wires with multiple drivers; where the inputs are replicated nodes, and
/// the outputs are voters.
class MultiDriverFixer : public FixWalker {
public:
    void processWire(RTLIL::Wire *wire) override;
};

}; // namespace tamara
