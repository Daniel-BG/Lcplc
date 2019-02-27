`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCM
// Engineer: Daniel Báscones
// 
// Create Date: 27.02.2019 09:51:23
// Design Name: 
// Module Name: test_axis_3in_1out
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Test AXIS modules with three inputs and 1 output
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module test_axis_3in_1out;
	parameter PERIOD = 10;
	parameter DATA_WIDTH_0 = 16;
	parameter DATA_WIDTH_1 = 16;
	parameter DATA_WIDTH_2 = 16;
	parameter OUT_WIDTH = 16;

	////////////////////////////////////////
	// MAIN CONTROL 					  //
	////////////////////////////////////////	
	reg clk, rst;
	always #(PERIOD/2) clk = ~clk;

	////////////////////////////////////////
	// GENERATOR AND DRAIN DELCLARATIONS  //
	////////////////////////////////////////	
	reg generator_0_enable;
	wire gen_0_valid, gen_0_ready;
	wire [DATA_WIDTH_0-1:0] gen_0_data;
	helper_axis_generator #(.DATA_WIDTH(DATA_WIDTH_0)) GEN_0
		(
			.clk(clk), .rst(rst), .enable(generator_0_enable),
			.output_valid(gen_0_valid),
			.output_data(gen_0_data),
			.output_ready(gen_0_ready)
		);

	reg generator_1_enable;
	wire gen_1_valid, gen_1_ready;
	wire [DATA_WIDTH_1-1:0] gen_1_data;
	helper_axis_generator #(.DATA_WIDTH(DATA_WIDTH_1)) GEN_1
		(
			.clk(clk), .rst(rst), .enable(generator_1_enable),
			.output_valid(gen_1_valid),
			.output_data(gen_1_data),
			.output_ready(gen_1_ready)
		);

	reg generator_2_enable;
	wire gen_2_valid, gen_2_ready;
	wire [DATA_WIDTH_2-1:0] gen_2_data;
	helper_axis_generator #(.DATA_WIDTH(DATA_WIDTH_2)) GEN_2
		(
			.clk(clk), .rst(rst), .enable(generator_2_enable),
			.output_valid(gen_2_valid),
			.output_data(gen_2_data),
			.output_ready(gen_2_ready)
		);

	reg drain_enable;
	wire drain_valid, drain_ready;
	wire [OUT_WIDTH-1:0] drain_data;
	helper_axis_drain #(.DATA_WIDTH(OUT_WIDTH)) DRAIN
		(
			.clk(clk), .rst(rst), .enable(drain_enable),
			.input_valid(drain_valid),
			.input_ready(drain_ready),
			.input_data(drain_data)
		);

	initial begin
		clk = 0;
		rst = 1;
		generator_0_enable = 0;
		generator_1_enable = 0;
		generator_2_enable = 0;
		drain_enable = 0;
		#(PERIOD/2);
		#(PERIOD*2);
		rst = 0;
		generator_0_enable = 1;
		generator_1_enable = 1;
		generator_2_enable = 1;
		drain_enable = 1;
	end


	////////////////////////////////////////
	// DUT DELCLARATIONS 				  //
	////////////////////////////////////////	
	reg merger_clear;
	initial begin
		merger_clear = 0;
		#(PERIOD*256);
		merger_clear = 1;
		#(PERIOD*2)
		merger_clear = 0;
	end
	AXIS_MERGER #(.DATA_WIDTH(DATA_WIDTH_0), .FROM_PORT_ZERO(17), .FROM_PORT_ONE(17)) merger_dut
		(
			.clk(clk), .rst(rst), .clear(merger_clear),
			.input_0_valid(gen_0_valid),
			.input_0_ready(gen_0_ready),
			.input_0_data(gen_0_data),
			.input_1_valid(gen_1_valid),
			.input_1_ready(gen_1_ready),
			.input_1_data(gen_1_data),
			.input_2_ready(gen_2_ready),
			.input_2_valid(gen_2_valid),
			.input_2_data(gen_2_data),
			.output_ready(drain_ready),
			.output_valid(drain_valid),
			.output_data(drain_data)
		);


endmodule
