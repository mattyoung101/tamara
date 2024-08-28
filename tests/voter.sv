// Majority voter
module voter(
    input logic[15:0] a,
    input logic[15:0] b,
    input logic[15:0] c,
    output logic[15:0] out,
);

    assign out = (a && b) || (b && c) || (a && c);

endmodule
