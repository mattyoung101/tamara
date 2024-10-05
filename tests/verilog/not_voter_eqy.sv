// Test that checks that a simple circuit is equivalent when manually replicating elements and inserting a
// voter.

// Gold circuit without voter
(* tamara_triplicate *)
module inverter(
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

inverter not1(.a(a), .o(o1));
inverter not2(.a(a), .o(o2));
inverter not3(.a(a), .o(o3));

voter voter(
    .a(o1),
    .b(o2),
    .c(o3),
    .out(o),
    .err(err)
);

endmodule

