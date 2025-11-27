module math_alu(
    input clk,
    input rst_n,
    input start,    //开始标志
    input [1:0] opcode,//00+、01-、10*、11/
    input [7:0] data_a,//操作数a, 8bit补码
    input [7:0] data_b,
    output reg [15:0] result, //16位结果
    output reg done //完成标志
);

    localparam IDLE = 2'd0, CALC = 2'd1, DONE = 2'd2;
    reg [1:0] state, next_state; 

    //扩展到16位
    wire [15:0] a_ext = {{8{data_a[7]}}, data_a};
    wire [15:0] b_ext = {{8{data_b[7]}}, data_b};
    
    //+-
    wire sub_en = (opcode == 2'b01);
    wire [15:0] add_sum_16bit; 
    wire add_cout;

    adder_16bit u_adder_subtractor (
        .a(a_ext),
        .b(b_ext),
        .sub_en(sub_en),
        .sum(add_sum_16bit),
        .cout(add_cout)
    );
    
    //*
    wire [15:0] mul_result;
    multiplier_8bit u_multiplier (
        .data_a(data_a), .data_b(data_b),
        .result(mul_result)
        );

    ///
    wire [15:0] div_result;
    divider_8bit u_divider (
        .data_a(data_a),
        .data_b(data_b),
        .result(div_result)
        );
    
    wire [15:0] calc_raw; // 原始输出

    assign calc_raw = 
        (opcode == 2'b00) ? add_sum_16bit : 
        (opcode == 2'b01) ? add_sum_16bit : 
        (opcode == 2'b10) ? mul_result :                  
        (opcode == 2'b11) ? div_result :                  
        16'd0; 

    //状态跳转
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = CALC;
            end
            CALC: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start) 
                    next_state = IDLE;
            end
        endcase
    end
    //输出
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 16'd0;
        end else begin
            done <= 1'b0; 
            
            case (state)
                CALC: begin
                    result <= calc_raw; 
                end
                
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule