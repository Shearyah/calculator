module led_driver(
    input clk,
    input rst_n,
    input [2:0] current_state,  //获取主状态
    input [7:0] data_saved,    
    output reg [7:0] led       
);
    //状态常量
    localparam S_INPUT_A = 0;
    localparam S_INPUT_B = 1;
    localparam S_RESULT  = 2;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            led <= 8'h00;
        end else begin
            if(current_state == S_INPUT_B || current_state == S_RESULT) begin
                led <= data_saved;  //合适状态点灯，不合适状态熄灯
            end else begin
                led <= 8'h00;
            end
        end
    end
endmodule