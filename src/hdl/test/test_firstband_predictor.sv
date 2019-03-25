`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCM
// Engineer: Daniel Báscones
// 
// Create Date: 26.02.2019 16:18:07
// Design Name: 
// Module Name: test_firstband_predictor
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Test the first band predictor to see if it works as intended
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "test_shared.svh"

module test_firstband_predictor;
	parameter PERIOD=10;
	parameter DATA_WIDTH=16;
	parameter BLOCK_WIDTH_LOG_MAX=4;
	
	//controls
	reg clk, rst;
	reg generator_enable;
	reg drain_enable;
	//inputs
	wire gen_valid, gen_ready;
	wire[DATA_WIDTH-1:0] gen_data;
	wire gen_last_r, gen_last_s;
	//wired outputs
	wire pred_ready;
	wire pred_valid;
	wire[DATA_WIDTH-1:0] pred_data;
	
	
	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_X_FIRSTB)) GEN_input
		(
			.clk(clk), .rst(rst), .enable(generator_enable),
			.output_valid(gen_valid),
			.output_data(gen_data),
			.output_ready(gen_ready)
		);
	helper_axis_reader #(.DATA_WIDTH(1), .FILE_NAME(`GOLDEN_X_FIRSTB_LAST_R)) GEN_input_last_r
		(
			.clk(clk), .rst(rst), .enable(generator_enable),
			.output_valid(),
			.output_data(gen_last_r),
			.output_ready(gen_ready)
		);
	helper_axis_reader #(.DATA_WIDTH(1), .FILE_NAME(`GOLDEN_X_FIRSTB_LAST_S)) GEN_input_last_s
		(
			.clk(clk), .rst(rst), .enable(generator_enable),
			.output_valid(),
			.output_data(gen_last_s),
			.output_ready(gen_ready)
		);		
		
	
	firstband_predictor_new #(.DATA_WIDTH(DATA_WIDTH), .MAX_SLICE_SIZE_LOG(BLOCK_WIDTH_LOG_MAX)) PREDICTOR
		(
			.clk(clk), .rst(rst),
			.x_valid(gen_valid),
			.x_ready(gen_ready),
			.x_data(gen_data),
			.x_last_r(gen_last_r),
			.x_last_s(gen_last_s),
			.xtilde_ready(pred_ready),
			.xtilde_valid(pred_valid),
			.xtilde_data(pred_data),
			.xtilde_last()
		);

	helper_axis_checker #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(`GOLDEN_XTILDE_FIRSTB)) GEN_checker_length
		(
			.clk        (clk), .rst        (rst), .enable     (drain_enable),
			.input_valid(pred_valid),
			.input_ready(pred_ready),
			.input_data (pred_data)
		);	
	
	always #(PERIOD/2) clk = ~clk;

	
	initial begin
		clk = 1;
		rst = 1;
		generator_enable = 0;
		drain_enable = 0;
		
		#(PERIOD)
		#(PERIOD/2);
		rst = 0;
		generator_enable = 1;
		
		#(PERIOD*10);
		drain_enable = 1;
		
		#(PERIOD*10);
		generator_enable = 0;
		
		#(PERIOD*10);
		generator_enable = 1;
	end

    
endmodule