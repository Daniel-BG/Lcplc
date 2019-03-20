`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCM
// Engineer: Daniel Báscones
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


module test_golomb_coding;
	parameter DATA_WIDTH = 19;
	parameter MAX_PARAM_VALUE = 19;
	parameter MAX_PARAM_VALUE_LOG = 5;
	parameter OUTPUT_WIDTH = 39;
	parameter OUTPUT_WIDTH_LOG = 6;
	parameter SLACK_LOG = 4;
	parameter MAX_1_OUT_LOG = 5;

	parameter PERIOD=10;


	
	reg clk, rst;


	//generators
	reg gen_input_enable;
	wire input_valid, input_ready;
	wire [DATA_WIDTH - 1:0] input_data;

	reg gen_param_enable;
	wire param_valid, param_ready;
	wire [MAX_PARAM_VALUE_LOG - 1:0] param_data;

	//checkers
	reg code_checker_enable;
	wire code_valid, code_ready;
	wire [OUTPUT_WIDTH-1:0] code_data;

	reg length_checker_enable;
	wire length_valid, length_ready;
	wire [OUTPUT_WIDTH_LOG - 1:0] length_data;

	
	always #(PERIOD/2) clk = ~clk;
	
	initial begin
		gen_input_enable = 0;
		gen_param_enable = 0;
		code_checker_enable = 0;
		length_checker_enable = 0;

		clk = 0;
		rst = 1;
		#(PERIOD*2)
		rst = 0;

		gen_input_enable = 1;
		gen_param_enable = 1;
		code_checker_enable = 1;
		length_checker_enable = 1;
	end
	
	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_GC_INPUT)) GEN_input
		(
			.clk(clk), .rst(rst), .enable(gen_input_enable),
			.output_valid(input_valid),
			.output_data(input_data),
			.output_ready(input_ready)
		);

	helper_axis_reader #(.DATA_WIDTH(MAX_PARAM_VALUE_LOG), .FILE_NAME(`GOLDEN_GC_PARAM)) GEN_param
		(
			.clk(clk), .rst(rst), .enable(gen_param_enable),
			.output_valid(param_valid),
			.output_data(param_data),
			.output_ready(param_ready)
		);

	helper_axis_checker #(.DATA_WIDTH(OUTPUT_WIDTH), .FILE_NAME(`GOLDEN_GC_CODE)) GEN_checker_code
		(
			.clk        (clk), .rst        (rst), .enable     (code_checker_enable),
			.input_valid(code_valid),
			.input_ready(code_ready),
			.input_data (code_data)
		);

	helper_axis_checker #(.DATA_WIDTH(OUTPUT_WIDTH_LOG), .FILE_NAME(`GOLDEN_GC_LENGTH)) GEN_checker_length
		(
			.clk        (clk), .rst        (rst), .enable     (length_checker_enable),
			.input_valid(length_valid),
			.input_ready(length_ready),
			.input_data (length_data)
		);

	wire output_valid, output_ready;

	GOLOMB_CODING #(
			.DATA_WIDTH(DATA_WIDTH),
			.MAX_PARAM_VALUE(MAX_PARAM_VALUE),
			.MAX_PARAM_VALUE_LOG(MAX_PARAM_VALUE_LOG),
			.OUTPUT_WIDTH(OUTPUT_WIDTH),
			.SLACK_LOG(SLACK_LOG),
			.MAX_1_OUT_LOG(MAX_1_OUT_LOG)
		) coder
		(
			.clk(clk),
			.rst(rst),
			.input_param_data(param_data),
			.input_param_valid(param_valid),
			.input_param_ready(param_ready),
			.input_param_last(0),
			.input_value_data(input_data),
			.input_value_valid(input_valid),
			.input_value_ready(input_ready),
			.input_value_last(0),
			.output_code(code_data),
			.output_length(length_data),
			.output_last(),
			.output_valid(output_valid),
			.output_ready(output_ready)
		);

	assign length_valid = output_valid;
	assign code_valid   = output_valid;
	assign output_ready = length_ready;
	//assign output_ready = code_ready;


endmodule
