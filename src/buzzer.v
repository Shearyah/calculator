// 蜂鸣器驱动
// 使用PWM驱动
module buzzer(
    input clk, // 时钟, 约为 20ns, 可用来调整全局音调
    input [3:0] idx, // 周期序号
    input en, // 使能, 高有效
    output beep
);
    reg [31:0] period; // PWM周期
    reg [31:0] duty; // PWM占空比

    pwm_32u pwm(
        .clk(clk),
        .rst_n(1'b1),
        .duty(duty),
        .period(period),
        .pwm(beep)
    );

    always @(*) begin
        if (!en) begin
            period = 32'd0; // 不工作时输出高电平
            duty = 32'd0;
        end else begin
            case (idx)
                4'd0: period = 32'd95602;
                4'd1: period = 32'd85178; 
                4'd2: period = 32'd75872; 
                4'd3: period = 32'd71633; 

                4'd4: period = 32'd63775; 
                4'd5: period = 32'd56818; 
                4'd6: period = 32'd50607; 
                4'd7: period = 32'd47801; 

                4'd8: period = 32'd42589;  
                4'd9: period = 32'd37931;  
                4'd10: period = 32'd35816; 
                4'd11: period = 32'd31887;

                4'd12: period = 32'd28409; 
                4'd13: period = 32'd25303; 
                4'd14: period = 32'd23900; 
                4'd15: period = 32'd21294; 
                default: ; // 不可能发生 
            endcase
            duty = period >> 1; // 占空比50%
        end
    end
endmodule