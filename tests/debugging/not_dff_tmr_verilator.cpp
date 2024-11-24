#include "debug_utils.hpp"
#include "Vnot_dff_tmr_tb.h"
#include <cstdio>

int main() {
    SETUP_VERILATOR("not_dff_tmr_verilator", Vnot_dff_tmr_tb);

    context->randReset();

    for (int i = 0; i < 100; i++) {
        for (int clock = 0; clock < 2; clock++) {
            dut->eval();
            trace->dump(context->time());
            context->timeInc(10);
            // dut->rootp->testbench__DOT__clk = !dut->rootp->testbench__DOT__clk;
            dut->clk = !dut->clk;
        }
    }

    FINALISE_VERILATOR("not_dff_tmr_verilator");
}
