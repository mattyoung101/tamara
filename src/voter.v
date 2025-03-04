// 1-bit majority voter in Verilog
// Used for technology mapping.
(* keep *)
module VOTER (
    input A,
    input B,
    input C,
    output OUT,
    output ERR
);
    assign OUT = (A & B) | (B & C) | (A & C);
    assign ERR = (~A & C) | (A & ~B) | (B & ~C);
endmodule
