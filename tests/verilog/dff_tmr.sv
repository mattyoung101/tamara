// This is the same as not_dff_tmr but without the NOT gate

(* tamara_triplicate *)
module dff_tmr(
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

assign o = ff;

endmodule
