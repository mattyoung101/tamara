// Gold circuit without voter
(* tamara_triplicate *)
module not_voter_gold(
    input logic a,
    output logic o
);

assign o = !a;

endmodule

////////////////////////////////////////////

// Gate circuit with voter, should be functionally equivalent to gold circuit
module not_voter_gate(
    input logic a,
    output logic o
);

logic o1;
logic o2;
logic o3;
logic err;

assign o1 = !a;
assign o2 = !a;
assign o3 = !a;

voter voter(
    .a(o1),
    .b(o2),
    .c(o3),
    .out(o),
    .err(err)
);

endmodule


// module not_voter(
//     input logic a,
//     input logic clk,
//     output logic o
// );
//
// logic ff1;
// logic ff2;
// logic ff3;
// logic err;
//
// always_ff @(posedge clk) begin
//     ff1 <= a;
//     ff2 <= a;
//     ff3 <= a;
// end
//
// voter voter(
//     .a(ff1),
//     .b(ff2),
//     .c(ff3),
//     .out(o),
//     .err(err)
// );
//
// endmodule
