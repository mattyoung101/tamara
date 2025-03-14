module bug39  (y, clk, wire3, wire2, wire1, wire0);
  output wire [(32'hb):(32'h0)] y;
  input wire [(1'h0):(1'h0)] clk;
  input wire [(2'h3):(1'h0)] wire3;
  input wire signed [(2'h3):(1'h0)] wire2;
  input wire signed [(2'h2):(1'h0)] wire1;
  input wire [(2'h3):(1'h0)] wire0;
  wire signed [(2'h3):(1'h0)] wire7;
  wire signed [(2'h2):(1'h0)] wire4;
  reg signed [(2'h2):(1'h0)] reg6 = (1'h0);
  reg signed [(2'h3):(1'h0)] reg5 = (1'h0);
  assign y = {wire7, wire4, reg6, reg5, (1'h0)};
  assign wire4 = {(wire3 ? wire2 : wire0)};
  always
    @(posedge clk) begin
      reg5 <= (wire2 >> (wire1 ? wire0 : (8'ha0)));
    end
  always
    @(posedge clk) begin
      reg6 <= (wire0 ? (wire1 & reg5) : (wire4 ? wire4 : (8'ha0)));
    end
  assign wire7 = $signed((~|reg5));
endmodule
