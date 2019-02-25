`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCM
// Engineer: Daniel Báscones
// 
// Create Date: 25.02.2019 09:54:00
// Design Name: 
// Module Name: test_axis_fifo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Test for AXIS_FIFO.vhd
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module test_axis_fifo;
	
parameter USE_MINIFIFO=1;
parameter PERIOD=10;
parameter DATA_WIDTH=32;
parameter FIFO_DEPTH=16;
	
	
	//controlled inputs
	reg clk, rst;
	reg input_valid;
	reg output_ready;
	reg[DATA_WIDTH-1:0] input_data;
	//wired outputs
	wire input_ready;
	wire output_valid;
	wire[DATA_WIDTH-1:0] output_data;
	//DUT (auto connect)
	
	if (USE_MINIFIFO == 1) begin: create_minififo
		AXIS_LATCHED_CONNECTION #(.DATA_WIDTH(DATA_WIDTH)) DUT (
			.clk(clk),
			.rst(rst),
			.input_valid(input_valid),
			.input_ready(input_ready),
			.input_data(input_data),
			.output_valid(output_valid),
			.output_ready(output_ready),
			.output_data(output_data)
		);
	end
	
	if (USE_MINIFIFO == 0) begin: create_full_fifo
		AXIS_FIFO #(.DATA_WIDTH(DATA_WIDTH), .FIFO_DEPTH(FIFO_DEPTH)) DUT (
			.clk(clk),
			.rst(rst),
			.input_valid(input_valid),
			.input_ready(input_ready),
			.input_data(input_data),
			.output_valid(output_valid),
			.output_ready(output_ready),
			.output_data(output_data)
		);
	end;
	
	always #(PERIOD/2) clk = ~clk;
	always begin
		#(PERIOD/2);
		input_data = input_data + 1;
		#(PERIOD/2);
	end
	
	initial begin
		clk = 1;
		rst = 1;
		input_valid = 0;
		input_data = 0;
		output_ready = 0;
		
		#(PERIOD)
		#(PERIOD/2);
		rst = 0;
		
		#PERIOD;
		input_valid = 1;
		
		#(FIFO_DEPTH*PERIOD*2);
		output_ready = 1;
		
		#(FIFO_DEPTH*PERIOD);
		input_valid = 0;
		
		#(FIFO_DEPTH*PERIOD*2);
		
		$finish;
	end

    
endmodule