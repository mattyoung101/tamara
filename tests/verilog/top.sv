module top(
    input logic i_clk,
    input logic i_rst,
    output logic[15:0] o_output
);

    logic[15:0] count;

    (* tamara_triplicate *)
    counter counter_inst(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .o_count(count)
    );

    assign o_output = count + 1;

endmodule
