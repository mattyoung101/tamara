// Very simple example of a single bit inverter/NOT gate

(* tamara_triplicate *)
module inverter(
    input logic a,
    output logic o,
    (* tamara_error_sink *)
    output logic err
);

assign o = !a;

endmodule


