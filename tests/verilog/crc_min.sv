// This is meant to be a minimum reproducer of crc2.v to reproduce the assert failure
module crc_min (
    input [1:0] in,
    output[1:0] out // FIXME THIS is the cause, the output being multi-bit
);
    assign out = {in[0] ^ in[1], 1'd0};
endmodule

module crc_const_variant3(
    input logic[1:0] in,
    output logic[1:0] out
);
    wire zero_wire = 1'b0;
    assign out = {in[0] ^ in[1], zero_wire};
endmodule

module crc_const_variant4(input logic[1:0] in, output logic[1:0] out);
    // (1'b1 - 1'b1) evaluates to 0
    assign out = {in[0] ^ in[1], (1'b1 - 1'b1)};
endmodule

module crc_const_variant5(input logic [1:0] in, output logic [1:0] out);
    // (in[1] & ~in[1]) always equals 0 regardless of in[1]
    assign out = {in[0] ^ in[1], (in[1] & ~in[1])};
endmodule
