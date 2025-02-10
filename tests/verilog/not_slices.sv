module not_slice(
    input logic a,
    input logic b,
    output logic[1:0] out
);
    assign out = { !a, !b };
endmodule


module not_swizzle_low(
    input logic a,
    output logic[1:0] out

);
    assign out = { !a, 1'd0 };
endmodule


module not_swizzle_high(
    input logic a,
    output logic[1:0] out

);
    assign out = { 1'd0, !a };
endmodule
