`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UCM
// Engineer: Daniel Báscones
// 
// Create Date: 25.02.2019 12:00:40
// Design Name: 
// Module Name: helper_axis_checker
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


module helper_axis_checker (
	clk, rst, enable,
	input_valid, input_data, input_ready
);
	parameter DATA_WIDTH=10;
	parameter FILE_NAME = null;
	parameter SKIP = 0;

	input					clk, rst, enable;
	input 					input_valid;
	input [DATA_WIDTH-1:0]	input_data;
	output					input_ready;

	//reader from file
	wire ref_valid, ref_ready;
	wire [DATA_WIDTH - 1:0] ref_data;

	helper_axis_reader #(.DATA_WIDTH(DATA_WIDTH), .FILE_NAME(FILE_NAME), .SKIP(SKIP)) reference_reader
		(
			.clk         (clk),
			.rst         (rst),
			.enable      (enable),
			.output_valid(ref_valid),
			.output_data (ref_data),
			.output_ready(ref_ready)
		);

	wire sync_valid;
	reg sync_ready;
	wire [DATA_WIDTH-1:0] sync_data_0, sync_data_1;

	//sync file stream with local generated stream
	axis_synchronizer_2 #(.DATA_WIDTH_0(DATA_WIDTH), .DATA_WIDTH_1(DATA_WIDTH), .LATCH(0)) sync_ref_with_real
		(
			.clk(clk),
			.rst(rst),
			.input_0_valid(input_valid),
			.input_0_ready(input_ready),
			.input_0_data (input_data),
			.input_1_valid(ref_valid),
			.input_1_ready(ref_ready),
			.input_1_data (ref_data),
			.output_valid(sync_valid),
			.output_ready(sync_ready),
			.output_data_0(sync_data_0),
			.output_data_1(sync_data_1)
		);

	initial begin
		sync_ready = 1;
	end

	always @(posedge clk) begin
		if (sync_valid == 1 && sync_ready == 1) begin
			if (sync_data_0 != sync_data_1) begin
				$info("Displaying info");
				$display("Received value 0x%h and was expecting 0x%h", sync_data_0, sync_data_1);
			end
		end
	end
	
endmodule

