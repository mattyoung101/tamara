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

// NOLINTBEGIN(bugprone-macro-parentheses) These macros do not need parentheses
#define WIRE(A, B) auto A##_##B##_wire = module->addWire(NEW_ID_SUFFIX(#A "_" #B "_wire"));
#define NOT(number, A, B) module->addLogicNot(NEW_ID_SUFFIX("not" #number), A, B)
#define AND(number, A, B, Y) module->addLogicAnd(NEW_ID_SUFFIX("and" #number), A, B, Y)
#define OR(number, A, B, Y) module->addLogicOr(NEW_ID_SUFFIX("or" #number), A, B, Y)
// NOLINTEND(bugprone-macro-parentheses)

void tamara::VoterBuilder::build(RTLIL::Design *design) {
    // generate voter module with a unique name
    auto *module = design->addModule(NEW_ID_SUFFIX("tamara_voter"));

    // add inputs
    // these do NOT have the $, because they are public signals (see Yosys manual § 4.2.1)
    auto *a = module->addWire(ID(a));
    auto *b = module->addWire(ID(b));
    auto *c = module->addWire(ID(c));
    a->port_input = true;
    b->port_input = true;
    c->port_input = true;

    // add outputs
    auto *out = module->addWire(ID(out));
    auto *err = module->addWire(ID(err));
    out->port_output = true;
    err->port_output = true;

    // add wires to ports
    module->fixup_ports();

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

    module->check();
}
