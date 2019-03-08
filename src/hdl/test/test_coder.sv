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


module test_coder;
	parameter MAPPED_ERROR_WIDTH = 19;
	parameter ACC_LOG = 5;
	parameter BLOCK_SIZE_LOG = 8;
	parameter OUTPUT_WIDTH_LOG = 5;

	parameter PERIOD=10;


	
	reg clk, rst;


	//generators
	reg gen_ehat_enable;
	wire ehat_valid, ehat_ready;
	wire [MAPPED_ERROR_WIDTH - 1:0] ehat_data;

	reg gen_kj_enable;
	wire kj_valid, kj_ready;
	wire [ACC_LOG - 1:0] kj_data;

	reg gen_dflag_enable;
	wire dflag_valid, dflag_ready;
	wire [0:0] dflag_data;

	//checkers
	reg output_checker_enable;
	wire output_valid, output_ready;
	wire [2**OUTPUT_WIDTH_LOG-1:0] output_data;
	
	always #(PERIOD/2) clk = ~clk;
	
	initial begin
		gen_ehat_enable = 0;
		gen_kj_enable = 0;
		gen_dflag_enable = 0;
		output_checker_enable = 0;

		clk = 0;
		rst = 1;
		#(PERIOD*2)
		rst = 0;

		gen_ehat_enable = 1;
		gen_kj_enable = 1;
		gen_dflag_enable = 1;
		output_checker_enable = 1;
	end
	
	helper_axis_reader #(.DATA_WIDTH(MAPPED_ERROR_WIDTH), .FILE_NAME(`GOLDEN_MERR)) GEN_ehat
		(
			.clk(clk), .rst(rst), .enable(gen_ehat_enable),
			.output_valid(ehat_valid),
			.output_data(ehat_data),
			.output_ready(ehat_ready)
		);

	helper_axis_reader #(.DATA_WIDTH(ACC_LOG), .FILE_NAME(`GOLDEN_KJ)) GEN_kj
		(
			.clk(clk), .rst(rst), .enable(gen_kj_enable),
			.output_valid(kj_valid),
			.output_data(kj_data),
			.output_ready(kj_ready)
		);

	wire kj_red_ready, kj_red_valid;
	wire [ACC_LOG-1:0] kj_red_data;
	AXIS_REDUCER #(
		.DATA_WIDTH(ACC_LOG),
		.VALID_TRANSACTIONS(255),
		.INVALID_TRANSACTIONS(1),
		.START_VALID(1)
	) kj_reducer (
		.clk(clk),
		.rst(rst),
		.input_ready(kj_ready),
		.input_valid(kj_valid),
		.input_data(kj_data),
		.output_ready(kj_red_ready),
		.output_valid(kj_red_valid),
		.output_data(kj_red_data)
	);

	helper_axis_reader #(.DATA_WIDTH(ACC_LOG), .FILE_NAME(`GOLDEN_DFLAG)) GEN_dflag
		(
			.clk(clk), .rst(rst), .enable(gen_dflag_enable),
			.output_valid(dflag_valid),
			.output_data(dflag_data),
			.output_ready(dflag_ready)
		);

	helper_axis_checker #(.DATA_WIDTH(2**OUTPUT_WIDTH_LOG), .FILE_NAME(`GOLDEN_OUTPUT)) GEN_checker_output
		(
			.clk        (clk), .rst        (rst), .enable     (output_checker_enable),
			.input_valid(output_valid),
			.input_ready(output_ready),
			.input_data (output_data)
		);

	CODER #(
		.MAPPED_ERROR_WIDTH(MAPPED_ERROR_WIDTH),
		.ACC_LOG(ACC_LOG),
		.BLOCK_SIZE_LOG(BLOCK_SIZE_LOG),
		.OUTPUT_WIDTH_LOG(OUTPUT_WIDTH_LOG)
	) coder_instance (
		.clk(clk),
		.rst(rst),
		.flush(0),
		.flushed(),
		.ehat_data(ehat_data),
		.ehat_ready(ehat_ready),
		.ehat_valid(ehat_valid),
		.kj_data(kj_red_data),
		.kj_ready(kj_red_ready),
		.kj_valid(kj_red_valid),
		.d_flag_data(dflag_data),
		.d_flag_ready(dflag_ready),
		.d_flag_valid(dflag_valid),
		.output_data(output_data),
		.output_valid(output_valid),
		.output_ready(output_ready)
	);

endmodule
