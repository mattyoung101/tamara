// A very large multi-bit wiring circuit designed to stress test the system

(* tamara_triplicate *)
module not_32bit(
    input logic[31:0] a,
    output logic[31:0] o,
    (* tamara_error_sink *)
    output logic err
);

assign o = ~a;

endmodule
