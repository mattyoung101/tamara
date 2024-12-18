// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2024 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#include "tamara/voter_builder.hpp"
#include "kernel/log.h"
#include "kernel/rtlil.h"
#include "kernel/yosys_common.h"
#include "tamara/util.hpp"

USING_YOSYS_NAMESPACE;

// NOLINTBEGIN(bugprone-macro-parentheses) These macros do not need parentheses
#define WIRE(A, B) auto A##_##B##_wire = makeAsVoter(module->addWire(NEW_ID_SUFFIX(#A "_" #B "_wire")));
#define NOT(number, A, B) makeAsVoter(module->addLogicNot(NEW_ID_SUFFIX("not" #number), A, B))
#define AND(number, A, B, Y) makeAsVoter(module->addLogicAnd(NEW_ID_SUFFIX("and" #number), A, B, Y))
#define OR(number, A, B, Y) makeAsVoter(module->addLogicOr(NEW_ID_SUFFIX("or" #number), A, B, Y))
// NOLINTEND(bugprone-macro-parentheses)

using namespace tamara;

namespace {

//! Makes sure that the RTLIL object is marked as a voter. This is mainly for the benefit of fault injection
//! testing, so that it doesn't flip the bits of voters.
template <typename T>
constexpr T makeAsVoter(T obj) {
    // we don't explicitly add (* tamara_ignore *), in case we want to process the circuit multiple times
    // intentionally as a test
    obj->set_bool_attribute(VOTER_ANNOTATION);
    return obj;
}

}; // namespace

namespace {

//! Inserts one voter. This also takes an error signal, which should be eventually routed through a $reduce_or
//! cell.
// NOLINTNEXTLINE(bugprone-easily-swappable-parameters)
void buildOne(RTLIL::Module *module, RTLIL::Wire *a, RTLIL::Wire *b, RTLIL::Wire *c, RTLIL::Wire *out,
    RTLIL::Wire *err) {
    // N.B. This is all based on the Logisim design (tests/manual_tests/simple_tmr.circ)

    // NOT
    // a -> not0 -> and2
    WIRE(not0, and2);
    NOT(0, a, not0_and2_wire);

    // b -> not1 -> and3
    WIRE(not1, and3);
    NOT(1, b, not1_and3_wire);

    // c -> not2 -> and5
    WIRE(not2, and5);
    NOT(2, c, not2_and5_wire);

    // AND
    // b, c -> and0 -> or0
    WIRE(and0, or0);
    AND(0, b, c, and0_or0_wire);

    // a, c -> and1 -> or0
    WIRE(and1, or0);
    AND(1, a, c, and1_or0_wire);

    // not0, c -> and2 -> or1
    WIRE(and2, or1);
    AND(2, not0_and2_wire, c, and2_or1_wire);

    // not1, a -> and3 -> or1
    WIRE(and3, or1);
    AND(3, not1_and3_wire, a, and3_or1_wire);

    // a, b -> and4 -> or2
    WIRE(and4, or2);
    AND(4, a, b, and4_or2_wire);

    // not2, b -> and5 -> or3
    WIRE(and5, or3);
    AND(5, not2_and5_wire, b, and5_or3_wire);

    // OR
    // and0, and1 -> or0 -> or2
    WIRE(or0, or2);
    OR(0, and0_or0_wire, and1_or0_wire, or0_or2_wire);

    // and2, and3 -> or1 -> or3
    WIRE(or1, or3);
    OR(1, and2_or1_wire, and3_or1_wire, or1_or3_wire);

    // or0, and4 -> or2 -> out
    OR(2, or0_or2_wire, and4_or2_wire, out);

    // or1, and5 -> or3 -> err
    OR(3, or1_or3_wire, and5_or3_wire, err);
}

}; // namespace

void VoterBuilder::build(RTLIL::Wire *a, RTLIL::Wire *b, RTLIL::Wire *c, RTLIL::Wire *out) {
    NOTNULL(module);
    NOTNULL(a);
    NOTNULL(b);
    NOTNULL(c);
    NOTNULL(out);
    log_assert((a->width == b->width && a->width == c->width && b->width == c->width) && "Mismatch between input wire sizes");

    auto bits = a->width;
    log_assert(out->width == bits && "Output wire size mismatch");

    // the ERROR wire is as wide as the number of input bits, we'll $reduce_or this down later; and then later
    // route it to the global module error signal
    auto *err = module->addWire(NEW_ID_SUFFIX("ERR"), bits);

    log("Inserting voter in module %s for a: %s, b: %s, c: %s\n", log_id(module->name), log_id(a->name),
        log_id(b->name), log_id(c->name));

    // generate one unique voter per bit
    for (int bit = 0; bit < bits; bit++) {
        log("Adding voter for bit %d\n", bit);

        // extract bits from wire
        auto *a_bit = makeAsVoter(module->addWire(NEW_ID_SUFFIX("a_bit_" + std::to_string(bit))));
        auto *b_bit = makeAsVoter(module->addWire(NEW_ID_SUFFIX("b_bit_" + std::to_string(bit))));
        auto *c_bit = makeAsVoter(module->addWire(NEW_ID_SUFFIX("c_bit_" + std::to_string(bit))));
        auto *out_bit = makeAsVoter(module->addWire(NEW_ID_SUFFIX("out_bit_" + std::to_string(bit))));
        auto *err_bit = makeAsVoter(module->addWire(NEW_ID_SUFFIX("err_bit_" + std::to_string(bit))));

        // TODO we need to use RTLIL::SigChunk, which we should add as a port to the voter in buildOne

        // select bits from wires
        // for (auto *wire : { a_bit, b_bit, c_bit, out_bit, err_bit }) {
        //     wire->start_offset = bit;
        //     wire->upto = true;
        // }

        // connect a, b, c, out, err to input wires
        // TODO

        buildOne(module, a_bit, b_bit, c_bit, out_bit, err_bit);
        size++;
    }

    // insert $reduce_or reduction to OR every err bit in the voter

    // TODO we need to reconsider how the error signal is going to work, we need to sink the error into an
    // internal buffer and then AND them all together
    // ---
    // I think we need a $reduce_or cell somewhere (maybe instead of the last $or cell?)

    module->check();
}

void VoterBuilder::finalise(RTLIL::Wire *err) {
    if (err->width != 1) {
        log_error(
            "Voter error signal '%s' should be 1 bit. Yours is %d bits.", log_id(err->name), err->width);
    }
}
