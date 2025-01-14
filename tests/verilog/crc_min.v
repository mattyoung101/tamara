// This is meant to be a minimum reproducer of crc2.v to reproduce the assert failure
module crc (
    input [1:0] in,
    output[1:0] out // FIXME THIS is the cause, the output being multi-bit
);
    assign out = {in[0] ^ in[1], 1'd0};
endmodule
