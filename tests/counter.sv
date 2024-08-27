// 16 bit counter
(* tamara_triplicate *)
module counter(
    input logic i_clk,
    input logic i_rst,
    output logic[15:0] o_count
);

logic[15:0] count;

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
