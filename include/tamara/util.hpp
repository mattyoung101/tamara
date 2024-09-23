// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2024 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#pragma once
#include "kernel/rtlil.h"
#include "kernel/yosys_common.h"
#include <unordered_map>
#include <unordered_set>
#include <variant>

USING_YOSYS_NAMESPACE;

namespace tamara {

const auto TRIPLICATE_ANNOTATION = ID(tamara_triplicate);
const auto IGNORE_ANNOTATION = ID(tamara_ignore);
const auto REPLICA_ANNOTATION = ID(tamara_replica);
const auto CONE_ANNOTATION = ID(tamara_cone);
const auto ORIGINAL_ANNOTATION = ID(tamara_original);

//! Pointer to any RTLIL object
using RTLILAnyPtr = std::variant<RTLIL::Wire*, RTLIL::Cell*>;

//! Mapping of connections between a wire and all RTLIL objects its connected to
using RTLILWireConnections = std::unordered_map<RTLIL::Wire*, std::unordered_set<RTLILAnyPtr>>;

//! Returns true if the cell is a DFF.
constexpr bool isDFF(const RTLIL::Cell *cell) {
    // this logic is borrowed from Yosys wreduce.cc
    return cell->type.in(ID($dff), ID($dffe), ID($adff), ID($adffe), ID($sdff), ID($sdffe), ID($sdffce),
        ID($dlatch), ID($adlatch));
}

} // namespace tamara
