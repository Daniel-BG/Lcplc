`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCM
// Engineer: Daniel Báscones
// 
// Create Date: 25.02.2019 12:08:33
// Design Name: 
// Module Name: helper_axis_drain
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Helper to create an AXIS bus drain for data to be consumed in tests
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module helper_axis_drain(
	clk, rst, enable,
	input_valid, input_data, input_ready
);
	parameter DATA_WIDTH=10;
	
	input					clk, rst;
	input 					enable;
	input 					input_valid;
	input [DATA_WIDTH-1:0]	input_data;
	output					input_ready;
	
	integer data_consumed;

	assign input_ready = enable;

	initial begin
		data_consumed = 0;
	end
	
	always @(posedge clk) begin
		if (input_ready == 1 && input_valid == 1) begin
			data_consumed = data_consumed + 1;
		end
	end

endmodule