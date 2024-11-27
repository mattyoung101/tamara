// 2 bit counter
(* tamara_triplicate *)
module counter(
    input logic i_clk,
    input logic i_rst,
    output logic[1:0] o_count
);

logic[1:0] count;

(* tamara_ignore *)
always_ff @(posedge i_clk) begin
    if (i_rst) begin
        count <= 0;
    end else begin
        count <= count + 1;
    end
end

assign o_count = count;

endmodule


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
