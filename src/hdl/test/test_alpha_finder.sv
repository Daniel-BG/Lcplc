`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCM
// Engineer: Daniel Báscones
// 
// Create Date: 25.02.2019 12:53:59
// Design Name: 
// Module Name: test_alpha_finder
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Test the alpha finder module
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module test_alpha_finder;

	parameter DATA_WIDTH=16;
	parameter BLOCK_SIZE_LOG=8;
	parameter ALPHA_WIDTH=10;
	parameter PERIOD=10;

	parameter FINAL_WIDTH=DATA_WIDTH*2 + 2 + BLOCK_SIZE_LOG;
	
	reg clk, rst;
	
	reg generator_0_enable;
	wire gen_0_valid, gen_0_ready;
	wire[FINAL_WIDTH - 1:0] gen_0_data;
	
	reg generator_1_enable;
	wire gen_1_valid, gen_1_ready;
	wire[FINAL_WIDTH - 1:0] gen_1_data;
	
	wire drain_valid, drain_ready;
	wire[ALPHA_WIDTH-1:0] drain_data;
	
	reg drain_enable;
	
	always #(PERIOD/2) clk = ~clk;
	
	initial begin
		generator_0_enable = 0;
		generator_1_enable = 0;
		drain_enable = 0;
		clk = 0;
		rst = 1;
		#(PERIOD*2)
		#(PERIOD/2)
		rst = 0;
		generator_0_enable = 1;
		generator_1_enable = 1;
		drain_enable = 1;
	end
	
	helper_axis_generator #(.DATA_WIDTH(FINAL_WIDTH), .START_AT(1)) GEN_0
		(
			.clk(clk), .rst(rst), .enable(generator_0_enable),
			.output_valid(gen_0_valid),
			.output_data(gen_0_data),
			.output_ready(gen_0_ready)
		);
		
	helper_axis_generator #(.DATA_WIDTH(FINAL_WIDTH), .START_AT(2)) GEN_1
		(
			.clk(clk), .rst(rst), .enable(generator_1_enable),
			.output_valid(gen_1_valid),
			.output_data(gen_1_data),
			.output_ready(gen_1_ready)
		);

	
	helper_axis_drain #(.DATA_WIDTH(ALPHA_WIDTH)) DRAIN
		(
			.clk(clk), .rst(rst), .enable(drain_enable),
			.input_valid(drain_valid),
			.input_ready(drain_ready),
			.input_data(drain_data)
		);

	alpha_finder #(.DATA_WIDTH(DATA_WIDTH), .BLOCK_SIZE_LOG(BLOCK_SIZE_LOG), .ALPHA_WIDTH(ALPHA_WIDTH)) FINDER
		(
			.clk(clk), .rst(rst),
			.alphan_data(gen_0_data),
			.alphan_ready(gen_0_ready),
			.alphan_valid(gen_0_valid),
			.alphad_data(gen_1_data),
			.alphad_ready(gen_1_ready),
			.alphad_valid(gen_1_valid),
			.output_data(drain_data),
			.output_ready(drain_ready),
			.output_valid(drain_valid)
		);


endmodule
