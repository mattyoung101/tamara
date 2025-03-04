// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2024-2025 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#pragma once
#include "ankerl/unordered_dense.hpp"
#include "kernel/rtlil.h"
#include "kernel/yosys_common.h"
#include <variant>

USING_YOSYS_NAMESPACE;

//! The main TaMaRa namespace
namespace tamara {

//! Asserts the pointer is not null
#define NOTNULL(ptr)                                                                                         \
    if ((ptr) == nullptr) {                                                                                  \
        log_error("TaMaRa internal error: Unexpected null pointer '%s'!\n", #ptr);                           \
    }

//! Crashes the application, indicating that the feature is not yet implemented
#define TODO log_error("TaMaRa internal error: Feature not yet implemented!\n");

/// Debug command to dump the graph of the design. Will only dump if the environment variable
/// TAMARA_DEBUG_DUMP is set.
#ifdef TAMARA_DEBUG
#define DUMP                                                                                                 \
    do {                                                                                                     \
        if (getenv("TAMARA_DEBUG_DUMP") != nullptr) {                                                        \
            Yosys::run_pass("show -colors 420 -pause -long");                                                \
        }                                                                                                    \
    } while (0);
#else
#define DUMP
#endif

/// Debug command to dump the RTLIL of the design. Will only dump if the environment variable
/// TAMARA_DEBUG_DUMP is set.
#ifdef TAMARA_DEBUG
#define DUMP_RTLIL                                                                                           \
    do {                                                                                                     \
        if (getenv("TAMARA_DEBUG_DUMP_RTLIL") != nullptr) {                                                  \
            Yosys::run_pass("write_rtlil");                                                                  \
        }                                                                                                    \
    } while (0);
#else
#define DUMP_RTLIL
#endif

/// Same as @ref DUMP, but runs in the background and does not halt the program. Will only dump if the
/// environment variable TAMARA_DEBUG_ASYNC_DUMP is set.
#ifdef TAMARA_DEBUG
#define DUMPASYNC tamara::dumpAsync(__FILE__, __LINE__);
#else
#define DUMPASYNC
#endif

const auto TRIPLICATE_ANNOTATION = ID(tamara_triplicate);
const auto IGNORE_ANNOTATION = ID(tamara_ignore);
const auto REPLICA_ANNOTATION = ID(tamara_replica);
const auto CONE_ANNOTATION = ID(tamara_cone);
const auto ORIGINAL_ANNOTATION = ID(tamara_original);
const auto VOTER_ANNOTATION = ID(tamara_voter);
const auto ERROR_SINK_ANNOTATION = ID(tamara_error_sink);

//! Pointer to an RTLIL wire or cell (not strictly "any", but for our use case it suffices)
using RTLILAnyPtr = std::variant<RTLIL::Wire *, RTLIL::Cell *>;

//! Unordered set of @ref RTLILAnyPtr
using RTLILAnyPtrSet = ankerl::unordered_dense::set<RTLILAnyPtr>;

//! Unordered set of @ref RTLIL::SigSpec
using RTLILSigSpecSet = ankerl::unordered_dense::set<RTLIL::SigSpec>;

//! Mapping of connections between a wire and all RTLIL objects its connected to
using RTLILWireConnections = ankerl::unordered_dense::map<RTLILAnyPtr, RTLILAnyPtrSet>;

//! Mapping of connections between an RTLILAnyPtr and all the RTLIL SigSpecs it is connected to
using RTLILAnySignalConnections = ankerl::unordered_dense::map<RTLILAnyPtr, RTLILSigSpecSet>;

//! Representation of connections in the original netlist
struct RTLILConnections {
    RTLILWireConnections wires;
    RTLILAnySignalConnections signals;
    //! Original cell outputs in the original circuit
    RTLILAnySignalConnections cellOutputs;
};

//! Returns true if the cell is a DFF.
bool isDFF(const RTLIL::Cell *cell);

//! Converts a SigSpec to a wire, if possible, <b>otherwise returns nullptr.</b>
RTLIL::Wire *sigSpecToWire(const RTLIL::SigSpec &sigSpec);

//! Casts an RTLILAnyPtr to an RTLIL::AttrObject
constexpr RTLIL::AttrObject *toAttrObject(const RTLILAnyPtr &ptr) {
    return std::visit(
        [](auto &&arg) {
            using T = std::decay_t<decltype(arg)>;
            if constexpr (std::is_same_v<T, RTLIL::Cell *>) {
                return dynamic_cast<RTLIL::AttrObject *>(arg);
            }
            if constexpr (std::is_same_v<T, RTLIL::Wire *>) {
                return dynamic_cast<RTLIL::AttrObject *>(arg);
            }
        },
        ptr);
}

//! Returns the RTLIL ID for a RTLILAnyPtr
RTLIL::IdString getRTLILName(const RTLILAnyPtr &ptr);

//! Analyses connections betweens wires/cells and the other wires or cells they're connected to
std::pair<RTLILWireConnections, RTLILAnySignalConnections> analyseConnections(const RTLIL::Module *module);

//! Analyses cell outputs in the original netlist
RTLILAnySignalConnections analyseCellOutputs(RTLIL::Module *module);

//! Performs a combination of @ref analyseConnections, @ref analyseSignalConnections and @ref
//! analyseCellOutputs
RTLILConnections analyseAll(RTLIL::Module *module);

//! RTLILWireConnections maps a -> (b, c, d, e); but what this function does is find "a" given say b, or c, or
//! d. Returns empty list if no results found.
std::vector<RTLILAnyPtr> rtlilInverseLookup(const RTLILWireConnections &connections, Wire *target);

//! Same as @ref rtlilInverseLookup, but for @ref RTLILAnySignalConnections
std::vector<RTLILAnyPtr> signalInverseLookup(
    const RTLILAnySignalConnections &connections, const RTLIL::SigSpec &target);

//! Called by the @ref DUMPASYNC macro to write out a dump to disk. Do not invoke manually.
void dumpAsync(const std::string &file, size_t line);

//! Generates random hex characters of the output length len
std::string generateRandomHex(size_t len);

} // namespace tamara

namespace std {
template <>
struct hash<RTLIL::SigSpec> {
    std::size_t operator()(const RTLIL::SigSpec &k) const {
        Hasher h;
        h = k.hash_into(h);
        return h.yield();
    }
};
}; // namespace std
