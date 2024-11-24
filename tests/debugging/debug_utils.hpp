// TaMaRa: An automated triple modular redundancy EDA flow for Yosys.
//
// Copyright (c) 2024 Matt Young.
//
// This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL
// was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
#pragma once
#include <verilated.h>
#include <verilated_fst_c.h>

/// Sets up a Verilator test
#define SETUP_VERILATOR(traceName, typeName)            \
    VerilatedContext *context = new VerilatedContext(); \
    context->traceEverOn(true);                         \
    context->randSeed(0xB0FA);                          \
    context->randReset(2);                              \
                                                        \
    auto dut = new typeName(context);                   \
    auto trace = new VerilatedFstC();                   \
    context->time(0);                                   \
    dut->trace(trace, 99);                              \
    trace->open(traceName ".vcd");            \
    std::cout << "[Testbench] Starting test: " << (traceName) << std::endl << std::flush;

/// Finalises a Verilator test
#define FINALISE_VERILATOR(traceName)                                  \
    dut->final();                                                      \
    trace->close();                                                    \
    delete dut;                                                        \
    delete trace;                                                      \
    delete context;                                                    \
    std::cout << "[Testbench] Test completed" << std::endl << std::endl << std::flush;
