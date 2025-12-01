// 计算模块

// 半加器
module half_addr(
    input a,
    input b,
    output sum,
    output carry // 进位
);
assign sum = a ^ b;
assign carry = a & b;
endmodule

// 全加器
module full_addr(
    input a,
    input b,
    input cin, // 进位输入
    output sum,
    output carry // 进位输出
);
assign sum = a ^ b ^ cin;
assign carry = (a & b) | (cin & (a ^ b));
endmodule

// 4位无符号加法器(实际上有符号和无符号的计算逻辑完全相同)
// 使用超前进位降低延迟
// 带有时序通信
module i4_addr(
    input  [3:0] a,          // 4位加数A
    input  [3:0] b,          // 4位加数B
    input        cin,        // 组内初始进位（分组时为组间进位输入）
    input        valid_in,   // 输入有效（握手：启动计算）
    output [3:0] sum,        // 4位和
    output       group_g,    // 组生成项（分组扩展用）
    output       group_p,    // 组传播项（分组扩展用）
    output       ready_out   // 输出就绪（握手：计算完成）
);

// ---------------------- 1. 超前进位核心逻辑 ----------------------
// 步骤1：计算组内每一位的生成项g、传播项p
wire [3:0] g, p;
assign g = a & b;          // 位生成项：g[i] = a[i] & b[i]
assign p = a | b;          // 位传播项：p[i] = a[i] | b[i]

// 步骤2：计算组内进位（超前进位，无链式延迟）
wire c1, c2, c3;
assign c1 = g[0] | (p[0] & cin);
assign c2 = g[1] | (p[1] & g[0]) | (p[1] & p[0] & cin);
assign c3 = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & cin);

// 步骤3：计算组生成项/组传播项（分组扩展核心）
assign group_g = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]);
assign group_p = p[3] & p[2] & p[1] & p[0];

// 步骤4：计算组内和
assign sum[0] = a[0] ^ b[0] ^ cin;
assign sum[1] = a[1] ^ b[1] ^ c1;
assign sum[2] = a[2] ^ b[2] ^ c2;
assign sum[3] = a[3] ^ b[3] ^ c3;

// ---------------------- 2. 异步握手时序逻辑 ----------------------
// 核心：ready_out = valid_in 延迟加法器传播延迟后置位
// 注：实际硬件中无需手动加延迟（依赖门级自然延迟），此处为仿真可视化作模拟
reg ready_out_reg;
always @(*) begin
    if (valid_in) begin
        ready_out_reg = 1'b1;
    end else begin
        ready_out_reg = 1'b0;
    end
end
assign ready_out = ready_out_reg;

endmodule

// 8位无符号加法器
// 分组超前进位
module i8_addr(
    input  [7:0] a,          // 8位加数A
    input  [7:0] b,          // 8位加数B
    input        cin,        // 组内初始进位（16位复用为组间进位输入）
    input        valid_in,   // 输入有效（握手：启动计算）
    output [7:0] sum,        // 8位和
    output       group_g,    // 组生成项（16位复用的组间进位计算）
    output       group_p,    // 组传播项（16位复用的组间进位计算）
    output       ready_out   // 输出就绪（握手：计算完成）
);

// ---------------------- 1. 拆分8位为两个4位组 ----------------------
wire [3:0] a_low  = a[3:0];
wire [3:0] a_high = a[7:4];
wire [3:0] b_low  = b[3:0];
wire [3:0] b_high = b[7:4];

// ---------------------- 2. 组间信号定义 ----------------------
wire c4;               // 高4位组的cin（4位组间进位）
wire g_low, p_low;     // 低4位组生成/传播项
wire g_high, p_high;   // 高4位组生成/传播项
wire ready_low, ready_high;

// ---------------------- 3. 例化可复用4位模块 ----------------------
i4_addr cla_low(
    .a(a_low), .b(b_low), .cin(cin), .valid_in(valid_in),
    .sum(sum[3:0]), .group_g(g_low), .group_p(p_low), .ready_out(ready_low)
);

