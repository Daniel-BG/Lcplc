`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.02.2019 18:12:05
// Design Name: 
// Module Name: testmul
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module testmul;
	
	parameter PERIOD = 10;
	
	reg clk, rst;
	
	reg [16:0] op_a, op_b;
	wire [33:0] res;
	
	reg enable;
	reg clear;
	
	mult_gen_prealpha UUT(
		.CLK(clk),
		.A(op_a),
		.B(op_b),
		.CE(enable),
		.SCLR(clear),
		.P(res)
	);


initial begin
	clk <= 1'b0;
	rst <= 1'b0;
end

always begin
	#(PERIOD/2) clk <= ~clk;
end

initial begin
	op_a <= 0;
	op_b <= 0;
	enable <= 1'b0;
	clear <= 1'b0;
	
	#(PERIOD*2);
	
	enable <= 1'b1;
	
	#(PERIOD);
	
	op_a   <= 12;
	op_b   <= 13;
	
	#(PERIOD);
	
	op_a   <= 17;
	op_b   <= 123;
	
	#(PERIOD);
	
	op_a   <= 45;
	op_b   <= 12;
	
	#(PERIOD);

	op_a   <= 5;
	op_b   <= 3;
	
	#(PERIOD);
	
	op_a   <= 3;
	op_b   <= 2;
	
	#(PERIOD);
	

end

endmodule
