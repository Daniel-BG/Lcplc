`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCM
// Engineer: Daniel Báscones
// 
// Create Date: 25.02.2019 12:53:59
// Design Name: 
// Module Name: test_nthband_predictor
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


module test_nthband_predictor;

	parameter DATA_WIDTH=16;
	parameter BLOCK_SIZE_LOG=8;
	parameter ALPHA_WIDTH=10;
	parameter PERIOD=10;

	
	reg clk, rst;
	
	reg gen_alpha_enable;
	wire alpha_valid, alpha_ready;
	wire [ALPHA_WIDTH - 1:0] alpha_data;

	reg gen_xhat_enable;
	wire xhat_valid, xhat_ready;
	wire [DATA_WIDTH - 1:0] xhat_data;

	reg gen_xmean_enable;
	wire xmean_valid, xmean_ready;
	wire [DATA_WIDTH - 1:0] xmean_data;

	reg gen_xhatmean_enable;
	wire xhatmean_valid, xhatmean_ready;
	wire [DATA_WIDTH - 1:0] xhatmean_data;

	reg checker_enable;
	wire prediction_valid, prediction_ready;
	wire [DATA_WIDTH:0] prediction_data;

	
	always #(PERIOD/2) clk = ~clk;
	
	initial begin
		gen_alpha_enable = 0;
		gen_xhat_enable = 0;
		gen_xmean_enable = 0;
		gen_xhatmean_enable = 0;
		checker_enable = 0;
		clk = 0;
		rst = 1;
		#(PERIOD*2)
		rst = 0;
		gen_alpha_enable = 1;
		gen_xhat_enable = 1;
		gen_xmean_enable = 1;
		gen_xhatmean_enable = 1;
		checker_enable = 1;
	end
	
	helper_axis_reader #(.DATA_WIDTH(ALPHA_WIDTH), .FILE_NAME(`GOLDEN_ALPHA)) GEN_alpha
		(
			.clk(clk), .rst(rst), .enable(gen_alpha_enable),
			.output_valid(alpha_valid),
			.output_data(alpha_data),
			.output_ready(alpha_ready)
		);

	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_XHAT)) GEN_xhat
		(
			.clk(clk), .rst(rst), .enable(gen_xhat_enable),
			.output_valid(xhat_valid),
			.output_data(xhat_data),
			.output_ready(xhat_ready)
		);

	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_XMEAN)) GEN_xmean
		(
			.clk(clk), .rst(rst), .enable(gen_xmean_enable),
			.output_valid(xmean_valid),
			.output_data(xmean_data),
			.output_ready(xmean_ready)
		);

	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_XHATMEAN)) GEN_xhatmean
		(
			.clk(clk), .rst(rst), .enable(gen_xhatmean_enable),
			.output_valid(xhatmean_valid),
			.output_data(xhatmean_data),
			.output_ready(xhatmean_ready)
		);

	helper_axis_checker #(.SKIP(256), .DATA_WIDTH(DATA_WIDTH+1), .FILE_NAME(`GOLDEN_PREDICTION)) GEN_checker
		(
			.clk        (clk),
			.rst        (rst),
			.enable     (checker_enable),
			.input_valid(prediction_valid),
			.input_ready(prediction_ready),
			.input_data (prediction_data)
		);

	nthband_predictor #(.DATA_WIDTH(DATA_WIDTH), .ALPHA_WIDTH(ALPHA_WIDTH), .BLOCK_SIZE_LOG(BLOCK_SIZE_LOG)) predictor
		(
			.clk(clk), .rst(rst),
			.xhat_valid(xhat_valid),
			.xhat_ready(xhat_ready),
			.xhat_data(xhat_data),
			.xmean_valid(xmean_valid),
			.xmean_ready(xmean_ready),
			.xmean_data(xmean_data),
			.xhatmean_valid(xhatmean_valid),
			.xhatmean_ready(xhatmean_ready),
			.xhatmean_data(xhatmean_data),
			.alpha_valid(alpha_valid),
			.alpha_ready(alpha_ready),
			.alpha_data(alpha_data),
			.prediction_ready(prediction_ready),
			.prediction_valid(prediction_valid),
			.prediction_data(prediction_data)
		);

endmodule
