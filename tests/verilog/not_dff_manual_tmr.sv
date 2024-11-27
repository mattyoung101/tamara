// Based on Logisim design in tests/manual_tests/not_gate_triplicate.circ
// This is just a flip flop into a NOT gate, that is manually replicated
module not_dff_tmr(
    input logic a,
    input logic clk,
    output logic o,
    output logic err
);

logic ff1;
logic ff2;
logic ff3;

always_ff @(posedge clk) begin
    {ff1, ff2, ff3} <= {3{a}};
end

voter voter(
    .a(ff1),
    .b(ff2),
    .c(ff3),
    .out(o),
    .err(err)
);

endmodule
