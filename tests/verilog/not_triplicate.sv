// Based on Logisim design in tests/manual_tests/not_gate_triplicate.circ

(* tamara_triplicate *)
module not_triplicate(
    input logic a,
    input logic clk,
    output logic o
);

logic ff;

always_ff @(posedge clk) begin
    ff <= a;
end

assign o = !ff;

endmodule
