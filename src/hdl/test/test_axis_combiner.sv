`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCM
// Engineer: Daniel Báscones
// 
// Create Date: 26.02.2019 17:52:50
// Design Name: 
// Module Name: test_axis_combiner
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Test the AXIS COMBINER module
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: 
// 
//////////////////////////////////////////////////////////////////////////////////


module test_axis_combiner;
	parameter DATA_WIDTH=16;
	parameter OUT_WIDTH=DATA_WIDTH;
	parameter PERIOD=10;
	
	reg clk, rst;
	
	reg generator_0_enable;
	wire gen_0_valid, gen_0_ready;
	wire[DATA_WIDTH-1:0] gen_0_data;
	
	reg generator_1_enable;
	wire gen_1_valid, gen_1_ready;
	wire[DATA_WIDTH-1:0] gen_1_data;
	
	wire unit_valid, unit_ready;
	wire[OUT_WIDTH-1:0] unit_data;
	
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
	
	axis_combiner #(.DATA_WIDTH(DATA_WIDTH), .FROM_PORT_ZERO(16), .FROM_PORT_ONE(7)) COMBINER
		(
			.clk(clk), .rst(rst),
			.input_0_valid(gen_0_valid),
			.input_0_data(gen_0_data),
			.input_0_ready(gen_0_ready),
			.input_1_valid(gen_1_valid),
			.input_1_data(gen_1_data),
			.input_1_ready(gen_1_ready),
			.output_valid(unit_valid),
			.output_data(unit_data),
			.output_ready(unit_ready)
		);
		
	helper_axis_drain #(.DATA_WIDTH(OUT_WIDTH)) DRAIN
		(
			.clk(clk), .rst(rst), .enable(drain_enable),
			.input_valid(unit_valid),
			.input_ready(unit_ready),
			.input_data(unit_data)
		);


endmodule

