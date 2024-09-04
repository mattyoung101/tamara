// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2024 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#include "kernel/rtlil.h"
#include "kernel/yosys_common.h"
#include "tamara/voter_builder.hpp"

USING_YOSYS_NAMESPACE

void tamara::VoterBuilder::build(RTLIL::Design *design) {
    // generate voter module with a unique name
    // TODO we may not want to generate a module?
    auto *module = design->addModule(NEW_ID_SUFFIX("tamara_voter"));
}
