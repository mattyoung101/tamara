// Simple example of a 2 bit inverter

(* tamara_triplicate *)
module inverter(
    input logic[1:0] a,
    output logic[1:0] o,
    (* tamara_error_sink *)
    output logic err
);

assign o = ~a;

endmodule
