//分频，输入50M，输出1ms时钟和20ms消抖计时时钟
module divclk(
    input clk,
    output reg clk_ms,//毫秒时钟
    output reg btnclk //消抖计时20ms
);

    reg [31:0] cnt1 = 0; 
    parameter CLK_MS_MAX = 26'd25000-1; 
    
    reg [31:0] btnclk_cnt = 0;
    parameter BTNCLK_MAX = 31'd1000000-1; 
// 分频
    always @(posedge clk) begin
        if(cnt1 == CLK_MS_MAX) begin
            clk_ms <= ~clk_ms;
            cnt1 <= 0;
        end else begin
            cnt1 <= cnt1 + 1'b1;
        end

        if(btnclk_cnt == BTNCLK_MAX) begin
            btnclk <= ~btnclk;
            btnclk_cnt <= 0;
        end else begin
            btnclk_cnt <= btnclk_cnt + 1'b1;
        end
    end
endmodule
//行扫描列接收+消抖，输出16位独热码
module v_ajxd(
    input clk,
    input btn_clk,
    input [3:0] col,    //被动列接收
    output [3:0] row,   //主动行扫描
    output [15:0] btn_out   //独热编码，AH
);
    reg [15:0] btn = 0;     // 原始按键捕获值
    reg [15:0] btn0 = 0;    // 去抖寄存器 1
    reg [15:0] btn1 = 0;    // 去抖寄存器 2
    
    reg [3:0] row_reg = 4'b1110; 
    
    //行扫描，循环拉低，原速扫描
    always @ (posedge clk) begin
        row_reg <= {row_reg[2:0], row_reg[3]}; 
    end
    
    assign row = row_reg; 

    //列接收捕获，原速接收
    always @ (negedge clk) begin 
        case (row_reg) 
            4'b1110: begin
                btn[3:0] <= col;
            end
            4'b1101: begin
                btn[7:4] <= col;
            end
            4'b1011: begin
                btn[11:8] <= col;
            end
            4'b0111: begin
                btn[15:12] <= col;
            end
            default: begin
                btn <= 0;
            end
        endcase
    end
    
    //消抖
    always @ (posedge btn_clk) begin
        btn0 <= btn;
        btn1 <= btn0;
    end
    assign btn_out = ~btn1 & ~btn0; 
endmodule
//
module key_decoder(
    input clk,
    input [15:0] btn_in,   //16位独热码
    output reg [3:0] key_val, //按键编码
    output reg key_pressed //单周期脉冲
);
    reg [15:0] btn_prev; //上一周期状态

    always @(posedge clk) begin
        key_pressed <= 0;
        btn_prev <= btn_in;
        //上升沿检测
        if ((btn_in != btn_prev) && (btn_in != 0)) begin
            case (btn_in)
                16'h8000: begin key_val <= 9; key_pressed <= 1; end //16'b1000_0000_0000_0000
                16'h4000: begin key_val <= 8; key_pressed <= 1; end
                16'h2000: begin key_val <= 7; key_pressed <= 1; end
                16'h0800: begin key_val <= 6; key_pressed <= 1; end
                16'h0400: begin key_val <= 5; key_pressed <= 1; end
                16'h0200: begin key_val <= 4; key_pressed <= 1; end
                16'h0080: begin key_val <= 3; key_pressed <= 1; end
                16'h0040: begin key_val <= 2; key_pressed <= 1; end
                16'h0020: begin key_val <= 1; key_pressed <= 1; end
                16'h0004: begin key_val <= 0; key_pressed <= 1; end

                16'h1000: begin key_val <= 12; key_pressed <= 1; end//+
                16'h0100: begin key_val <= 13; key_pressed <= 1; end//-
                16'h0010: begin key_val <= 14; key_pressed <= 1; end//*
                16'h0008: begin key_val <= 11; key_pressed <= 1; end//C
                16'h0002: begin key_val <= 15; key_pressed <= 1; end//=
                16'h0001: begin key_val <= 10; key_pressed <= 1; end///
                
                default: ;//细节default
                /*
                9、8、7 | +     C_3、D、E、F
                6、5、4 | -     G、A、B、C_4
                3、2、1 | ×     D、E、F、G
                c、0、= | ÷     A、B、C_5、D
                */
            endcase
        end
    end
endmodule