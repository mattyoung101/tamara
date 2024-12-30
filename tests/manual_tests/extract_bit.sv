// This module contains a simple test to see how extracting bits generates RTLIL
module test(
    input logic[3:0] in,
    output logic out1,
    output logic out2,
    output logic[2:0] bus
);
    assign out1 = in[0];
    assign out2 = in[2];
    assign bus = in[2:0];
endmodule