i4_addr cla_high(
    .a(a_high), .b(b_high), .cin(c4), .valid_in(valid_in),
    .sum(sum[7:4]), .group_g(g_high), .group_p(p_high), .ready_out(ready_high)
);

// ---------------------- 4. 8位组内进位计算（组间4位→8位） ----------------------
assign c4 = g_low | (p_low & cin);

// ---------------------- 5. 8位组生成/传播项（供16位复用） ----------------------
// 8位组生成项：本组能自产进位（和cin无关）
assign group_g = g_high | (p_high & g_low);
// 8位组传播项：本组能透传cin到16位的高8位组
assign group_p = p_high & p_low;

// ---------------------- 6. 8位整体握手信号 ----------------------
assign ready_out = ready_low & ready_high;

endmodule

// 16位加法
// 与16位加法器的区别: 无组间进位输出, 组生成项和组传播项
module i16_add(
    input  [15:0] a,         // 16位加数A
    input  [15:0] b,         // 16位加数B
    input        valid_in,   // 输入有效（握手：启动16位计算）
    output [15:0] sum,       // 16位和
    output       carry_out,  // 整体进位输出
    output       ready_out   // 输出就绪（握手：16位计算完成）
);

// ---------------------- 1. 拆分16位为两个8位组 ----------------------
wire [7:0] a_low  = a[7:0];  // 低8位组
wire [7:0] a_high = a[15:8]; // 高8位组
wire [7:0] b_low  = b[7:0];
wire [7:0] b_high = b[15:8];

// ---------------------- 2. 组间信号定义 ----------------------
wire c0, c8;               // c0=整体初始进位，c8=高8位组cin（8位组间进位）
wire g_low, p_low;         // 低8位组生成/传播项
wire g_high, p_high;       // 高8位组生成/传播项
wire ready_low, ready_high;// 两个8位组的就绪信号
assign c0 = 1'b0;          // 无符号加法初始进位为0

// ---------------------- 3. 例化两个8位可复用模块 ----------------------
i8_addr cla_low_8bit(
    .a(a_low), .b(b_low), .cin(c0), .valid_in(valid_in),
    .sum(sum[7:0]), .group_g(g_low), .group_p(p_low), .ready_out(ready_low)
);

i8_addr cla_high_8bit(
    .a(a_high), .b(b_high), .cin(c8), .valid_in(valid_in),
    .sum(sum[15:8]), .group_g(g_high), .group_p(p_high), .ready_out(ready_high)
);

// ---------------------- 4. 16位组间进位计算 ----------------------
assign c8 = g_low | (p_low & c0);                  // 高8位组的cin
assign carry_out = g_high | (p_high & g_low) | (p_high & p_low & c0); // 16位整体进位

// ---------------------- 5. 16位整体握手信号 ----------------------
assign ready_out = ready_low & ready_high;

endmodule

// 16位补码减法器
// 复用加法器逻辑: A - B = A + (~B) + 1
module i16_sub(
    input  [15:0] a,         // 16位被减数
    input  [15:0] b,         // 16位减数
    input        valid_in,   // 输入有效
    output [15:0] diff,      // 16位差
    output       borrow_out, // 借位输出 (注意：减法中 Carry=0 代表借位，Carry=1 代表无借位)
    output       ready_out   // 输出就绪
);

// ---------------------- 1. 构造补码输入 ----------------------
wire [15:0] b_neg = ~b; // 取反

// ---------------------- 2. 拆分16位为两个8位组 ----------------------
wire [7:0] a_low  = a[7:0];
wire [7:0] a_high = a[15:8];
wire [7:0] b_low  = b_neg[7:0];
wire [7:0] b_high = b_neg[15:8];

// ---------------------- 3. 组间信号定义 ----------------------
wire c0, c8;               
wire g_low, p_low;         
wire g_high, p_high;       
wire ready_low, ready_high;
wire carry_result;

assign c0 = 1'b1;          // 减法：加1 (A + ~B + 1)

// ---------------------- 4. 复用8位加法器模块 ----------------------
i8_addr cla_low_8bit(
    .a(a_low), .b(b_low), .cin(c0), .valid_in(valid_in),
    .sum(diff[7:0]), .group_g(g_low), .group_p(p_low), .ready_out(ready_low)
);

i8_addr cla_high_8bit(
    .a(a_high), .b(b_high), .cin(c8), .valid_in(valid_in),
    .sum(diff[15:8]), .group_g(g_high), .group_p(p_high), .ready_out(ready_high)
);

// ---------------------- 5. 进位链计算 ----------------------
assign c8 = g_low | (p_low & c0);
assign carry_result = g_high | (p_high & g_low) | (p_high & p_low & c0);

// 借位输出：减法中，如果加法产生进位(carry_result=1)，说明 A >= B，无借位(borrow=0)
// 如果无进位(carry_result=0)，说明 A < B，有借位(borrow=1)
assign borrow_out = ~carry_result;

assign ready_out = ready_low & ready_high;

endmodule

// 16位补码乘法器
// 移位加法实现，避免使用 * 运算符
module i16_mul(
    input signed [15:0] a,   // 16位有符号乘数
    input signed [15:0] b,   // 16位有符号乘数
    input        valid_in,
    output signed [15:0] prod, // 16位积 (截断低16位)
    output       ready_out
);

// 1. 取绝对值
wire sign_a = a[15];
wire sign_b = b[15];
wire sign_res = sign_a ^ sign_b;

wire [15:0] abs_a = sign_a ? (~a + 1'b1) : a;
wire [15:0] abs_b = sign_b ? (~b + 1'b1) : b;

// 2. 移位加法乘法 (无符号)
reg [15:0] abs_prod;
integer i;
always @(*) begin
    abs_prod = 16'd0;
    for(i = 0; i < 16; i = i + 1) begin
        if(abs_b[i]) begin
            abs_prod = abs_prod + (abs_a << i);
        end
    end
end

// 3. 恢复符号
assign prod = sign_res ? (~abs_prod + 1'b1) : abs_prod;

// 握手信号模拟
assign ready_out = valid_in;

endmodule

// 16位补码除法器
// 移位减法实现 (恢复余数法)，避免使用 / 运算符
module i16_div(
    input signed [15:0] a,   // 16位有符号被除数
    input signed [15:0] b,   // 16位有符号除数
    input        valid_in,
    output signed [15:0] quot, // 16位商
    output       ready_out
);

// 1. 取绝对值
wire sign_a = a[15];
wire sign_b = b[15];
wire sign_res = sign_a ^ sign_b;

wire [15:0] abs_a = sign_a ? (~a + 1'b1) : a;
wire [15:0] abs_b = sign_b ? (~b + 1'b1) : b;

// 2. 移位减法除法 (无符号)
reg [15:0] abs_quot;
reg [31:0] temp_r; // 余数寄存器，使用32位防止溢出方便移位
integer i;

always @(*) begin
    if (abs_b == 0) begin
        abs_quot = 16'hFFFF; // 除零保护
    end else begin
        abs_quot = 16'd0;
        temp_r = 32'd0;
        
        for(i = 15; i >= 0; i = i - 1) begin
            temp_r = temp_r << 1;
            temp_r[0] = abs_a[i]; // 移入被除数的一位
            
            if(temp_r >= {16'd0, abs_b}) begin
                temp_r = temp_r - {16'd0, abs_b};
                abs_quot[i] = 1'b1;
            end
        end
    end
end

// 3. 恢复符号
assign quot = sign_res ? (~abs_quot + 1'b1) : abs_quot;

// 握手信号模拟
assign ready_out = valid_in;

endmodule