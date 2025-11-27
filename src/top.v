module top( 
    input clk,
    input rst_n,
    input [7:0] sw,     //8拨码开关
    input [3:0] col,    //矩阵键盘列捕捉
    output [3:0] row,   //矩阵键盘行扫描
    output [7:0] seg,
    output [3:0] an,
    output [7:0] led,
    output beep
);
//整体大状态
localparam S_INPUT_A = 3'd0, S_INPUT_B = 3'd1, S_CALC = 3'd2, S_RESULT = 3'd3; 
//特殊键定义
localparam KEY_PLUS = 4'd12, KEY_MINUS = 4'd13, KEY_MUL = 4'd14, KEY_DIV = 4'd10, KEY_EQ = 4'd15, KEY_CLEAR = 4'd11;

wire clk_ms;   //毫秒时钟
wire btnclk;   //按键消抖20ms时钟
wire [15:0] btn_raw;   //16位按键独热码
wire [3:0] key_val;    //二进制编码
wire key_pressed;      //稳定按下标记
reg [11:0] bcd_accumulated; // BCD累加值 
reg bcd_input_active;      // BCD激活状

reg [7:0] reg_a, reg_b;//8位操作数ab
reg [1:0] op_code;     //2位运算操作码
reg [15:0] disp_data;  //16位显示数据
reg [2:0] state;       //计算模块当前状态
wire [15:0] alu_result;   //16位计算结果
wire alu_done;             //计算完成标志
reg alu_start;            //ALU启动控制


//主状态控制
reg [7:0] current_op_value; //当前操作数的值sw or BCD
//bcd
wire [11:0] new_bcd_shift;
wire [7:0] bin_from_bcd;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        bcd_accumulated <= 12'd0;
        bcd_input_active <= 1'b0;
        reg_a <= 8'd0;
        reg_b <= 8'd0;
        op_code <= 2'd0;
        state <= S_INPUT_A;
        disp_data <= 16'd0;
        current_op_value <= 8'd0;
        alu_start <= 1'b0; 
    end else begin
        alu_start <= 1'b0; //默认拉低ALU start，只在 S_INPUT_B -> S_CALC 转换时拉高一个周期
        if(sw != 8'd0) begin
            //拨码开关输入有效时，直接赋值给当前操作数
            current_op_value <= sw;
            bcd_accumulated <= 12'd0;
            bcd_input_active <= 1'b0;
        end else begin
            //按键输入处理sw==0时有效
            if(key_pressed) begin
                if(key_val <= 4'd9) begin //0-9
                    bcd_accumulated <= new_bcd_shift;
                    bcd_input_active <= 1'b1;
                end else if(key_val == KEY_CLEAR) begin //C
                    bcd_accumulated <= 12'd0;
                    bcd_input_active <= 1'b0;
                    // 如果在输入B状态按C,返回输入A状态
                    if(state == S_INPUT_B) state <= S_INPUT_A; 
                end
            end
            //当前操作数取值:如果按键输入有效，则取BCD转换结果否则取0
            current_op_value <= (bcd_input_active) ? bin_from_bcd : 8'd0;
        end
        
        //状态转移
        case(state)
            S_INPUT_A: begin
                //显示当前A的值
                disp_data <= {{8{current_op_value[7]}}, current_op_value};
                
                if(key_pressed) begin
                    case(key_val)
                        //检测到运算符，锁存A，设置操作码，进入输入B状态，清空BCD累加器
                        KEY_PLUS: begin reg_a <= current_op_value; op_code <= 2'd0; bcd_accumulated<=0; bcd_input_active<=0; state <= S_INPUT_B; end
                        KEY_MINUS: begin reg_a <= current_op_value; op_code <= 2'd1; bcd_accumulated<=0; bcd_input_active<=0; state <= S_INPUT_B; end
                        KEY_MUL: begin reg_a <= current_op_value; op_code <= 2'd2; bcd_accumulated<=0; bcd_input_active<=0; state <= S_INPUT_B; end
                        KEY_DIV: begin reg_a <= current_op_value; op_code <= 2'd3; bcd_accumulated<=0; bcd_input_active<=0; state <= S_INPUT_B; end
                    endcase
                end
            end
            
            S_INPUT_B: begin
                //显示当前B的值
                disp_data <= {{8{current_op_value[7]}}, current_op_value};
                
                if(key_pressed) begin
                    if(key_val == KEY_EQ) begin //按下等号
                        reg_b <= current_op_value; //锁存B
                        state <= S_CALC;           //进入计算状态
                        alu_start <= 1'b1;         //启动ALU计算
                        bcd_accumulated<=0;        //清空BCD累加器
                        bcd_input_active<=0;
                    end
                end
            end
            
            S_CALC: begin
                disp_data <= 16'h0C0C; //显示计算中标记
                
                if (alu_done) begin
                    disp_data <= alu_result; //使用 ALU 的 16 位结果进行显示
                    state <= S_RESULT;       //进入结果显示状态
                end
            end
            S_RESULT: begin
                //保持显示结果（由 S_CALC 状态赋值保持）
                
                if(key_pressed) begin
                    if(key_val == KEY_CLEAR) begin //C键清零 重新开始输入A
                        state <= S_INPUT_A;
                        bcd_accumulated <= 12'd0;
                        bcd_input_active <= 1'b0;
                    end
                    else if (key_val <= 4'd9) begin //0-9键：视为开始新输入
                        state <= S_INPUT_A;
                        bcd_accumulated <= new_bcd_shift;
                        bcd_input_active <= 1'b1;
                    end
                    else if (key_val >= KEY_PLUS && key_val <= KEY_DIV) begin
                        //运算符键：使用当前结果的低8位作为新的操作数A进入输入 B 状态
                        reg_a <= alu_result[7:0]; 
                        op_code <= (key_val == KEY_PLUS) ? 0 : 
                                    (key_val == KEY_MINUS) ? 1 :
                                    (key_val == KEY_MUL) ? 2 : 3;
                        state <= S_INPUT_B;
                        bcd_accumulated <= 12'd0; 
                        bcd_input_active <= 1'b0;
                    end
                end
            end
            
            default: state <= S_INPUT_A;
        endcase
    end
end


//分频&消抖
divclk u_div(.clk(clk),.clk_ms(clk_ms),.btnclk(btnclk));
//键盘驱动
v_ajxd u_key_driver(.clk(btnclk),.btn_clk(btnclk),.col(col),.row(row),.btn_out(btn_raw));
//键盘解码
key_decoder u_decoder(.clk(clk),.btn_in(btn_raw),.key_val(key_val),.key_pressed(key_pressed));
//蜂鸣器
buzzer_driver u_beep(.clk(clk),.key_status(btn_raw),.beep(beep));
//数码管显示
display_driver u_disp(.clk(clk),.data_in(disp_data),.seg(seg),.an(an));
//LED
led_driver u_leds(.clk(clk),.rst_n(rst_n),.current_state(state),.data_saved(reg_a),.led(led));
//ALU
math_alu u_math(.clk(clk),.rst_n(rst_n),.start(alu_start),.opcode(op_code),.data_a(reg_a),.data_b(reg_b),.result(alu_result),.done(alu_done));
//BCD
bcd_handler u_bcd_handler (.bcd_in(bcd_accumulated), .digit(key_val), .shift_out(new_bcd_shift), .bin_out(bin_from_bcd));
endmodule

