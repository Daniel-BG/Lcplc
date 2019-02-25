`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCM
// Engineer: Daniel Báscones
// 
// Create Date: 25.02.2019 12:53:59
// Design Name: 
// Module Name: test_axis_joiner_2
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Test for the joiner module
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module test_axis_joiner_2;
	parameter DATA_WIDTH=16;
	parameter PERIOD=10;
	
	reg clk, rst;
	
	reg generator_0_enable;
	wire gen_0_valid, gen_0_ready;
	wire[DATA_WIDTH-1:0] gen_0_data;
	
	reg generator_1_enable;
	wire gen_1_valid, gen_1_ready;
	wire[DATA_WIDTH-1:0] gen_1_data;
	
	wire joiner_valid, joiner_ready;
	wire[DATA_WIDTH-1:0] joiner_data_0, joiner_data_1;
	
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
		#(PERIOD*5)
		drain_enable = 0;
		#(PERIOD*5)
		drain_enable = 1;
	end
	
//	always begin
//		#(PERIOD)
//		generator_0_enable = ~generator_0_enable;
//	end
	
//	always begin
//		#(PERIOD)
//		generator_1_enable = ~generator_1_enable;
//	end
	
	
	
	
	helper_axis_generator #(.DATA_WIDTH(DATA_WIDTH)) GEN_0
		(
			.clk(clk), .rst(rst), .enable(generator_0_enable),
			.output_valid(gen_0_valid),
			.output_data(gen_0_data),
			.output_ready(gen_0_ready)
		);
		
	helper_axis_generator #(.DATA_WIDTH(DATA_WIDTH)) GEN_1
		(
			.clk(clk), .rst(rst), .enable(generator_1_enable),
			.output_valid(gen_1_valid),
			.output_data(gen_1_data),
			.output_ready(gen_1_ready)
		);
	
	
	axis_synchronizer_2 #(.DATA_WIDTH_0(DATA_WIDTH), .DATA_WIDTH_1(DATA_WIDTH)) SYNCRHONIZER
		(
			.clk(clk), .rst(rst),
			.input_0_valid(gen_0_valid),
			.input_0_data(gen_0_data),
			.input_0_ready(gen_0_ready),
			.input_1_valid(gen_1_valid),
			.input_1_data(gen_1_data),
			.input_1_ready(gen_1_ready),
			.output_valid(joiner_valid),
			.output_data_0(joiner_data_0),
			.output_data_1(joiner_data_1),
			.output_ready(joiner_ready)
		);
	
	helper_axis_drain #(.DATA_WIDTH(DATA_WIDTH*2)) DRAIN
		(
			.clk(clk), .rst(rst), .enable(drain_enable),
			.input_valid(joiner_valid),
			.input_ready(joiner_ready),
			.input_data({joiner_data_0, joiner_data_1})
		);


endmodule
