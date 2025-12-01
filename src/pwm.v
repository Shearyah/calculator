// 用于输出PWM波, 本质是时钟分频
// period等于0时始终输出1 (即cnt始终为0不可能小于duty)
// period大于0时cnt在0~period之间循环增加, cnt 小于 duty 时输出1
// 注意由于只在上升沿触发, 所以分频系数至少是2
// period = 1, duty = 1 时是二分频
// 用于分频时为保证时钟的高电平和低电平时间相同, 需 period 为奇数且 duty = period / 2 + 1
// 名字中的 8u 表示占空比和周期均为8位无符号数
module pwm_8u (
    input clk, // 输入时钟
    input rst_n, // 复位信号，低有效, 复位后占空比为0
    input [7:0] duty, // 占空比，范围0-255
    input [7:0] period, // PWM周期，范围0-255
    output pwm // PWM输出信号
);

reg [7:0] cnt;

assign pwm = cnt < duty ? 1 : 0;

always @(posedge clk) begin
    if (!rst_n) begin
        cnt <= 8'd0;
    end else begin
        cnt <= cnt < period ? cnt + 8'd1 : 8'd0;
    end
end

endmodule

module pwm_32u (
    input clk, // 输入时钟
    input rst_n, // 复位信号，低有效, 复位后占空比为0
    input [31:0] duty, // 占空比，范围0-255
    input [31:0] period, // PWM周期，范围0-255
    output pwm // PWM输出信号
);

reg [31:0] cnt;

assign pwm = cnt < duty ? 1 : 0;

always @(posedge clk) begin
    if (!rst_n) begin
        cnt <= 31'd0;
    end else begin
        cnt <= cnt < period ? cnt + 31'd1 : 31'd0;
    end
end

endmodule