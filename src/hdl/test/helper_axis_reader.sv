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
// Description: Simple data reader for AXIS bus (taking values from file)
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module helper_axis_reader(
	clk, rst, enable,
	output_valid, output_data, output_ready
);
	parameter DATA_WIDTH=10;
	parameter FILE_NAME = null;
	parameter SKIP = 0;

	//file stuff
	int fd; // file descriptor
	int status; //status for file reads
	reg [DATA_WIDTH-1:0] value; //values read from file go here
	////
	
	input					clk, rst, enable;
	output 					output_valid;
	output [DATA_WIDTH-1:0]	output_data;
	input					output_ready;

	reg output_valid_pre;

	assign output_data  = value;
	assign output_valid = output_valid_pre & enable;
	

	always @(posedge clk) begin
		if (rst == 1) begin
			$fclose(fd);
			fd = $fopen(FILE_NAME, "r");
			//SKIP+1 so that value loads the first value already
			for (int i = 0; i < SKIP + 1; i++) begin
				status = $fscanf(fd, "%d", value);
				if (status != 1)
					$error("Error when reading file (skipping values)");
			end
			output_valid_pre = 1;
		end else if (output_valid_pre == 1 && output_ready == 1 && enable == 1) begin
			if ($feof(fd)) begin
				output_valid_pre = 0;
				$info("End of file reached! %s", FILE_NAME);
			end else begin
				status = $fscanf(fd, "%d", value);
				if (status != 1) begin
					if ($feof(fd)) begin 
						$info("End of file reached! %s", FILE_NAME);
					end else begin
						$error("Unknown when reading file: %s", FILE_NAME);
					end 
					output_valid_pre = 0;
				end 
			end
		end
	end

endmodule

