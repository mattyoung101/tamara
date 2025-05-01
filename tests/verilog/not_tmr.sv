// Very simple example of a single bit inverter/NOT gate

module not_tmr(
    (* tamara_voter *)
    input logic a,
    (* tamara_voter *)
    output logic o,
    (* tamara_error_sink *)
    (* tamara_voter *)
    output logic err
);

assign o = !a;

// `ifndef TAMARA
// assign err = 0;
// `endif

endmodule
