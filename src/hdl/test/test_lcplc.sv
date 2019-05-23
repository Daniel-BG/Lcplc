`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCM
// Engineer: Daniel BÃ¡scones
// 
// Create Date: 25.02.2019 12:53:59
// Design Name: 
// Module Name: test_exp_zero_golomb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Test the nth band prediction module
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "test_shared.svh"


module test_lcplc;
	parameter DATA_WIDTH = 16;
	parameter WORD_WIDTH_LOG = 5;
	parameter MAX_SLICE_SIZE_LOG = 8;
	parameter ALPHA_WIDTH = 10;
	parameter ACCUMULATOR_WINDOW = 32;
	parameter QUANTIZER_SHIFT_WIDTH = 4;
	
	//parameter QUANTIZER_SHIFT = 0;
	//wire[63:0] THRESHOLD = 16'h0000_0000_0000_0000;
	//parameter QUANTIZER_SHIFT = 2;
	//wire[63:0] THRESHOLD = 16'h0000_0000_0005_5555;
	parameter QUANTIZER_SHIFT = 2;
	wire[63:0] THRESHOLD = 64'h0000_0000_0010_0000;
	
	parameter PERIOD = 10;
	reg clk, rst;


	//generators
	reg gen_x_enable;
	wire x_valid, x_ready;
	wire [DATA_WIDTH - 1:0] x_data;
	wire x_last_r, x_last_s, x_last_b, x_last_i;

	//checkers
	reg output_checker_enable;
	wire output_valid, output_ready;
	wire [2**WORD_WIDTH_LOG-1:0] output_data;
	wire output_last;
	
	always #(PERIOD/2) clk = ~clk;
	
	initial begin
		gen_x_enable = 0;
		output_checker_enable = 0;
		clk = 0;
		rst = 1;
		#(PERIOD*2)
		rst = 0;
		gen_x_enable = 1;
		output_checker_enable = 1;
		#(PERIOD*10000)
		gen_x_enable = 0;
		output_checker_enable = 0;
		#(PERIOD)
		rst = 1;
		#(PERIOD*2)
		rst = 0;
		gen_x_enable = 1;
		output_checker_enable = 1;
	end
	
	
//	initial begin
//		gen_x_enable = 0;
		
//		#(PERIOD*2)
//		while (1) begin
//			#(PERIOD*3)
//			gen_x_enable = 1;
//			#(PERIOD)
//			gen_x_enable = 0;
//		end
//	end
	
//	initial begin
//		output_checker_enable = 0;
		
//		#(PERIOD*2)
//		while (1) begin
//			#(PERIOD*7)
//			output_checker_enable = 1;
//			#(PERIOD)
//			output_checker_enable = 0;
//		end
//	end
	
	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_X)) GEN_x
		(
			.clk(clk), .rst(rst), .enable(gen_x_enable),
			.output_valid(x_valid),
			.output_data(x_data),
			.output_ready(x_ready)
		);
	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_X_LAST_R)) GEN_x_last_r
		(
			.clk(clk), .rst(rst), .enable(gen_x_enable),
			.output_valid(),
			.output_data(x_last_r),
			.output_ready(x_ready)
		);
	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_X_LAST_S)) GEN_x_last_s
		(
			.clk(clk), .rst(rst), .enable(gen_x_enable),
			.output_valid(),
			.output_data(x_last_s),
			.output_ready(x_ready)
		);
	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_X_LAST_B)) GEN_x_last_b
		(
			.clk(clk), .rst(rst), .enable(gen_x_enable),
			.output_valid(),
			.output_data(x_last_b),
			.output_ready(x_ready)
		);
	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_X_LAST_I)) GEN_x_last_i
		(
			.clk(clk), .rst(rst), .enable(gen_x_enable),
			.output_valid(),
			.output_data(x_last_i),
			.output_ready(x_ready)
		);



	helper_axis_checker #(.DATA_WIDTH(2**WORD_WIDTH_LOG), .FILE_NAME(`GOLDEN_OUTPUT)) GEN_checker_output
		(
			.clk        (clk), .rst        (rst), .enable     (output_checker_enable),
			.input_valid(output_valid),
			.input_ready(output_ready),
			.input_data (output_data)
		);

	LCPLC #(
		.DATA_WIDTH(DATA_WIDTH),
		.WORD_WIDTH_LOG(WORD_WIDTH_LOG),
		.MAX_SLICE_SIZE_LOG(MAX_SLICE_SIZE_LOG),
		.ALPHA_WIDTH(ALPHA_WIDTH),
		.ACCUMULATOR_WINDOW(ACCUMULATOR_WINDOW),
		.QUANTIZER_SHIFT_WIDTH(QUANTIZER_SHIFT_WIDTH)
	) coder_instance (
		.clk(clk),
		.rst(rst),
		.x_valid(x_valid),
		.x_ready(x_ready),
		.x_data(x_data),
		.x_last_r(x_last_r),
		.x_last_s(x_last_s),
		.x_last_b(x_last_b),
		.x_last_i(x_last_i),
		.output_data(output_data),
		.output_ready(output_ready),
		.output_valid(output_valid),
		.output_last(output_last),
		.cfg_quant_shift(QUANTIZER_SHIFT),
		.cfg_threshold(THRESHOLD)
	);

endmodule
