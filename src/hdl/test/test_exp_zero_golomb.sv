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


module test_exp_zero_golomb;
	parameter DATA_WIDTH=19;
	parameter LENGTH_LOG=6;

	parameter PERIOD=10;


	
	reg clk, rst;


	//generators
	reg gen_input_enable;
	wire input_valid, input_ready;
	wire [DATA_WIDTH - 1:0] input_data;

	//checkers
	reg code_checker_enable;
	wire code_valid, code_ready;
	wire [DATA_WIDTH*2:0] code_data;

	reg length_checker_enable;
	wire length_valid, length_ready;
	wire [LENGTH_LOG - 1:0] length_data;

	
	always #(PERIOD/2) clk = ~clk;
	
	initial begin
		gen_input_enable = 0;
		code_checker_enable = 0;
		length_checker_enable = 0;

		clk = 0;
		rst = 1;
		#(PERIOD*2)
		rst = 0;

		gen_input_enable = 1;
		code_checker_enable = 1;
		length_checker_enable = 1;
	end
	
	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_EZG_INPUT)) GEN_input
		(
			.clk(clk), .rst(rst), .enable(gen_input_enable),
			.output_valid(input_valid),
			.output_data(input_data),
			.output_ready(input_ready)
		);

	helper_axis_checker #(.DATA_WIDTH(DATA_WIDTH*2+1), .FILE_NAME(`GOLDEN_EZG_CODE)) GEN_checker_code
		(
			.clk        (clk), .rst        (rst), .enable     (code_checker_enable),
			.input_valid(code_valid),
			.input_ready(code_ready),
			.input_data (code_data)
		);

	helper_axis_checker #(.DATA_WIDTH(LENGTH_LOG), .FILE_NAME(`GOLDEN_EZG_LENGTH)) GEN_checker_length
		(
			.clk        (clk), .rst        (rst), .enable     (length_checker_enable),
			.input_valid(length_valid),
			.input_ready(length_ready),
			.input_data (length_data)
		);

	wire output_valid, output_ready;
	EXP_ZERO_GOLOMB #(.DATA_WIDTH(DATA_WIDTH)) coder
		(
			.input_data(input_data),
			.input_valid(input_valid),
			.input_ready(input_ready),
			.output_code(code_data),
			.output_length(length_data),
			.output_valid(output_valid),
			.output_ready(output_ready)
		);

	assign length_valid = output_valid;
	assign code_valid   = output_valid;
	assign output_ready = length_ready;
	//assign output_ready = code_ready;


endmodule
