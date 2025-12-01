module in(
    input clk,
    input rst_n,
    input [15:0] key,
    input start,
    output reg [7:0] num,
    output reg [2:0] op,
    output reg stop
);

wire [15:0] key_pulse;
// 实例化 key_press，将按键状态转换为单周期脉冲
// key_press 模块已在 key.v 中定义，且使用了打两拍逻辑确保时序稳定
key_press u_key_press(.clk(clk), .rst_n(rst_n), .state(key), .press(key_pulse));

reg [15:0] local_key;
reg local_start;

// 下降沿读取输入
// 由于 key_pulse 是在 posedge 更新并维持一个周期，
// 所以这里的 negedge 一定能采样到稳定的 key_pulse
always @(negedge clk) begin
    local_start <= start;
    local_key <= key_pulse;
end

always @(posedge clk) begin
	if (~rst_n) begin
    	stop <= 0;
        num <= 0;
        op <= 0;
    end else begin
        // 如果当前没有请求(stop=0)且没有收到确认(local_start=0)，则检测按键
    	if (~stop && ~local_start) begin
            if (local_key != 0) begin
                case (local_key)
                16'b0000_0000_0000_0001: begin num <= 8'd0; op <= 3'd1; stop <= 1;  end // DIV
                16'b0000_0000_0000_0010: begin num <= 8'd0; op <= 3'd2; stop <= 1;  end // ENT
                16'b0000_0000_0000_0100: begin num <= 8'd0; op <= 3'd0; stop <= 1;  end // 0
                16'b0000_0000_0000_1000: begin num <= 8'd0; op <= 3'd3; stop <= 1;  end // CLR
                16'b0000_0000_0001_0000: begin num <= 8'd0; op <= 3'd4; stop <= 1;  end // MUL
                16'b0000_0000_0010_0000: begin num <= 8'd3; op <= 3'd0; stop <= 1;  end // 6
                16'b0000_0000_0100_0000: begin num <= 8'd2; op <= 3'd0; stop <= 1;  end // 5
                16'b0000_0000_1000_0000: begin num <= 8'd1; op <= 3'd0; stop <= 1;  end // 4
                16'b0000_0001_0000_0000: begin num <= 8'd0; op <= 3'd5; stop <= 1;  end // SUB
                16'b0000_0010_0000_0000: begin num <= 8'd6; op <= 3'd0; stop <= 1;  end // 3
                16'b0000_0100_0000_0000: begin num <= 8'd5; op <= 3'd0; stop <= 1;  end // 2
                16'b0000_1000_0000_0000: begin num <= 8'd4; op <= 3'd0; stop <= 1;  end // 1
                16'b0001_0000_0000_0000: begin num <= 8'd0; op <= 3'd6; stop <= 1;  end // ADD
                16'b0010_0000_0000_0000: begin num <= 8'd9; op <= 3'd0; stop <= 1;  end // 9
                16'b0100_0000_0000_0000: begin num <= 8'd8; op <= 3'd0; stop <= 1;  end // 8
                16'b1000_0000_0000_0000: begin num <= 8'd7; op <= 3'd0; stop <= 1;  end // 7
                default: stop <= 0;
                endcase
            end
        end 
        // 如果正在请求(stop=1)且收到确认(local_start=1)，则结束请求
        else if (stop && local_start) begin
            stop <= 0;
            // 清除数据，防止误读
            num <= 0;
            op <= 0;
        end
        // 其他状态保持不变 (等待确认或等待确认取消)
    end
end

endmodule

// 主模块!
module calc(
    input clk, // 时钟
    input rst_n, // 复位, 低有效
    input [7:0] num,
    input [2:0] op,
    input start,
    output reg [15:0] result,
    output reg [15:0] display_val, // 用于数码管显示
    output [2:0] led_op, // 输出当前操作符给LED
    output reg stop
);

reg [15:0] local_result;
reg local_stop;

// 缓存操作数和结果
localparam ADD = 3'd6;
localparam SUB = 3'd5;
localparam MUL = 3'd4;
localparam DIV = 3'd1;
localparam ENT = 3'd2;
localparam CLR = 3'd3;
reg [15:0] a, b;
reg [2:0] local_op;
assign led_op = local_op; // 输出内部操作符状态

