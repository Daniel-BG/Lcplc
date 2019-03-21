`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCM
// Engineer: Daniel Báscones
// 
// Create Date: 25.02.2019 12:11:21
// Design Name: 
// Module Name: test_axis_1in_2out
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Test modules with one input AXIS bus and two output AXIS buses
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module test_axis_1in_2out;
	parameter DATA_WIDTH=16;
	parameter PERIOD=10;
	parameter USE_SPL=0;
	parameter USE_SEP=1;
	
	reg clk, rst;
	
	reg generator_enable;
	wire gen_valid, gen_ready;
	wire[DATA_WIDTH-1:0] gen_data;
	
	wire splitter_0_valid, splitter_0_ready;
	wire[DATA_WIDTH-1:0] splitter_0_data;
	
	wire splitter_1_valid, splitter_1_ready;
	wire[DATA_WIDTH-1:0] splitter_1_data;
	
	reg drain_0_enable, drain_1_enable;
	
	always #(PERIOD) clk = ~clk;
	
	initial begin
		generator_enable = 0;
		drain_0_enable = 0;
		drain_1_enable = 0;
		clk = 0;
		rst = 1;
		#(PERIOD*2)
		#(PERIOD/2)
		rst = 0;
		generator_enable = 1;
	end
	
	always begin
		#(PERIOD*2)
		drain_0_enable = ~drain_0_enable;
	end
	
	always begin
		#(PERIOD*3)
		drain_1_enable = ~drain_1_enable;
	end
	
	
	
	
	helper_axis_generator #(.DATA_WIDTH(DATA_WIDTH)) GEN
		(
			.clk(clk), .rst(rst), .enable(generator_enable),
			.output_valid(gen_valid),
			.output_data(gen_data),
			.output_ready(gen_ready)
		);
		
	if (USE_SPL == 1) begin: gen_splitter
		axis_splitter_2 #(.DATA_WIDTH(DATA_WIDTH)) SPLITTER
			(
				.clk(clk), .rst(rst),
				.input_valid(gen_valid),
				.input_data(gen_data),
				.input_ready(gen_ready),
				.output_0_valid(splitter_0_valid),
				.output_0_data(splitter_0_data),
				.output_0_ready(splitter_0_ready),
				.output_1_valid(splitter_1_valid),
				.output_1_data(splitter_1_data),
				.output_1_ready(splitter_1_ready)
			);
	end

	if (USE_SEP == 1) begin: gen_separator
		axis_separator #(.DATA_WIDTH(DATA_WIDTH), .TO_PORT_ZERO(17), .TO_PORT_ONE(5)) separator
			(
				.clk(clk), .rst(rst),
				.input_valid(gen_valid),
				.input_data(gen_data),
				.input_ready(gen_ready),
				.output_0_valid(splitter_0_valid),
				.output_0_data(splitter_0_data),
				.output_0_ready(splitter_0_ready),
				.output_1_valid(splitter_1_valid),
				.output_1_data(splitter_1_data),
				.output_1_ready(splitter_1_ready)
			);
	end
	
	helper_axis_drain #(.DATA_WIDTH(DATA_WIDTH)) DRAIN_0
		(
			.clk(clk), .rst(rst), .enable(drain_0_enable),
			.input_valid(splitter_0_valid),
			.input_ready(splitter_0_ready),
			.input_data(splitter_0_data)
		);
		
	helper_axis_drain #(.DATA_WIDTH(DATA_WIDTH)) DRAIN_1
		(
			.clk(clk), .rst(rst), .enable(drain_1_enable),
			.input_valid(splitter_1_valid),
			.input_ready(splitter_1_ready),
			.input_data(splitter_1_data)
		);
	

endmodule
