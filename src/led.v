// LED显示模块
// 功能是每个时钟周期只显示一个LED灯，通过快速切换实现多灯同时点亮的效果
// 省电
// 其他方面与直接用组合逻辑输出并无不同
module led(
    input clk, // 时钟
    input [7:0] data, // 输入数据
    output [7:0] led // LED显示
);

reg [2:0] scan_cnt; // 扫描计数器

assign led = data & (8'b00000001 << scan_cnt); // 逐位点亮

always @(posedge clk) begin
    scan_cnt <= scan_cnt + 1;
end

endmodule