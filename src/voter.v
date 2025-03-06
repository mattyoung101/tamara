// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2025 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// 1-bit majority voter in Verilog.
// Used for technology mapping.
(* keep *)
module VOTER (
    input A,
    input B,
    input C,
    output OUT,
    output ERR
);
    assign OUT = (A & B) | (B & C) | (A & C);
    assign ERR = (~A & C) | (A & ~B) | (B & ~C);
endmodule
