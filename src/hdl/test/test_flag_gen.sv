`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.04.2019 17:40:14
// Design Name: 
// Module Name: test_flag_gen
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module test_flag_gen;
	parameter PERIOD = 10;
	
	parameter DATA_WIDTH = 16;
	parameter MAX_BLOCK_SAMPLE_LOG = 4;
	parameter MAX_BLOCK_LINE_LOG = 4;
	parameter MAX_IMAGE_SAMPLE_LOG = 12;
	parameter MAX_IMAGE_LINE_LOG = 12;
	parameter MAX_IMAGE_BAND_LOG = 12;
	parameter LATCH_INPUT = 1;
	parameter LATCH_OUTPUT = 1;

	wire[MAX_BLOCK_SAMPLE_LOG-1:0] config_block_samples;
	wire[MAX_BLOCK_LINE_LOG  -1:0] config_block_lines;
	wire[MAX_IMAGE_SAMPLE_LOG-1:0] config_image_samples;
	wire[MAX_IMAGE_LINE_LOG  -1:0] config_image_lines;
	wire[MAX_IMAGE_BAND_LOG  -1:0] config_image_bands;
	assign config_block_samples = 2; //3 total
	assign config_block_lines   = 2; //3 total
	assign config_image_samples = 6; //7 total
	assign config_image_lines   = 6; //7 total
	assign config_image_bands   = 2; //3 total
    
	//controls
	reg clk, rst;
	reg generator_enable;
	reg drain_enable;
	//inputs
	wire gen_valid, gen_ready;
	wire[DATA_WIDTH-1:0] gen_data;
	//wired outputs
	wire drain_ready;
	wire drain_valid;
	wire[DATA_WIDTH-1:0] drain_data;
	wire drain_last_s, drain_last_r, drain_last_b, drain_last_i;

	helper_axis_generator #(.DATA_WIDTH(DATA_WIDTH), .RANDOM(0)) GEN_0
		(
			.clk(clk), .rst(rst), .enable(generator_enable),
			.output_valid(gen_valid),
			.output_data(gen_data),
			.output_ready(gen_ready)
		);

	helper_axis_drain #(.DATA_WIDTH(DATA_WIDTH)) DRAIN
		(
			.clk(clk), .rst(rst), .enable(drain_enable),
			.input_valid(drain_valid),
			.input_ready(drain_ready),
			.input_data(drain_data)
		);

	flag_generator_blocked
		#(
			.DATA_WIDTH(DATA_WIDTH),
			.MAX_BLOCK_SAMPLE_LOG(MAX_BLOCK_SAMPLE_LOG),
			.MAX_BLOCK_LINE_LOG(MAX_BLOCK_LINE_LOG),
			.MAX_IMAGE_SAMPLE_LOG(MAX_IMAGE_SAMPLE_LOG),
			.MAX_IMAGE_LINE_LOG(MAX_IMAGE_LINE_LOG),
			.MAX_IMAGE_BAND_LOG(MAX_IMAGE_BAND_LOG),
			.LATCH_INPUT(LATCH_INPUT),
			.LATCH_OUTPUT(LATCH_OUTPUT)
		) FLAG_GEN
		(
			.clk(clk), .rst(rst),
			.config_block_samples(config_block_samples),
			.config_block_lines(config_block_lines),
			.config_image_samples(config_image_samples),
			.config_image_lines(config_image_lines),
			.config_image_bands(config_image_bands),
			.raw_input_data(gen_data),
			.raw_input_ready(gen_ready),
			.raw_input_valid(gen_valid),
			.output_data(drain_data),
			.output_last_r(drain_last_r),
			.output_last_s(drain_last_s),
			.output_last_b(drain_last_b),
			.output_last_i(drain_last_i),
			.output_ready(drain_ready),
			.output_valid(drain_valid)
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
		drain_enable = 1;
	end


endmodule
