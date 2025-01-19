// 4-bit parallel in, serial out shift register
(* tamara_triplicate *)
module shiftreg(
    input logic clk,
    input logic rst,
    input logic load,
    input logic[3:0] din,
    output logic dout,
    (* tamara_error_sink *)
    output logic err
);

logic[3:0] temp;

always_ff @(posedge clk) begin
    if (rst) begin
        dout <= 0;
        temp <= 0;
    end else begin
        if (load) begin
            // load din into temp
            temp <= din;
        end else begin
            // dout is the high bit
            dout <= temp[3];
            // shift along temp
            temp <= { temp[2:0], 1'b0 };
        end
    end
end

endmodule
