// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2024 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#pragma once
#include "kernel/rtlil.h"
#include "kernel/yosys_common.h"
#include <cstddef>

USING_YOSYS_NAMESPACE;

namespace tamara {

//! Used to build and insert voters into a Yosys RTLIL design.
class VoterBuilder {
public:
    //! Instantiates a new voter builder for the specified module
    VoterBuilder(RTLIL::Module *module) : module(module) {}

    //! Insert one voter into the design. The voter will use the number of bits in the input wires.
    //! You specify the `a, b` and `c` wires, as well as the output wire.
    void build(RTLIL::Wire *a, RTLIL::Wire *b, RTLIL::Wire *c, RTLIL::Wire *out);

    //! Finalises all of the voters in this module by OR'ing together all the intermediate error signals into
    //! a final error signal.
    void finalise(RTLIL::Wire *err);

    //! Returns the number of inserted voters
    size_t getSize();

private:
    RTLIL::Module *module;
    size_t size = 0;
    std::vector<RTLIL::Wire*> reductions;
};

}; // namespace tamara
