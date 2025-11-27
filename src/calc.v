module full_adder(
    input a,
    input b,
    input cin,
    output sum,
    output cout
);
    assign sum = a ^ b ^ cin;
    assign cout = (a & b) | (b & cin) | (a & cin);
endmodule

module adder_16bit(
    input [15:0] a,
    input [15:0] b,
    input sub_en,
    output [15:0] sum,
    output cout //末位1进位or0借位
);
    wire [15:0] b_ops;
    wire [16:0] carry;
    
    //若减法使能，则b操作数按位取反再加一，加一放到进位上了
    assign b_ops = sub_en ? ~b : b;
    assign carry[0] = sub_en;
    //级联16个全加器
    genvar i;
    generate
        for(i=0; i<16; i=i+1) begin : adder_loop
            full_adder u_fa(.a(a[i]), .b(b_ops[i]), .cin(carry[i]), .sum(sum[i]), .cout(carry[i+1]));
        end
    endgenerate
    assign cout = carry[16];
endmodule

module multiplier_8bit(
    input [7:0] data_a,
    input [7:0] data_b,
    output [15:0] result 
);
    assign result = {8'd0, data_a} * {8'd0, data_b};
endmodule

module divider_8bit(
    input [7:0] data_a,
    input [7:0] data_b,
    output [15:0] result
);
    wire signed [15:0] a_ext = $signed(data_a); 
    wire signed [15:0] b_ext = $signed(data_b);
    
    wire signed [15:0] q_raw;

    assign q_raw = (b_ext == 16'd0) ? 16'hFFFE : (a_ext / b_ext); 

    assign result = q_raw;
endmodule