// 1-bit majority voter
module voter(
    input logic a,
    input logic b,
    input logic c,
    output logic out,
    output logic err
);

    assign out = (a && b) || (b && c) || (a && c);
    assign err = (a && b && c) || (!a && !b && !c);

endmodule
