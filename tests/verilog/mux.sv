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

module mux_4bit(
    input logic[3:0] a,
    input logic[3:0] b,
    input logic sel,
    output logic[3:0] o
);
    assign o = sel ? a : b;
endmodule

module mux_8bit(
    input logic[7:0] a,
    input logic[7:0] b,
    input logic sel,
    output logic[7:0] o
);
    assign o = sel ? a : b;
endmodule

module mux_16bit(
    input logic[15:0] a,
    input logic[15:0] b,
    input logic sel,
    output logic[15:0] o
);
    assign o = sel ? a : b;
endmodule

module mux_24bit(
    input logic[23:0] a,
    input logic[23:0] b,
    input logic sel,
    output logic[23:0] o
);
    assign o = sel ? a : b;
endmodule

module mux_32bit(
    input logic[31:0] a,
    input logic[31:0] b,
    input logic sel,
    output logic[31:0] o
);
    assign o = sel ? a : b;
endmodule
