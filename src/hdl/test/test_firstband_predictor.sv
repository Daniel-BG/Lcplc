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

module test_firstband_predictor;
	parameter PERIOD=10;
	parameter DATA_WIDTH=16;
	parameter BLOCK_SIZE_LOG=8;
	
	//controls
	reg clk, rst;
	reg generator_enable;
	reg drain_enable;
	//inputs
	wire gen_valid, gen_ready;
	wire[DATA_WIDTH-1:0] gen_data;
	//wired outputs
	wire pred_ready;
	wire pred_valid;
	wire[DATA_WIDTH:0] pred_data;
	
	
	
	helper_axis_generator #(.DATA_WIDTH(DATA_WIDTH), .RANDOM(0)) GEN_0
		(
			.clk(clk), .rst(rst), .enable(generator_enable),
			.output_valid(gen_valid),
			.output_data(gen_data),
			.output_ready(gen_ready)
		);
		
	firstband_predictor #(.DATA_WIDTH(DATA_WIDTH), .BLOCK_SIZE_LOG(BLOCK_SIZE_LOG)) PREDICTOR
		(
			.clk(clk), .rst(rst),
			.x_valid(gen_valid),
			.x_ready(gen_ready),
			.x_data(gen_data),
			.prediction_ready(pred_ready),
			.prediction_valid(pred_valid),
			.prediction_data(pred_data)
		);
		
	helper_axis_drain #(.DATA_WIDTH(DATA_WIDTH+1)) DRAIN
		(
			.clk(clk), .rst(rst), .enable(drain_enable),
			.input_valid(pred_valid),
			.input_ready(pred_ready),
			.input_data(pred_data)
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