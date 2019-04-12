`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCM
// Engineer: Daniel Báscones
// 
// Create Date: 25.02.2019 12:53:59
// Design Name: 
// Module Name: test_axis_2in_1out
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Test AXIS modules with two inputs and one output bus
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module test_shifter;
	parameter PERIOD=10;
	parameter SHIFT_WIDTH=7;
	parameter INPUT_WIDTH=39;
	parameter OUTPUT_WIDTH=70;
	parameter BITS_PER_STAGE=4;


	reg clk, rst;
	
	reg generator_0_enable;
	wire gen_0_valid, gen_0_ready;
	wire[SHIFT_WIDTH-1:0] gen_0_data;
	
	reg generator_1_enable;
	wire gen_1_valid, gen_1_ready;
	wire[INPUT_WIDTH-1:0] gen_1_data;

	helper_axis_generator #(.DATA_WIDTH(SHIFT_WIDTH), .START_AT(1), .END_AT(39)) GEN_0
		(
			.clk(clk), .rst(rst), .enable(generator_0_enable),
			.output_valid(gen_0_valid),
			.output_data(gen_0_data),
			.output_ready(gen_0_ready)
		);
		
	helper_axis_generator #(.DATA_WIDTH(INPUT_WIDTH), .START_AT(1), .END_AT(39)) GEN_1
		(
			.clk(clk), .rst(rst), .enable(generator_1_enable),
			.output_valid(gen_1_valid),
			.output_data(gen_1_data),
			.output_ready(gen_1_ready)
		);
	
	reg drain_enable;
	wire drain_valid, drain_ready;
	wire [OUTPUT_WIDTH - 1:0] drain_data;

	always #(PERIOD/2) clk = ~clk;
	
	initial begin
//		generator_0_enable = 0;
//		generator_1_enable = 0;
//		drain_enable = 0;
		clk = 0;
		rst = 1;
		#(PERIOD*2)
		
		//#(PERIOD/2)
		rst = 0;
//		generator_0_enable = 1;
//		generator_1_enable = 1;
//		drain_enable = 1;
	end
	
	initial begin
		generator_0_enable = 0;
		#(PERIOD*2)
		while (1) begin
			#(PERIOD*7) generator_0_enable = 1;
			#(PERIOD) generator_0_enable = 0;
		end
	end
	initial begin
		generator_1_enable = 0;
		#(PERIOD*2)
		while (1) begin
			#(PERIOD*5) generator_1_enable = 1;
			#(PERIOD) generator_1_enable = 0;
		end
	end
	initial begin
		drain_enable = 0;
		#(PERIOD*2)
		while (1) begin
			#(PERIOD*2) drain_enable = 1;
			#(PERIOD) drain_enable = 0;
		end
	end


	axis_shifter 
		#(
			.SHIFT_WIDTH(SHIFT_WIDTH),
			.INPUT_WIDTH(INPUT_WIDTH),
			.OUTPUT_WIDTH(OUTPUT_WIDTH),
			.BITS_PER_STAGE(BITS_PER_STAGE),
			.LEFT(1),
			.ARITHMETIC(0),
			.LATCH_INPUT_SYNC(1)
		) 
		shifter
		(
			.clk(clk),.rst(rst),
			.shift_data(gen_0_data),
			.shift_ready(gen_0_ready),
			.shift_valid(gen_0_valid),
			.shift_last(0),
			.input_data(gen_1_data),
			.input_ready(gen_1_ready),
			.input_valid(gen_1_valid),
			.input_last(0),
			.output_data(drain_data),
			.output_ready(drain_ready),
			.output_valid(drain_valid)
		);

	helper_axis_drain #(.DATA_WIDTH(OUTPUT_WIDTH)) DRAIN
		(
			.clk(clk), .rst(rst), .enable(drain_enable),
			.input_valid(drain_valid),
			.input_ready(drain_ready),
			.input_data(drain_data)
		);


endmodule
