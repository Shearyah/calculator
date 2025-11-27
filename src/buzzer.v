module buzzer_driver(
    input clk,
    input [15:0] key_status, // New: 16位按键状态，用于判断持续时间
    output reg beep
);
    reg [31:0] period;
    reg [31:0] cnt;
    
    // 判断是否有按键正在按下
    wire key_is_pressed = |key_status;

    // 频率查找表 (根据按下的键来确定发声频率)
    always @(*) begin
        // 这里需要找到 key_status 中哪一位是 1，才能确定 period
        casez(key_status)
            16'h8000: period = 95602; // Key 15
            16'h4000: period = 85178; // Key 14
            16'h2000: period = 75872; // Key 13
            16'h1000: period = 71633; // Key 12
            
            16'h0800: period = 63775; // Key 11
            16'h0400: period = 56818; // Key 10
            16'h0200: period = 50607; // Key 9
            16'h0100: period = 47801; // Key 8
            
            16'h0080: period = 42589; // Key 7
            16'h0040: period = 37937; // Key 6
            16'h0020: period = 35816; // Key 5
            16'h0010: period = 31887; // Key 4
            
            16'h0008: period = 28409; // Key 3
            16'h0004: period = 25303; // Key 2
            16'h0002: period = 23900; // Key 1
            16'h0001: period = 21294; // Key 0
            default: period = 0;
        endcase
    end

    // 震荡逻辑：只要按键按下，就一直发声
    always @(posedge clk) begin
        if(key_is_pressed && period != 0) begin
            if(cnt < period) begin
                cnt <= cnt + 1;
            end else begin
                cnt <= 0;
                beep <= ~beep; // 翻转发声
            end
        end else begin
            beep <= 0;
            cnt <= 0;
        end
    end
endmodule