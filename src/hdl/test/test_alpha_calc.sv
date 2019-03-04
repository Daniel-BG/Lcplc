`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCM
// Engineer: Daniel Báscones
// 
// Create Date: 25.02.2019 12:53:59
// Design Name: 
// Module Name: test_alpha_calc
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Test the alpha calc module
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module test_alpha_calc;

	parameter DATA_WIDTH=16;
	parameter BLOCK_SIZE_LOG=8;
	parameter ALPHA_WIDTH=10;
	parameter PERIOD=10;

	
	reg clk, rst;
	
	reg gen_x_enable;
	wire x_valid, x_ready;
	wire [DATA_WIDTH - 1:0] x_data;

	reg gen_xhat_enable;
	wire xhat_valid, xhat_ready;
	wire [DATA_WIDTH - 1:0] xhat_data;

	reg gen_xmean_enable;
	wire xmean_valid, xmean_ready;
	wire [DATA_WIDTH - 1:0] xmean_data;

	reg gen_xhatmean_enable;
	wire xhatmean_valid, xhatmean_ready;
	wire [DATA_WIDTH - 1:0] xhatmean_data;

	reg drain_alpha_enable;
	wire alpha_valid, alpha_ready;
	wire [ALPHA_WIDTH - 1:0] alpha_data;

	
	always #(PERIOD/2) clk = ~clk;
	
	initial begin
		gen_x_enable = 0;
		gen_xhat_enable = 0;
		gen_xmean_enable = 0;
		gen_xhatmean_enable = 0;
		drain_alpha_enable = 0;
		clk = 0;
		rst = 1;
		#(PERIOD*2)
		#(PERIOD/2)
		rst = 0;
		gen_x_enable = 1;
		gen_xhat_enable = 1;
		gen_xmean_enable = 1;
		gen_xhatmean_enable = 1;
		drain_alpha_enable = 1;
	end
	
	helper_axis_generator #(.DATA_WIDTH(DATA_WIDTH), .START_AT(512)) GEN_x
		(
			.clk(clk), .rst(rst), .enable(gen_x_enable),
			.output_valid(x_valid),
			.output_data(x_data),
			.output_ready(x_ready)
		);
		
	helper_axis_generator #(.DATA_WIDTH(DATA_WIDTH), .START_AT(256), .STEP(2)) GEN_xhat
		(
			.clk(clk), .rst(rst), .enable(gen_xhat_enable),
			.output_valid(xhat_valid),
			.output_data(xhat_data),
			.output_ready(xhat_ready)
		);

	helper_axis_generator #(.DATA_WIDTH(DATA_WIDTH), .START_AT(640), .STEP(256)) GEN_xmean
		(
			.clk(clk), .rst(rst), .enable(gen_xmean_enable),
			.output_valid(xmean_valid),
			.output_data(xmean_data),
			.output_ready(xmean_ready)
		);

	helper_axis_generator #(.DATA_WIDTH(DATA_WIDTH), .START_AT(384), .STEP(512)) GEN_xhatmean
		(
			.clk(clk), .rst(rst), .enable(gen_xhatmean_enable),
			.output_valid(xhatmean_valid),
			.output_data(xhatmean_data),
			.output_ready(xhatmean_ready)
		);

	
	helper_axis_drain #(.DATA_WIDTH(ALPHA_WIDTH)) DRAIN
		(
			.clk(clk), .rst(rst), .enable(drain_alpha_enable),
			.input_valid(alpha_valid),
			.input_ready(alpha_ready),
			.input_data(alpha_data)
		);

	alpha_calc #(.DATA_WIDTH(DATA_WIDTH), .BLOCK_SIZE_LOG(BLOCK_SIZE_LOG), .ALPHA_WIDTH(ALPHA_WIDTH)) calc_alpha
		(
			.clk(clk), .rst(rst),
			.x_valid(x_valid),
			.x_ready(x_ready),
			.x_data(x_data),
			.xhat_valid(xhat_valid),
			.xhat_ready(xhat_ready),
			.xhat_data(xhat_data),
			.xmean_valid(xmean_valid),
			.xmean_ready(xmean_ready),
			.xmean_data(xmean_data),
			.xhatmean_valid(xhatmean_valid),
			.xhatmean_ready(xhatmean_ready),
			.xhatmean_data(xhatmean_data),
			.alpha_ready(alpha_ready),
			.alpha_valid(alpha_valid),
			.alpha_data(alpha_data)
		);

endmodule
