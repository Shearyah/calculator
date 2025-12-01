// 4 * 4 按键矩阵扫描和滤波, 共 16 个按键
// 此模块不假设任何按键含义, 因此不用于解码
// 允许多个按键同时按下
// TODO: 无法处理 同一列同时按下多个按键 的情况
module key_filter(
    input clk, // 5ms按键扫描时钟, 适当扫描间隔用于滤波
    input rst_n, // 复位低有效, 开机时用于清空所有内部寄存器
    input [3:0] col, //被动列接收, 根据电路图, 低有效
    output reg[3:0] row, //主动行扫描
    output [15:0] state //按键状态, 按下为1
);
reg [15:0] btn;
reg [15:0] btn0;
reg [15:0] btn1;
reg [1:0] cnt;

assign state = btn0 & btn1; // 滤波后的当前按键状态

// 上升沿切换输出
// 此时 cnt 稳定, row 不稳定
always @ (posedge clk) begin
	if (!rst_n) begin
    	btn0 <= 16'd0;
        btn1 <= 16'd0;
        row <= 4'b1110;
    end else begin
        row <= ~(4'b0001 << cnt);
        case (cnt[1:0]) // cnt 在上一个下降沿递增了, 所以此处从 2'b01 开始
        2'b01: begin 
            btn0[3:0] <= btn[3:0];
            btn1[3:0] <= btn0[3:0];
        end
        2'b10: begin
            btn0[7:4] <= btn[7:4];
            btn1[7:4] <= btn0[7:4];
        end
        2'b11: begin
            btn0[11:8] <= btn[11:8];
            btn1[11:8] <= btn0[11:8];
        end
        2'b00: begin 
            btn0[15:12] <= btn[15:12];
            btn1[15:12] <= btn0[15:12];
        end
        default: ; // 什么都不做
        endcase
    end
end

// 下降沿采样输入
// 此时 row 稳定, cnt 变化
always @(negedge clk) begin
    if(!rst_n) begin // 复位
        btn <= 16'd0;
    end else begin
        case (row[3:0])
        4'b1110: btn[3:0] <= ~col;
        4'b1101: btn[7:4] <= ~col;
        4'b1011: btn[11:8] <= ~col;
        4'b0111: btn[15:12] <= ~col;
        default: btn <= 16'd0;
        endcase
        cnt <= (cnt == 3) ? 0 : cnt + 1;
    end
end

endmodule

module key_press(
    input clk,
    input rst_n,
    input [15:0] state, // 按键状态, 高有效
    output [15:0] press // 按键按下瞬间, 高有效
);

// 使用打两拍的方式进行边沿检测，确保脉冲宽度为一个时钟周期
// 且脉冲在 posedge 产生，覆盖随后的 negedge
reg [15:0] key_d1;
reg [15:0] key_d2;

always @(posedge clk) begin
	if (!rst_n) begin
        key_d1 <= 16'd0;
        key_d2 <= 16'd0;
    end else begin
        key_d1 <= state;
        key_d2 <= key_d1;
    end
end

assign press = key_d1 & ~key_d2;

endmodule

