module mux_1bit(
    input logic a,
    input logic b,
    input logic sel,
    output logic o
);
    assign o = sel ? a : b;
endmodule

module mux_2bit(
    input logic[1:0] a,
    input logic[1:0] b,
    input logic sel,
    output logic[1:0] o
);
    assign o = sel ? a : b;
endmodule
