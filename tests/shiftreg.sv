// 16-bit parallel in, serial out shift register
module shiftreg_piso(
    input logic clk,
    input logic rst,
    input logic load,
    input logic[15:0] din,
    output logic dout
);

logic[15:0] temp;

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
            dout <= temp[15];
            // shift along temp
            temp <= { temp[14:0], 1'b0 };
        end
    end
end

endmodule
