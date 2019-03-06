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


module test_error_calc;

	parameter BANDS=224;
	parameter DATA_WIDTH=16;
	parameter BLOCK_SIZE_LOG=8;
	parameter ACC_LOG=5;
	parameter UPSHIFT=1;
	parameter DOWNSHIFT=1;
	parameter THRESHOLD=0;

	parameter PERIOD=10;


	
	reg clk, rst;


	//generators
	reg gen_x_enable;
	wire x_valid, x_ready;
	wire [DATA_WIDTH - 1:0] x_data;

	reg gen_prediction_enable;
	wire prediction_valid, prediction_ready;
	wire [DATA_WIDTH + 2:0] prediction_data;

	//checkers
	reg merr_checker_enable;
	wire merr_valid, merr_ready;
	wire [DATA_WIDTH + 2:0] merr_data;

	reg kj_checker_enable;
	wire kj_valid, kj_ready;
	wire [ACC_LOG - 1:0] kj_data;

	reg xtilde_checker_enable;
	wire xtilde_valid, xtilde_ready;
	wire [DATA_WIDTH - 1:0] xtilde_data;

	reg xhatout_checker_enable;
	wire xhatout_valid, xhatout_ready;
	wire [DATA_WIDTH - 1:0] xhatout_data;
	
	reg dflag_checker_enable;
	wire dflag_valid, dflag_ready;
	wire [0:0] dflag_data;


	
	always #(PERIOD/2) clk = ~clk;
	
	initial begin
		gen_x_enable = 0;
		gen_prediction_enable = 0;

		merr_checker_enable = 0;
		kj_checker_enable = 0;
		xtilde_checker_enable = 0;
		xhatout_checker_enable = 0;
		dflag_checker_enable = 0;
		clk = 0;
		rst = 1;
		#(PERIOD*2)
		rst = 0;
		gen_x_enable = 1;
		gen_prediction_enable = 1;

		merr_checker_enable = 1;
		kj_checker_enable = 1;
		xtilde_checker_enable = 1;
		xhatout_checker_enable = 1;
		dflag_checker_enable = 1;
	end
	
	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_X)) GEN_alpha
		(
			.clk(clk), .rst(rst), .enable(gen_x_enable),
			.output_valid(x_valid),
			.output_data(x_data),
			.output_ready(x_ready)
		);

	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH+3), .FILE_NAME(`GOLDEN_PREDICTION)) GEN_pred
		(
			.clk(clk), .rst(rst), .enable(gen_prediction_enable),
			.output_valid(prediction_valid),
			.output_data(prediction_data),
			.output_ready(prediction_ready)
		);

	helper_axis_checker #(.DATA_WIDTH(DATA_WIDTH+3), .FILE_NAME(`GOLDEN_MERR)) GEN_checker_merr
		(
			.clk        (clk), .rst        (rst), .enable     (merr_checker_enable),
			.input_valid(merr_valid),
			.input_ready(merr_ready),
			.input_data (merr_data)
		);

	helper_axis_checker #(.DATA_WIDTH(ACC_LOG), .FILE_NAME(`GOLDEN_KJ)) GEN_checker_kj
		(
			.clk        (clk), .rst        (rst), .enable     (kj_checker_enable),
			.input_valid(kj_valid),
			.input_ready(kj_ready),
			.input_data (kj_data)
		);

	helper_axis_checker #(.DATA_WIDTH(ACC_LOG), .FILE_NAME(`GOLDEN_XTILDE)) GEN_checker_xtilde
		(
			.clk        (clk), .rst        (rst), .enable     (xtilde_checker_enable),
			.input_valid(xtilde_valid),
			.input_ready(xtilde_ready),
			.input_data (xtilde_data)
		);

	helper_axis_checker #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_XHAT)) GEN_checker_xhatout
		(
			.clk        (clk), .rst        (rst), .enable     (xhatout_checker_enable),
			.input_valid(xhatout_valid),
			.input_ready(xhatout_ready),
			.input_data (xhatout_data)
		);

	helper_axis_checker #(.DATA_WIDTH(1), .FILE_NAME(`GOLDEN_DFLAG)) GEN_checker_dflag
		(
			.clk        (clk), .rst        (rst), .enable     (dflag_checker_enable),
			.input_valid(dflag_valid),
			.input_ready(dflag_ready),
			.input_data (dflag_data)
		);


	error_calc #(
		.BANDS(BANDS),
		.DATA_WIDTH(DATA_WIDTH),
		.BLOCK_SIZE_LOG(BLOCK_SIZE_LOG),
		.ACC_LOG(ACC_LOG),
		.UPSHIFT(UPSHIFT),
		.DOWNSHIFT(DOWNSHIFT),
		.THRESHOLD(THRESHOLD)
	) error_calc_module
		(
			.clk(clk),
			.rst(rst),
			.x_valid(x_valid),
			.x_ready(x_ready),			
			.x_data(x_data),			
			.prediction_ready(prediction_ready),
			.prediction_valid(prediction_valid),
			.prediction_data(prediction_data),
			.merr_ready(merr_ready),		
			.merr_valid(merr_valid),		
			.merr_data(merr_data),		
			.kj_ready(kj_ready),		
			.kj_valid(kj_valid),		
			.kj_data(kj_data),			
			.xtilde_valid(xtilde_valid),	
			.xtilde_ready(xtilde_ready),	
			.xtilde_data(xtilde_data),		
			.xhatout_valid(xhatout_valid),   
			.xhatout_ready(xhatout_ready),	
			.xhatout_data(xhatout_data),	
			.d_flag_valid(dflag_valid),	
			.d_flag_ready(dflag_ready),	
			.d_flag_data(dflag_data) 	
		);

endmodule
