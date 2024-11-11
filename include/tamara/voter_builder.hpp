// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2024 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#pragma once
#include "kernel/log.h"
#include "kernel/rtlil.h"
#include "kernel/yosys_common.h"
#include <stdexcept>

USING_YOSYS_NAMESPACE;

namespace tamara {

//! Result from building a voter
class Voter {
public:
    RTLIL::Wire *a, *b, *c, *out, *err;

    RTLIL::Wire *operator[](int i) const {
        switch (i) {
            case 0: return a;
            case 1: return b;
            case 2: return c;
            default: log_error("Invalid voter operator[] index: %d\n", i);
        }
    }
};

//! Used to build and insert voters into a Yosys RTLIL design.
class VoterBuilder {
public:
    //! Insert one voter into the design.
    static Voter build(RTLIL::Module *module);
};

}; // namespace tamara
