// This module contains a chain of OR signals so we can figure out how we're going to OR together all the
// voters
module test(
    input logic[7:0] a,
    input logic[7:0] b,
    input logic[7:0] c,
    output logic out
);
    assign out = (|a) | (|b) | (|c);
endmodule