// 实例化计算模块
wire [15:0] res_add, res_sub, res_mul, res_div;
// 这里的 valid_in 暂时置 1，因为当前设计是组合逻辑/单周期
i16_add u_add(.a(a), .b(b), .valid_in(1'b1), .sum(res_add), .carry_out(), .ready_out());
i16_sub u_sub(.a(a), .b(b), .valid_in(1'b1), .diff(res_sub), .borrow_out(), .ready_out());
i16_mul u_mul(.a(a), .b(b), .valid_in(1'b1), .prod(res_mul), .ready_out());
i16_div u_div(.a(a), .b(b), .valid_in(1'b1), .quot(res_div), .ready_out());

// 状态定义
localparam S_INPUT_A = 2'b00;
localparam S_INPUT_B = 2'b01;
reg [2:0] state;

// 下降沿输入并计算
always @(negedge clk) begin
	if (~rst_n) begin
    	local_stop <= 0;
        a <= 0;
        b <= 0;
        local_result <= 0;
        display_val <= 0;
        local_op <= 0;
        state <= S_INPUT_A;
    end else begin
        if (~start&local_stop) begin
        // 结束状态
        local_stop <= 0;
        end else if (start&~local_stop) begin
            // 逻辑状态
            case (state)
            S_INPUT_A: begin
                if (op == CLR) begin
                    a <= 0; b <= 0; display_val <= 0; local_result <= 0; local_op <= 0;
                end else if (op == ADD || op == SUB || op == MUL || op == DIV) begin
                    local_op <= op;
                    b <= 0;
                    state <= S_INPUT_B;
                end else if (op == 0) begin
                    a <= a * 16'd10 + {8'd0, num};
                    display_val <= a * 16'd10 + {8'd0, num};
                end
            end
            S_INPUT_B: begin
                if (op == CLR) begin
                    a <= 0; b <= 0; display_val <= 0; local_result <= 0; local_op <= 0;
                    state <= S_INPUT_A;
                end else if (op == ENT) begin
                    case (local_op)
                    ADD: begin local_result <= res_add; display_val <= res_add; end
                    SUB: begin local_result <= res_sub; display_val <= res_sub; end
                    DIV: begin local_result <= res_div; display_val <= res_div; end
                    MUL: begin local_result <= res_mul; display_val <= res_mul; end
                    endcase
                    a <= 0;
                    local_op <= 0; // 计算完成后清除操作符显示
                    state <= S_INPUT_A;
                end else if (op == 0) begin
                    b <= b * 16'd10 + {8'd0, num};
                    display_val <= b * 16'd10 + {8'd0, num};
                end
            end
            endcase
            local_stop <= 1;
        end
    end
end

// 上升沿输出
always @(posedge clk) begin
    result <= local_result;
    stop <= local_stop;
end

endmodule

module core(
    input clk_20ns, // 系统时钟50MHz(周期为20ns)
    input rst_n, // 系统复位，低有效
    input [7:0] sw, // switch 拨码开关
    input [3:0] col, // 矩阵按键列捕捉
    output [3:0] row, // 矩阵按键行扫描
    output [7:0] led, // LED指示灯, 高有效
    output [7:0] seg, // 数码管段选
    output [3:0] an, // 数码管位选
    output beep // 蜂鸣器
);

wire [15:0] key_state;
wire [15:0] key_press;

// 分频
wire clk_2us, clk_100us, clk_5ms;
pwm_8u time_div0(.clk(clk_20ns), .rst_n(rst_n), .duty(8'd50), .period(8'd99), .pwm(clk_2us));
pwm_8u time_div1(.clk(clk_2us), .rst_n(rst_n), .duty(8'd25), .period(8'd49), .pwm(clk_100us));
pwm_8u time_div2(.clk(clk_100us), .rst_n(rst_n), .duty(8'd25), .period(8'd49), .pwm(clk_5ms));


/* 下降沿输入 */
// 读取矩阵按键输入
key_filter key_filter0(.clk(clk_5ms), .rst_n(rst_n), .col(col), .row(row), .state(key_state));
wire [7:0] num;
wire [2:0] op;
wire [15:0] result;
wire [15:0] display_val; // 新增
wire [2:0] led_op; // 新增：LED操作符
wire inToCalc, calcToIn;
// key_press 移入 in 模块内部
in in0(.clk(clk_100us), .rst_n(rst_n), .key(key_state), .start(calcToIn), .num(num), .op(op), .stop(inToCalc));
calc calc0(.clk(clk_100us), .rst_n(rst_n), .num(num), .op(op), .start(inToCalc), .result(result), .display_val(display_val), .led_op(led_op), .stop(calcToIn));

// 声音输出
buzzer buzzer0(.clk(clk_20ns), .idx(key_state != 0), .en(sw[4]), .beep(beep));

// LED输出
led led0(.clk(clk_100us), .data({5'd0, led_op}), .led(led));

// 数码管输出
digit_tube digit_tube0(.clk(clk_100us), .data_in(display_val), .seg(seg), .an(an));
endmodule