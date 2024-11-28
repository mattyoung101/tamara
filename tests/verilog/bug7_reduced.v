// Test for https://github.com/mattyoung101/tamara/issues/7
// Generated with Verismith

(* tamara_triplicate *)
module top  (y, clk, wire3, wire2, wire1, wire0);
  output wire [(32'hc):(32'h0)] y;
  input wire [(1'h0):(1'h0)] clk;
  input wire signed [(2'h3):(1'h0)] wire3;
  input wire [(2'h2):(1'h0)] wire2;
  input wire [(2'h2):(1'h0)] wire1;
  input wire signed [(2'h2):(1'h0)] wire0;
  wire signed [(2'h2):(1'h0)] wire8;
  wire [(2'h2):(1'h0)] wire7;
  wire [(2'h2):(1'h0)] wire6;
  wire [(2'h3):(1'h0)] wire5;
  wire signed [(2'h2):(1'h0)] wire4;
  assign y = {wire8, wire7, wire6, wire5, wire4, (1'h0)};
  assign wire4 = $signed(wire1[(1'h0):(1'h0)]);
  assign wire5 = $signed((^wire4));
  assign wire6 = (+wire1[(1'h0):(1'h0)]);
  assign wire7 = (~&(8'h9e));
  assign wire8 = wire0[(1'h1):(1'h1)];
endmodule
