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


module test_coding_output_packer;
	parameter PERIOD=10;
	parameter DATA_WIDTH_0=39;
	parameter DATA_WIDTH_1=6;
	parameter OUT_WIDTH_LOG=5;


	
	reg clk, rst;
	
	reg generator_0_enable;
	wire gen_0_valid, gen_0_ready;
	wire[DATA_WIDTH_0-1:0] gen_0_data;
	
	reg generator_1_enable;
	wire gen_1_valid, gen_1_ready;
	wire[DATA_WIDTH_1-1:0] gen_1_data;

	helper_axis_generator #(.DATA_WIDTH(DATA_WIDTH_0), .START_AT(1)) GEN_0
		(
			.clk(clk), .rst(rst), .enable(generator_0_enable),
			.output_valid(gen_0_valid),
			.output_data(gen_0_data),
			.output_ready(gen_0_ready)
		);
		
	helper_axis_generator #(.DATA_WIDTH(DATA_WIDTH_1), .START_AT(1), .END_AT(5)) GEN_1
		(
			.clk(clk), .rst(rst), .enable(generator_1_enable),
			.output_valid(gen_1_valid),
			.output_data(gen_1_data),
			.output_ready(gen_1_ready)
		);

	wire joint_gens_valid;
	wire joint_gens_ready;
	wire [DATA_WIDTH_0 - 1:0] joint_gens_bits;
	wire [DATA_WIDTH_1 - 1:0] joint_gens_amt;

	axis_synchronizer_2 #(.DATA_WIDTH_0(DATA_WIDTH_0), .DATA_WIDTH_1(DATA_WIDTH_1)) SYNCRHONIZER
		(
			.clk(clk), .rst(rst),
			.input_0_valid(gen_0_valid),
			.input_0_ready(gen_0_ready),
			.input_0_data(gen_0_data),
			.input_1_valid(gen_1_valid),
			.input_1_ready(gen_1_ready),
			.input_1_data(gen_1_data),
			.output_valid(joint_gens_valid),
			.output_ready(joint_gens_ready),
			.output_data_0(joint_gens_bits),
			.output_data_1(joint_gens_amt)
		);


	

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

	wire packer_valid, packer_ready;
	wire [2**OUT_WIDTH_LOG-1:0] packer_data;

	coding_output_packer #(.CODE_WIDTH(DATA_WIDTH_0), .BIT_AMT_WIDTH(DATA_WIDTH_1), .OUTPUT_WIDTH_LOG(OUT_WIDTH_LOG)) packer
		(
			.clk(clk), .rst(rst),
			.flush(0), .flushed(),
			.input_code_data(joint_gens_bits),
			.input_length_data(joint_gens_amt),
			.input_valid(joint_gens_valid),
			.input_ready(joint_gens_ready),
			.output_data(packer_data),
			.output_valid(packer_valid),
			.output_ready(packer_ready)
		);


	helper_axis_drain #(.DATA_WIDTH(2**OUT_WIDTH_LOG)) DRAIN
		(
			.clk(clk), .rst(rst), .enable(drain_enable),
			.input_valid(packer_valid),
			.input_ready(packer_ready),
			.input_data(packer_data)
		);


endmodule
