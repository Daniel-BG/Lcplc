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
	parameter DATA_WIDTH=16;
	parameter MAX_SLICE_SIZE_LOG=8;
	parameter ACCUMULATOR_WINDOW=32;
	parameter UPSHIFT=1;
	parameter DOWNSHIFT=1;
	parameter THRESHOLD=0;
	//inner constants
	parameter PERIOD=10;
	parameter ACC_LOG = 5;

	
	reg clk, rst;


	//generators
	reg gen_x_enable;
	wire x_valid, x_ready;
	wire [DATA_WIDTH - 1:0] x_data;
	wire x_last_s, x_last_b, x_last_i;

	reg gen_xtilde_enable;
	wire xtilde_valid, xtilde_ready;
	wire [DATA_WIDTH + 2:0] xtilde_data;
	wire xtilde_last_s;

	//checkers
	reg merr_checker_enable;
	wire merr_valid, merr_ready;
	wire merr_last_s, merr_last_b, merr_last_i;
	wire [DATA_WIDTH + 2:0] merr_data;

	reg kj_checker_enable;
	wire kj_valid, kj_ready;
	wire [ACC_LOG - 1:0] kj_data;

	reg xtilde_checker_enable;
	wire xtilde_out_valid, xtilde_out_ready;
	wire [DATA_WIDTH - 1:0] xtilde_out_data;
	wire xtilde_out_last_s;

	reg xhatraw_checker_enable;
	wire xhatraw_valid, xhatraw_ready;
	wire [DATA_WIDTH - 1:0] xhatraw_data;
	wire xhatraw_last_s, xhatraw_last_b;
	
	reg dflag_checker_enable;
	wire dflag_valid, dflag_ready;
	wire [0:0] dflag_data;

	
	always #(PERIOD/2) clk = ~clk;
	
	initial begin
		gen_x_enable = 0;
		gen_xtilde_enable = 0;

		merr_checker_enable = 0;
		kj_checker_enable = 0;
		xtilde_checker_enable = 0;
		xhatraw_checker_enable = 0;
		dflag_checker_enable = 0;
		clk = 0;
		rst = 1;
		#(PERIOD*2)
		rst = 0;
		gen_x_enable = 1;
		gen_xtilde_enable = 1;

		merr_checker_enable = 1;
		kj_checker_enable = 1;
		xtilde_checker_enable = 1;
		xhatraw_checker_enable = 1;
		dflag_checker_enable = 1;
	end
	
	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_X)) GEN_x
		(
			.clk(clk), .rst(rst), .enable(gen_x_enable),
			.output_valid(x_valid),
			.output_data(x_data),
			.output_ready(x_ready)
		);
	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_X_LAST_S)) GEN_x_last_s
		(
			.clk(clk), .rst(rst), .enable(gen_x_enable),
			.output_valid(), .output_data(x_last_s), .output_ready(x_ready)
		);
	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_X_LAST_B)) GEN_x_last_b
		(
			.clk(clk), .rst(rst), .enable(gen_x_enable),
			.output_valid(), .output_data(x_last_b), .output_ready(x_ready)
		);
	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_X_LAST_I)) GEN_x_last_i
		(
			.clk(clk), .rst(rst), .enable(gen_x_enable),
			.output_valid(), .output_data(x_last_i), .output_ready(x_ready)
		);


	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH+3), .FILE_NAME(`GOLDEN_XTILDE)) GEN_xtilde
		(
			.clk(clk), .rst(rst), .enable(gen_xtilde_enable),
			.output_valid(xtilde_valid),
			.output_data(xtilde_data),
			.output_ready(xtilde_ready)
		);
	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH+3), .FILE_NAME(`GOLDEN_XTILDE_LAST_S)) GEN_xtilde_last_s
		(
			.clk(clk), .rst(rst), .enable(gen_xtilde_enable),
			.output_valid(), .output_data(xtilde_last_s), .output_ready(xtilde_ready)
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
			.input_valid(xtilde_out_valid),
			.input_ready(xtilde_out_ready),
			.input_data (xtilde_out_data)
		);

	helper_axis_checker #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_XHATRAW)) GEN_checker_xhatout
		(
			.clk        (clk), .rst        (rst), .enable     (xhatraw_checker_enable),
			.input_valid(xhatraw_valid),
			.input_ready(xhatraw_ready),
			.input_data (xhatraw_data)
		);

	helper_axis_checker #(.DATA_WIDTH(1), .FILE_NAME(`GOLDEN_DFLAG)) GEN_checker_dflag
		(
			.clk        (clk), .rst        (rst), .enable     (dflag_checker_enable),
			.input_valid(dflag_valid),
			.input_ready(dflag_ready),
			.input_data (dflag_data)
		);


	error_calc #(
		.DATA_WIDTH(DATA_WIDTH),
		.MAX_SLICE_SIZE_LOG(MAX_SLICE_SIZE_LOG),
		.ACCUMULATOR_WINDOW(ACCUMULATOR_WINDOW),
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
			.x_last_s(x_last_s),
			.x_last_b(x_last_b),
			.x_last_i(x_last_i),		
			.xtilde_in_ready(xtilde_ready),
			.xtilde_in_valid(xtilde_valid),
			.xtilde_in_data(xtilde_data),
			.xtilde_in_last_s(xtilde_last_s),
			.merr_ready(merr_ready),		
			.merr_valid(merr_valid),		
			.merr_data(merr_data),		
			.merr_last_s(merr_last_s),
			.merr_last_b(merr_last_b),
			.merr_last_i(merr_last_i),
			.kj_ready(kj_ready),		
			.kj_valid(kj_valid),		
			.kj_data(kj_data),			
			.xtilde_out_valid(xtilde_out_valid),	
			.xtilde_out_ready(xtilde_out_ready),	
			.xtilde_out_data(xtilde_out_data),
			.xtilde_out_last_s(xtilde_out_last_s),		
			.xhatout_valid(xhatraw_valid),   
			.xhatout_ready(xhatraw_ready),	
			.xhatout_data(xhatraw_data),	
			.xhatout_last_s(xhatraw_last_s),
			.xhatout_last_b(xhatraw_last_b),
			.d_flag_valid(dflag_valid),	
			.d_flag_ready(dflag_ready),	
			.d_flag_data(dflag_data) 	
		);
	
endmodule
