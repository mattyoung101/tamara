// This is an attempt to replicate the problems in not_dff_tmr, but using an entirely combinatorial circuit

// module passthru(
//     input logic a,
//     output logic o
// );
// assign o = a;
// endmodule

(* tamara_triplicate *)
module passthru_tmr(
    input logic a,
    output logic o,
    (* tamara_error_sink *)
    output logic err
);

logic internal;

// passthru pt(
//     .a(a),
//     .o(internal)
// );

assign internal = !a;

assign o = !internal;

`ifndef TAMARA
assign err = 0;
`endif

endmodule
