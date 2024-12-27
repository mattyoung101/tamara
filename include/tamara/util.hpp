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
const auto VOTER_ANNOTATION = ID(tamara_voter);
const auto ERROR_SINK_ANNOTATION = ID(tamara_error_sink);

//! Pointer to an RTLIL wire or cell (not strictly "any", but for our use case it suffices)
using RTLILAnyPtr = std::variant<RTLIL::Wire *, RTLIL::Cell *>;

//! Mapping of connections between a wire and all RTLIL objects its connected to
using RTLILWireConnections = std::unordered_map<RTLILAnyPtr, std::unordered_set<RTLILAnyPtr>>;

//! Returns true if the cell is a DFF.
constexpr bool isDFF(const RTLIL::Cell *cell) {
    // this logic is borrowed from Yosys wreduce.cc
    return cell->type.in(ID($dff), ID($dffe), ID($adff), ID($adffe), ID($sdff), ID($sdffe), ID($sdffce),
        ID($dlatch), ID($adlatch));
}

//! Converts a SigSpec to a wire, if possible, otherwise returns nullptr
//! WARNING: MAY RETURN NULLPTR! BE CAREFUL. This is so it works better with legacy code.
constexpr RTLIL::Wire *sigSpecToWire(const RTLIL::SigSpec &sigSpec) {
    if (sigSpec.is_wire()) {
        return sigSpec.as_wire();
    }
    if (sigSpec.is_bit()) {
        return sigSpec.as_bit().wire;
    }
    if (!sigSpec.chunks().empty()) {
        // FIXME this is somewhat questionable and should be tested on more designs
        return sigSpec.chunks().front().wire;
    }

    // unhandled!
    return nullptr;
}

//! Asserts the pointer is not null
#define NOTNULL(ptr)                                                                                         \
    log_assert(((ptr) != nullptr) && "TaMaRa internal error: Unexpected null pointer '" #ptr "'!");

//! Crashes the application, indicating that the feature is not yet implemented
#define TODO log_error("TaMaRa internal error: Feature not yet implemented!\n");

} // namespace tamara
