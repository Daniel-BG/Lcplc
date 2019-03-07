`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCM
// Engineer: Daniel Báscones
// 
// Create Date: 25.02.2019 12:53:59
// Design Name: 
// Module Name: test_xhat_precalc
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Test the xhat precalc module
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "test_shared.svh"


module test_xhat_precalc;

	parameter DATA_WIDTH=16;
	parameter BLOCK_SIZE_LOG=8;

	parameter PERIOD=10;


	
	reg clk, rst;


	//generators
	reg gen_xhatraw_enable;
	wire xhatraw_valid, xhatraw_ready;
	wire [DATA_WIDTH - 1:0] xhatraw_data;

	reg gen_xtilde_enable;
	wire xtilde_valid, xtilde_ready;
	wire [DATA_WIDTH - 1:0] xtilde_data;

	reg gen_dflag_enable;
	wire dflag_valid, dflag_ready;
	wire [0:0] dflag_data;

	//checkers
	reg xhat_checker_enable;
	wire xhat_valid, xhat_ready;
	wire [DATA_WIDTH - 1:0] xhat_data;

	reg xhatmean_checker_enable;
	wire xhatmean_valid, xhatmean_ready;
	wire [DATA_WIDTH - 1:0] xhatmean_data;


	always #(PERIOD/2) clk = ~clk;
	
	initial begin
		gen_xhatraw_enable = 0;
		gen_xtilde_enable = 0;
		gen_dflag_enable = 0;

		xhat_checker_enable = 0;
		xhatmean_checker_enable = 0;

		clk = 0;
		rst = 1;
		#(PERIOD*2)
		rst = 0;

		gen_xhatraw_enable = 1;
		gen_xtilde_enable = 1;
		gen_dflag_enable = 1;

		xhat_checker_enable = 1;
		xhatmean_checker_enable = 1;
	end
	
	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_XHATRAW)) GEN_xhatraw
		(
			.clk(clk), .rst(rst), .enable(gen_xhatraw_enable),
			.output_valid(xhatraw_valid),
			.output_data(xhatraw_data),
			.output_ready(xhatraw_ready)
		);

	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_XTILDE)) GEN_xtilde
		(
			.clk(clk), .rst(rst), .enable(gen_xtilde_enable),
			.output_valid(xtilde_valid),
			.output_data(xtilde_data),
			.output_ready(xtilde_ready)
		);

	helper_axis_reader #(.DATA_WIDTH(1), .FILE_NAME(`GOLDEN_DFLAG)) GEN_dflag
		(
			.clk(clk), .rst(rst), .enable(gen_dflag_enable),
			.output_valid(dflag_valid),
			.output_data(dflag_data),
			.output_ready(dflag_ready)
		);


	helper_axis_checker #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_XHAT)) GEN_checker_xhat
		(
			.clk        (clk), .rst        (rst), .enable     (xhat_checker_enable),
			.input_valid(xhat_valid),
			.input_ready(xhat_ready),
			.input_data (xhat_data)
		);

	helper_axis_checker #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_XHATMEAN)) GEN_checker_xhatmean
		(
			.clk        (clk), .rst        (rst), .enable     (xhatmean_checker_enable),
			.input_valid(xhatmean_valid),
			.input_ready(xhatmean_ready),
			.input_data (xhatmean_data)
		);


	NEXT_XHAT_PRECALC #(.DATA_WIDTH(DATA_WIDTH), .BLOCK_SIZE_LOG(BLOCK_SIZE_LOG)) xhat_precalc
		(
			.rst(rst),
			.clk(clk),
			.xhat_data(xhatraw_data),
			.xhat_ready(xhatraw_ready),
			.xhat_valid(xhatraw_valid),
			.xtilde_data(xtilde_data),
			.xtilde_ready(xtilde_ready),
			.xtilde_valid(xtilde_valid),
			.d_flag_data(dflag_data),
			.d_flag_ready(dflag_ready),
			.d_flag_valid(dflag_valid),
			.xhatout_data(xhat_data),
			.xhatout_ready(xhat_ready),
			.xhatout_valid(xhat_valid),
			.xhatoutmean_data(xhatmean_data),
			.xhatoutmean_ready(xhatmean_ready),
			.xhatoutmean_valid(xhatmean_valid)
		);

endmodule
