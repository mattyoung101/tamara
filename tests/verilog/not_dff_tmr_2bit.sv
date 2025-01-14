// Based on Logisim design in tests/manual_tests/not_gate_triplicate.circ
// This is just a 2-bit flip flop into a NOT gate

(* tamara_triplicate *)
module not_dff_tmr(
    input logic[1:0] a,
    input logic clk,
    output logic[1:0] o,
    (* tamara_error_sink *)
    output logic err
);

logic[1:0] ff;

always_ff @(posedge clk) begin
    ff <= a;
end

assign o = ~ff;

`ifndef TAMARA
assign err = 0;
`endif

endmodule
