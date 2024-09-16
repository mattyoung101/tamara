// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2024 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#pragma once
#include "kernel/rtlil.h"
#include "kernel/yosys_common.h"

USING_YOSYS_NAMESPACE

namespace tamara {

const auto TRIPLICATE_ANNOTATION = ID(tamara_triplicate);
const auto IGNORE_ANNOTATION = ID(tamara_ignore);
const auto REPLICANT_ANNOTATION = ID(tamara_replicant);

//! Returns true if the cell is a DFF.
constexpr bool isDff(const RTLIL::Cell *cell) {
    // this logic is borrowed from Yosys wreduce.cc
    return cell->type.in(ID($dff), ID($dffe), ID($adff), ID($adffe), ID($sdff), ID($sdffe), ID($sdffce),
        ID($dlatch), ID($adlatch));
}

} // namespace tamara
