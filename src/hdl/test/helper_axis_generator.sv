`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCM
// Engineer: Daniel Báscones
// 
// Create Date: 25.02.2019 12:00:40
// Design Name: 
// Module Name: helper_axis_generator
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Simple data generator for AXIS bus (used in testing)
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module helper_axis_generator(
	clk, rst, enable,
	output_valid, output_data, output_ready
);
	parameter DATA_WIDTH=10;
	parameter RANDOM=0;
	parameter START_AT=0;
	parameter STEP=1;
	parameter END_AT=2**DATA_WIDTH-1;
	
	input					clk, rst;
	input 					enable;
	output 					output_valid;
	output [DATA_WIDTH-1:0]	output_data;
	input					output_ready;
	
	reg [DATA_WIDTH-1:0]	output_data_reg;

	assign output_valid = enable;
	assign output_data  = output_data_reg;

	initial begin
		output_data_reg = START_AT;
	end
	
	always @(posedge clk) begin
		if (output_ready == 1 && output_valid == 1) begin
			if (RANDOM == 0) begin
				if (output_data_reg == END_AT) begin
					output_data_reg = START_AT;
				end else begin
					output_data_reg = output_data_reg + STEP;
				end
			end else begin
				output_data_reg = $random();
			end
		end
	end

endmodule
