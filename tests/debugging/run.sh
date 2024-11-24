#!/bin/bash
# must be run from build directory
# ALL TEMPORARY this will be nuked

iverilog -g2005-sv -Wall ../tests/debugging/not_dff_tmr_tb.v -o not_dff_tmr
vvp not_dff_tmr
