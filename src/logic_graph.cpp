// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2024 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#include "tamara/logic_graph.hpp"
#include "kernel/log.h"
#include "kernel/rtlil.h"
#include "kernel/yosys_common.h"
#include <memory>
#include <optional>

USING_YOSYS_NAMESPACE;

void tamara::LogicCone::search(RTLIL::Module *module, RTLIL::Wire *output) {
    log_assert(frontier.empty());
    log_assert(cone.empty());

    // we can fill in the output directly
    outputNode = std::make_shared<IONode>(output);
    cone.push_back(outputNode);
    frontier.push(outputNode);
}
