/**
 * 4位7段数码管显示驱动模块
 * 输入：16位带符号整数
 * 输出：8段选信号，4位选信号
 * 显示格式：十进制，负号显示在最高位
 * 显示范围：-999到+9999，超出范围显示为----?
 */
module digit_tube(
    input clk,
    input [15:0] data_in, // 显示数据
    output reg [7:0] seg,//段选
    output reg [3:0] an  //位选
);
    //符号处理
    wire is_neg = data_in[15]; //< 是否是负数
    wire [15:0] abs_data = is_neg ? (~data_in + 1) : data_in; //< 输入数据的绝对值
    reg [1:0] scan_cnt; //< 扫描计数器
    reg [3:0] d0, d1, d2, d3; //< 四个数字的bcd
    reg [3:0] disp_digit; //< 当前状态值

    // 扫描计数器和片选信号
    always @(posedge clk) scan_cnt <= scan_cnt + 1;

    // 移位加三法，对每一个输出数字进行bcd编码
    reg [3:0] i;
    always @(abs_data) begin
        {d3, d2, d1, d0} = 0;
        i = 4'd15;
        repeat (16) begin
            if (d0 >= 5) d0 = d0 + 3;
            if (d1 >= 5) d1 = d1 + 3;
            if (d2 >= 5) d2 = d2 + 3;
            if (d3 >= 5) d3 = d3 + 3;
            {d3, d2, d1, d0} = {d3, d2, d1, d0} << 1;
            d0[0] = abs_data[i];
            i = i - 1;
        end
    end

    // 位选扫描逻辑 (低电平选中位)
    always @(*) begin
        case(scan_cnt)
            2'b00: begin an = 4'b1110; disp_digit = d0; end
            2'b01: begin an = 4'b1101; disp_digit = d1; end
            2'b10: begin an = 4'b1011; disp_digit = d2; end
            2'b11: begin
                an = 4'b0111; 
                if(is_neg) disp_digit = 4'hE;//负号
                else disp_digit = d3; 
            end
        endcase
        // 范围检测，超出范围显示----
        //if ((is_neg && (abs_data > 16'd999)) || (!is_neg && (abs_data > 16'd9999))) begin
        //    an = 4'b0000; //全部灭
        //    disp_digit = 4'h10; //特殊码，显示----
        //end
    end

    //bcd解码，AH
    always @(*) begin
        case(disp_digit)
            4'h0: seg = 8'h3f; //0
            4'h1: seg = 8'h06; //1
            4'h2: seg = 8'h5b; //2
            4'h3: seg = 8'h4f; //3
            4'h4: seg = 8'h66; //4
            4'h5: seg = 8'h6d; //5
            4'h6: seg = 8'h7d; //6
            4'h7: seg = 8'h07; //7
            4'h8: seg = 8'h7f; //8
            4'h9: seg = 8'h6f; //9
            4'hA: seg = 8'h77; //A
            4'hB: seg = 8'h7c; //b
            4'hC: seg = 8'h39; //C
            4'hD: seg = 8'h5e; //D
            4'hE: seg = 8'h40; //-
            4'hF: seg = 8'h71; //F
            default: seg = 8'h00; //off
        endcase
    end
endmodule