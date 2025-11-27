module bcd_handler (
    input [11:0] bcd_in,//当前已经累加的 BCD 值（3个十进制位，共12bit）
    input [3:0] digit,//这次新按下的数字键 0~9
    output [11:0] shift_out,//左移一位 + 新数字加到个位的“新 BCD 值”
    output [7:0] bin_out//当前 bcd_in 对应的 8 位二进制数值（0~255）
);
wire [11:0] shifted = {bcd_in[7:0], 4'd0};
wire [11:0] added = shifted + {8'd0, digit};
assign shift_out = (added > 12'd999) ? 12'd999 : added;

wire [7:0] calculated = bcd_in[3:0] + (bcd_in[7:4] * 4'd10) + (bcd_in[11:8] * 7'd100);
assign bin_out = (calculated > 8'd255) ? 8'd255 : calculated;

endmodule

