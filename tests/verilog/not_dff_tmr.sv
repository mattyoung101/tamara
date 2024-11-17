// Based on Logisim design in tests/manual_tests/not_gate_triplicate.circ
// This is just a flip flop into a NOT gate

(* tamara_triplicate *)
module not_dff_tmr(
    input logic a,
    input logic clk,
    output logic o,
    (* tamara_error_sink *)
    output logic err
);

logic ff;

always_ff @(posedge clk) begin
    ff <= a;
end

assign o = !ff;

endmodule
