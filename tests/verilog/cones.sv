// This example is meant to produce two logic cones
module cones(
    input logic a,
    input logic clk,
    output logic out
);

logic stage1;
logic stage2;

always_ff @(posedge clk) begin
    stage1 <= !a;
end

always_ff @(posedge clk) begin
    stage2 <= !stage1;
end

assign out = stage2;

endmodule

module cones_2bit(
    input logic[1:0] a,
    input logic clk,
    output logic[1:0] out
);

logic[1:0] stage1;
logic[1:0] stage2;

always_ff @(posedge clk) begin
    stage1 <= ~a;
end

always_ff @(posedge clk) begin
    stage2 <= ~stage1;
end

assign out = stage2;

endmodule
