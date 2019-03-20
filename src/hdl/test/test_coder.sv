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
	parameter ACCUMULATOR_WINDOW = 32;
	parameter OUTPUT_WIDTH_LOG = 5;
	parameter ALPHA_WIDTH = 10;
	parameter DATA_WIDTH = 16;

	parameter KJ_WIDTH = 5;
	parameter PERIOD=10;
	
	reg clk, rst;


	//generators
	reg gen_ehat_enable;
	wire ehat_valid, ehat_ready;
	wire [MAPPED_ERROR_WIDTH - 1:0] ehat_data;
	wire ehat_last_s, ehat_last_b, ehat_last_i;

	reg gen_kj_enable;
	wire kj_valid, kj_ready;
	wire [KJ_WIDTH - 1:0] kj_data;

	reg gen_dflag_enable;
	wire dflag_valid, dflag_ready;
	wire [0:0] dflag_data;

	reg gen_alpha_enable;
	wire alpha_valid, alpha_ready;
	wire [ALPHA_WIDTH-1:0] alpha_data;

	reg gen_xmean_enable;
	wire xmean_valid, xmean_ready;
	wire [DATA_WIDTH-1:0] xmean_data;

	//checkers
	reg output_checker_enable;
	wire output_valid, output_ready;
	wire [2**OUTPUT_WIDTH_LOG-1:0] output_data;
	
	always #(PERIOD/2) clk = ~clk;
	
	initial begin
		gen_ehat_enable = 0;
		gen_kj_enable = 0;
		gen_dflag_enable = 0;
		gen_alpha_enable = 0;
		gen_xmean_enable = 0;
		output_checker_enable = 0;

		clk = 0;
		rst = 1;
		#(PERIOD*2)
		rst = 0;

		gen_ehat_enable = 1;
		gen_kj_enable = 1;
		gen_dflag_enable = 1;
		gen_alpha_enable = 1;
		gen_xmean_enable = 1;
		output_checker_enable = 1;
	end
	
	helper_axis_reader #(.DATA_WIDTH(MAPPED_ERROR_WIDTH), .FILE_NAME(`GOLDEN_MERR)) GEN_ehat
		(
			.clk(clk), .rst(rst), .enable(gen_ehat_enable),
			.output_valid(ehat_valid),
			.output_data(ehat_data),
			.output_ready(ehat_ready)
		);
	helper_axis_reader #(.DATA_WIDTH(MAPPED_ERROR_WIDTH), .FILE_NAME(`GOLDEN_X_LAST_S)) GEN_ehat_last_s
		(
			.clk(clk), .rst(rst), .enable(gen_ehat_enable),
			.output_valid(),
			.output_data(ehat_last_s),
			.output_ready(ehat_ready)
		);
	helper_axis_reader #(.DATA_WIDTH(MAPPED_ERROR_WIDTH), .FILE_NAME(`GOLDEN_X_LAST_B)) GEN_ehat_last_b
		(
			.clk(clk), .rst(rst), .enable(gen_ehat_enable),
			.output_valid(),
			.output_data(ehat_last_b),
			.output_ready(ehat_ready)
		);
	helper_axis_reader #(.DATA_WIDTH(MAPPED_ERROR_WIDTH), .FILE_NAME(`GOLDEN_X_LAST_I)) GEN_ehat_last_i
		(
			.clk(clk), .rst(rst), .enable(gen_ehat_enable),
			.output_valid(),
			.output_data(ehat_last_i),
			.output_ready(ehat_ready)
		);
				
								

	helper_axis_reader #(.DATA_WIDTH(KJ_WIDTH), .FILE_NAME(`GOLDEN_KJ)) GEN_kj
		(
			.clk(clk), .rst(rst), .enable(gen_kj_enable),
			.output_valid(kj_valid),
			.output_data(kj_data),
			.output_ready(kj_ready)
		);

	helper_axis_reader #(.DATA_WIDTH(1), .FILE_NAME(`GOLDEN_DFLAG)) GEN_dflag
		(
			.clk(clk), .rst(rst), .enable(gen_dflag_enable),
			.output_valid(dflag_valid),
			.output_data(dflag_data),
			.output_ready(dflag_ready)
		);

	helper_axis_reader #(.DATA_WIDTH(ALPHA_WIDTH), .FILE_NAME(`GOLDEN_ALPHA)) GEN_alpha
		(
			.clk(clk), .rst(rst), .enable(gen_alpha_enable),
			.output_valid(alpha_valid),
			.output_data(alpha_data),
			.output_ready(alpha_ready)
		);

	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_XMEAN)) GEN_xmean
		(
			.clk(clk), .rst(rst), .enable(gen_xmean_enable),
			.output_valid(xmean_valid),
			.output_data(xmean_data),
			.output_ready(xmean_ready)
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
		.ACCUMULATOR_WINDOW(ACCUMULATOR_WINDOW),
		.OUTPUT_WIDTH_LOG(OUTPUT_WIDTH_LOG),
		.ALPHA_WIDTH(ALPHA_WIDTH),
		.DATA_WIDTH(DATA_WIDTH)
	) coder_instance (
		.clk(clk),
		.rst(rst),
		.ehat_data(ehat_data),
		.ehat_ready(ehat_ready),
		.ehat_valid(ehat_valid),
		.ehat_last_s(ehat_last_s),
		.ehat_last_b(ehat_last_b),
		.ehat_last_i(ehat_last_i),
		.kj_data(kj_data),
		.kj_ready(kj_ready),
		.kj_valid(kj_valid),
		.d_flag_data(dflag_data),
		.d_flag_ready(dflag_ready),
		.d_flag_valid(dflag_valid),
		.alpha_ready(alpha_ready),
		.alpha_valid(alpha_valid),
		.alpha_data(alpha_data),
		.xmean_ready(xmean_ready),
		.xmean_valid(xmean_valid),
		.xmean_data(xmean_data),
		.output_data(output_data),
		.output_valid(output_valid),
		.output_ready(output_ready)
	);

endmodule
