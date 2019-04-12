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

	helper_axis_generator #(.DATA_WIDTH(DATA_WIDTH_0), .START_AT(1), .END_AT(39)) GEN_0
		(
			.clk(clk), .rst(rst), .enable(generator_0_enable),
			.output_valid(gen_0_valid),
			.output_data(gen_0_data),
			.output_ready(gen_0_ready)
		);
		
	helper_axis_generator #(.DATA_WIDTH(DATA_WIDTH_1), .START_AT(1), .END_AT(39)) GEN_1
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
	
	wire packer_ready;
	reg packer_valid;
	reg [DATA_WIDTH_0 - 1:0] packer_code;
	reg [DATA_WIDTH_1 - 1:0] packer_length;

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
		generator_1_enable = 0;
		#(PERIOD*2)
		while (1) begin
			#(PERIOD*2) generator_0_enable = 1;
			generator_1_enable = 1;
			#(PERIOD) generator_0_enable = 0;
			generator_1_enable = 0;
		end
	end
	initial begin
		drain_enable = 0;
		#(PERIOD*2)
		while (1) begin
			#(PERIOD*5) drain_enable = 1;
			#(PERIOD) drain_enable = 0;
		end
	end

	wire packer_out_valid, packer_out_ready;
	wire [2**OUT_WIDTH_LOG-1:0] packer_out_data;
	
	//custom feed the packer
	initial begin
		packer_valid = 0;
		#(PERIOD*4)
		packer_code = 10028;
		packer_length = 27;
		packer_valid = 1;
		@(posedge clk) wait (packer_ready == 1 && clk == 1);
		packer_code = -14650;
		packer_length = 14;
		@(posedge clk) wait (packer_ready == 1 && clk == 1);
		packer_code = -4444;
		@(posedge clk) wait (packer_ready == 1 && clk == 1);
		packer_code = -16370;
		@(posedge clk) wait (packer_ready == 1 && clk == 1);
		packer_code = -8172;
		packer_length = 13;
		@(posedge clk) wait (packer_ready == 1 && clk == 1);
		packer_code = -8155;
		@(posedge clk) wait (packer_ready == 1 && clk == 1);
		packer_code = -8125;
		@(posedge clk) wait (packer_ready == 1 && clk == 1);
		packer_code = -8151;
		@(posedge clk) wait (packer_ready == 1 && clk == 1);
		packer_valid = 0;
	end

	coding_output_packer #(.CODE_WIDTH(DATA_WIDTH_0), .BIT_AMT_WIDTH(DATA_WIDTH_1), .OUTPUT_WIDTH_LOG(OUT_WIDTH_LOG)) packer
		(
			.clk(clk), .rst(rst),
			.input_code_data(packer_code),
			.input_length_data(packer_length),
			.input_valid(packer_valid),
			.input_ready(packer_ready),
			.input_last(0),
			.output_data(packer_out_data),
			.output_valid(packer_out_valid),
			.output_ready(packer_out_ready),
			.output_last()
		);


	helper_axis_drain #(.DATA_WIDTH(2**OUT_WIDTH_LOG)) DRAIN
		(
			.clk(clk), .rst(rst), .enable(drain_enable),
			.input_valid(packer_out_valid),
			.input_ready(packer_out_ready),
			.input_data(packer_out_data)
		);


endmodule
