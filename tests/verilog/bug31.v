module top  (y, clk, wire2, wire1, wire0);
  output wire [(32'hc):(32'h0)] y;
  input wire [(1'h0):(1'h0)] clk;
  input wire signed [(2'h3):(1'h0)] wire2;
  input wire [(2'h2):(1'h0)] wire1;
  input wire [(2'h2):(1'h0)] wire0;
  wire [(2'h3):(1'h0)] wire5;
  reg signed [(2'h3):(1'h0)] reg6 = (1'h0);
  reg [(2'h2):(1'h0)] reg4 = (1'h0);
  assign y = {wire5, reg6, reg4, (1'h0)};
  always
    @(posedge clk) begin
      reg4 <= wire0;
    end
  assign wire5 = $signed((wire1 << reg4));
  always
    @(posedge clk) begin
      reg6 <= wire2[0];
    end
endmodule
