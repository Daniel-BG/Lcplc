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


module test_axis_2in_1out;
	parameter DATA_WIDTH_0=39;
	parameter DATA_WIDTH_1=6;
	parameter OUT_WIDTH=40; //DATA_WIDTH_0+DATA_WIDTH_1;
	parameter PERIOD=10;
	parameter USE_JOINER=0;
	parameter USE_FILTER=0;
	parameter USE_COMBINER=0;
	parameter USE_SHIFTER=1;
	parameter ELIMINATE_ON_UP=1;
	
	reg clk, rst;
	
	reg generator_0_enable;
	wire gen_0_valid, gen_0_ready;
	wire[DATA_WIDTH_0-1:0] gen_0_data;
	
	reg generator_1_enable;
	wire gen_1_valid, gen_1_ready;
	wire[DATA_WIDTH_1-1:0] gen_1_data;
	
	wire joiner_valid, joiner_ready;
	wire[DATA_WIDTH_0-1:0] joiner_data_0;
	wire[DATA_WIDTH_1-1:0] joiner_data_1;
	
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
	
	helper_axis_generator #(.DATA_WIDTH(DATA_WIDTH_0)) GEN_0
		(
			.clk(clk), .rst(rst), .enable(generator_0_enable),
			.output_valid(gen_0_valid),
			.output_data(gen_0_data),
			.output_ready(gen_0_ready)
		);
		
	helper_axis_generator #(.DATA_WIDTH(DATA_WIDTH_1)) GEN_1
		(
			.clk(clk), .rst(rst), .enable(generator_1_enable),
			.output_valid(gen_1_valid),
			.output_data(gen_1_data),
			.output_ready(gen_1_ready)
		);
	
	if (USE_JOINER==1) begin: sync
		axis_synchronizer_2 #(.DATA_WIDTH_0(DATA_WIDTH_0), .DATA_WIDTH_1(DATA_WIDTH_1)) SYNCRHONIZER
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
	end
	
	if (USE_FILTER==1) begin: filter
		axis_filter #(.DATA_WIDTH(DATA_WIDTH_0), .ELIMINATE_ON_UP(ELIMINATE_ON_UP)) FILTER
			(
				.clk(clk), .rst(rst),
				.input_valid(gen_0_valid),
				.input_data(gen_0_data),
				.input_ready(gen_0_ready),
				.flag_valid(gen_1_valid),
				.flag_data(gen_1_data),
				.flag_ready(gen_1_ready),
				.output_valid(joiner_valid),
				.output_data(joiner_data_0),
				.output_ready(joiner_ready)
			);
		assign joiner_data_1 = 0;
	end

	if (USE_COMBINER==1) begin: combiner
		axis_combiner #(.DATA_WIDTH(DATA_WIDTH_0), .FROM_PORT_ZERO(16), .FROM_PORT_ONE(7)) COMBINER
			(
				.clk(clk), .rst(rst),
				.input_0_valid(gen_0_valid),
				.input_0_data(gen_0_data),
				.input_0_ready(gen_0_ready),
				.input_1_valid(gen_1_valid),
				.input_1_data(gen_1_data),
				.input_1_ready(gen_1_ready),
				.output_valid(joiner_valid),
				.output_data(joiner_data_0),
				.output_ready(joiner_ready)
			);
		assign joiner_data_1 = 0;
	end

	if (USE_SHIFTER==1) begin: shifter
		axis_shifter #(.SHIFT_WIDTH(DATA_WIDTH_1), .DATA_WIDTH(DATA_WIDTH_0), .LEFT(1), .ARITHMETIC(0)) SHIFTER
			(
				.clk(clk), .rst(rst),
				.shift_valid(gen_1_valid),
				.shift_data(gen_1_data),
				.shift_ready(gen_1_ready),
				.input_valid(gen_0_valid),
				.input_data(gen_0_data),
				.input_ready(gen_0_ready),
				.output_valid(joiner_valid),
				.output_data(joiner_data_0),
				.output_ready(joiner_ready)
			);
		assign joiner_data_1 = 0;
	end
	
	
	helper_axis_drain #(.DATA_WIDTH(OUT_WIDTH)) DRAIN
		(
			.clk(clk), .rst(rst), .enable(drain_enable),
			.input_valid(joiner_valid),
			.input_ready(joiner_ready),
			.input_data({joiner_data_1, joiner_data_0})
		);


endmodule
