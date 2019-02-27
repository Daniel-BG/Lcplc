`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCM
// Engineer: Daniel Báscones
// 
// Create Date: 26.02.2019 16:18:07
// Design Name: 
// Module Name: test_processing_elements
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Test processing elements that take a single AXIS bus and operate over
//		its values to produce a results AXIS bus
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module test_axis_1in_1out;
	parameter PERIOD=10;
	parameter DATA_WIDTH=16;
	parameter OUT_WIDTH=16;
	parameter BLOCK_SIZE_LOG=8;
	parameter IS_SIGNED=0;
	parameter USE_ACC=0;
	parameter USE_AVG=0;
	parameter USE_REP=0;
	parameter USE_CLP=0;
	parameter USE_RED=0;
	parameter USE_SUB=1;
	
	//controls
	reg clk, rst;
	reg generator_enable;
	reg drain_enable;
	//inputs
	wire gen_valid, gen_ready;
	wire[DATA_WIDTH-1:0] gen_data;
	//wired outputs
	wire acc_ready;
	wire acc_valid;
	wire[OUT_WIDTH-1:0] acc_data;
	
	
	
	helper_axis_generator #(.DATA_WIDTH(DATA_WIDTH), .RANDOM(0)) GEN_0
		(
			.clk(clk), .rst(rst), .enable(generator_enable),
			.output_valid(gen_valid),
			.output_data(gen_data),
			.output_ready(gen_ready)
		);
		
	if (USE_ACC == 1) begin: gen_accumulator
		axis_accumulator #(.DATA_WIDTH(DATA_WIDTH), .ACC_COUNT_LOG(BLOCK_SIZE_LOG), .ACC_COUNT(2**BLOCK_SIZE_LOG), .IS_SIGNED(IS_SIGNED)) acc
			(
				.clk(clk), .rst(rst),
				.input_valid(gen_valid),
				.input_ready(gen_ready),
				.input_data(gen_data),
				.output_ready(acc_ready),
				.output_valid(acc_valid),
				.output_data(acc_data)
			);
	end

	if (USE_AVG == 1) begin: gen_averager
		axis_averager_pow2 #(.DATA_WIDTH(DATA_WIDTH), .ELEMENT_COUNT_LOG(BLOCK_SIZE_LOG), .IS_SIGNED(IS_SIGNED)) averager
			(
				.clk(clk), .rst(rst),
				.input_valid(gen_valid),
				.input_ready(gen_ready),
				.input_data(gen_data),
				.output_ready(acc_ready),
				.output_valid(acc_valid),
				.output_data(acc_data)
			);
	end
	
	if (USE_REP == 1) begin: gen_repeater
		axis_data_repeater #(.DATA_WIDTH(DATA_WIDTH), .NUMBER_OF_REPETITIONS(7)) repeater
			(
				.clk(clk), .rst(rst),
				.input_valid(gen_valid),
				.input_ready(gen_ready),
				.input_data(gen_data),
				.output_ready(acc_ready),
				.output_valid(acc_valid),
				.output_data(acc_data)
			);
	end

	if (USE_CLP == 1) begin: gen_clamper
		axis_interval_clamper #(.DATA_WIDTH(DATA_WIDTH), .IS_SIGNED(IS_SIGNED), .LOWER_LIMIT(256), .UPPER_LIMIT(2**14)) clamper
			(
				.clk(clk), .rst(rst),
				.input_valid(gen_valid),
				.input_ready(gen_ready),
				.input_data(gen_data),
				.output_ready(acc_ready),
				.output_valid(acc_valid),
				.output_data(acc_data)
			);
	end

	if (USE_RED == 1) begin: gen_reducer
		axis_reducer #(.DATA_WIDTH(DATA_WIDTH), .VALID_TRANSACTIONS(17), .INVALID_TRANSACTIONS(3), .START_VALID(1)) reducer
			(
				.clk(clk), .rst(rst),
				.input_valid(gen_valid),
				.input_ready(gen_ready),
				.input_data(gen_data),
				.output_ready(acc_ready),
				.output_valid(acc_valid),
				.output_data(acc_data)
			);
	end

	reg substituter_clear;
	initial begin
		substituter_clear = 0;
		#(PERIOD*128);
		substituter_clear = 1;
		#(PERIOD);
		substituter_clear = 0;
	end

	reg [DATA_WIDTH-1:0] input_sub;
	assign input_sub = {DATA_WIDTH{1'b1}};
	if (USE_SUB == 1) begin: gen_substituter
		axis_substituter #(.DATA_WIDTH(DATA_WIDTH), .INVALID_TRANSACTIONS(4)) substituter
			(
				.clk(clk), .rst(rst),
				.clear(substituter_clear),
				.input_valid(gen_valid),
				.input_ready(gen_ready),
				.input_data(gen_data),
				.input_sub(input_sub),
				.output_ready(acc_ready),
				.output_valid(acc_valid),
				.output_data(acc_data)
			);
	end
		
	helper_axis_drain #(.DATA_WIDTH(OUT_WIDTH)) DRAIN
		(
			.clk(clk), .rst(rst), .enable(drain_enable),
			.input_valid(acc_valid),
			.input_ready(acc_ready),
			.input_data(acc_data)
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