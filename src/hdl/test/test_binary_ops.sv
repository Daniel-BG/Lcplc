`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.02.2019 09:21:34
// Design Name: 
// Module Name: test_binary_ops
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Test arithmetic and logical operations performed over two AXIS
//		buses yielding a new AXIS bus of results
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module test_binary_ops;
	parameter DATA_WIDTH=16;
	parameter PERIOD=10;
	/////module configuration
	parameter DATA_WIDTH_0=DATA_WIDTH;
	parameter DATA_WIDTH_1=DATA_WIDTH;
	//parameter OUT_WIDTH=DATA_WIDTH+1; //ADDSUB 
	//parameter OUT_WIDTH=DATA_WIDTH*2; //MULT
	parameter OUT_WIDTH=1; //COMP
	parameter SIGN_EXTEND_0=1;
	parameter SIGN_EXTEND_1=1;
	parameter SIGNED_OP=1;
	parameter EQUAL_OP=0;
	parameter GREATER_OP=0;
	reg signed [DATA_WIDTH-1:0] op_0_data;
	//reg        [DATA_WIDTH-1:0] op_0_data;
	reg signed [DATA_WIDTH-1:0] op_1_data;
	//reg        [DATA_WIDTH-1:0] op_1_data;
	reg signed  [OUT_WIDTH-1:0] res_data;
	//reg         [OUT_WIDTH-1:0] res_data;
	//select one of the next few
	parameter USE_MULT=0;
	parameter USE_ARITH=0;
	parameter USE_COMP=1;
	parameter IS_ADD=1;
	/////////////////////////
	
	
	reg clk, rst;
	
	reg generator_0_enable;
	wire gen_0_valid, gen_0_ready;
	wire[DATA_WIDTH-1:0] gen_0_data;
	
	reg generator_1_enable;
	wire gen_1_valid, gen_1_ready;
	wire[DATA_WIDTH-1:0] gen_1_data;
	
	wire op_valid, op_ready;
	wire[OUT_WIDTH-1:0] op_data;
	
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
		drain_enable = 1;
		#(PERIOD*5)
		drain_enable = 0;
		#(PERIOD*5)
		drain_enable = 1;
	end
	
	always begin
		#(PERIOD*2)
		generator_0_enable = ~generator_0_enable;
	end
	
	always begin
		#(PERIOD*3)
		generator_1_enable = ~generator_1_enable;
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
	
	if (USE_MULT == 1) begin: multiplier_instance
		AXIS_MULTIPLIER #(
			.DATA_WIDTH_0(DATA_WIDTH_0),
			.DATA_WIDTH_1(DATA_WIDTH_1),
			.OUTPUT_DATA_WIDTH(OUT_WIDTH),
			.SIGN_EXTEND_0(SIGN_EXTEND_0),
			.SIGN_EXTEND_1(SIGN_EXTEND_1),
			.SIGNED_OP(SIGNED_OP)
			) 
			MULTIPLIER
			(
				.clk(clk), .rst(rst),
				.input_0_valid(gen_0_valid),
				.input_0_data(gen_0_data),
				.input_0_ready(gen_0_ready),
				.input_1_valid(gen_1_valid),
				.input_1_data(gen_1_data),
				.input_1_ready(gen_1_ready),
				.output_valid(op_valid),
				.output_data(op_data),
				.output_ready(op_ready)
			);
	end
		
	if (USE_ARITH == 1) begin: arith_instance
		AXIS_ARITHMETIC_OP #(
				.DATA_WIDTH_0(DATA_WIDTH_0),
				.DATA_WIDTH_1(DATA_WIDTH_1),
				.OUTPUT_DATA_WIDTH(OUT_WIDTH),
				.IS_ADD(IS_ADD),
				.SIGN_EXTEND_0(SIGN_EXTEND_0),
				.SIGN_EXTEND_1(SIGN_EXTEND_1),
				.SIGNED_OP(SIGNED_OP)
			)
			ADDER
			(
				.clk(clk), .rst(rst),
				.input_0_valid(gen_0_valid),
				.input_0_data(gen_0_data),
				.input_0_ready(gen_0_ready),
				.input_1_valid(gen_1_valid),
				.input_1_data(gen_1_data),
				.input_1_ready(gen_1_ready),
				.output_valid(op_valid),
				.output_data(op_data),
				.output_ready(op_ready)
			);
	end
	
	if (USE_COMP == 1) begin: comp_instance
		AXIS_COMPARATOR #(
				.DATA_WIDTH(DATA_WIDTH_0),
				.IS_EQUAL(EQUAL_OP),
				.IS_GREATER(GREATER_OP),
				.IS_SIGNED(SIGNED_OP)
			)
			COMPARATOR
			(
				.clk(clk), .rst(rst),
				.input_0_valid(gen_0_valid),
				.input_0_data(gen_0_data),
				.input_0_ready(gen_0_ready),
				.input_1_valid(gen_1_valid),
				.input_1_data(gen_1_data),
				.input_1_ready(gen_1_ready),
				.output_valid(op_valid),
				.output_data(op_data),
				.output_ready(op_ready)
			);
	end

	
	helper_axis_drain #(.DATA_WIDTH(OUT_WIDTH)) DRAIN
		(
			.clk(clk), .rst(rst), .enable(drain_enable),
			.input_valid(op_valid),
			.input_ready(op_ready),
			.input_data(op_data)
		);

	//mailboxes for input and output verification
	mailbox m_box_in_0;
	mailbox m_box_in_1;
	mailbox m_box_out;
	initial begin
		m_box_in_0 = new();
		m_box_in_1 = new();
		m_box_out  = new();
	end

	//mailbox fill
	always @(posedge clk) begin
		if (gen_0_valid == 1 && gen_0_ready == 1) begin
			m_box_in_0.put(gen_0_data);
		end
		if (gen_1_valid == 1 && gen_1_ready == 1) begin
			m_box_in_1.put(gen_1_data);
		end
		if (op_valid == 1 && op_ready == 1) begin
			m_box_out.put(op_data);
		end
	end
	
	always begin
		//get all results (block until available)
		m_box_in_0.get(op_0_data);
		m_box_in_1.get(op_1_data);
		m_box_out.get(res_data);
		//check validity of result
		if (USE_MULT == 1) begin
			assert (op_0_data * op_1_data == res_data) else $error("Not OK %b*%b=%b (expected %b)!!", op_0_data, op_1_data, res_data, op_0_data * op_1_data);
		end else if (USE_ARITH == 1) begin
			if (IS_ADD == 1) begin
				assert (op_0_data + op_1_data == res_data) else $error("Not OK %b+%b=%b (expected %b)!!", op_0_data, op_1_data, res_data, op_0_data + op_1_data);
			end else begin
				assert (op_0_data - op_1_data == res_data) else $error("Not OK %b-%b=%b (expected %b)!!", op_0_data, op_1_data, res_data, op_0_data - op_1_data);
			end 
		end else if (USE_COMP == 1) begin
			if (EQUAL_OP == 1) begin
				if (GREATER_OP == 1) begin
					assert ((op_0_data >= op_1_data) == res_data) else $error("Not OK %b*%b=%b (expected %b)!!", op_0_data, op_1_data, res_data, op_0_data * op_1_data);
				end else begin
					assert ((op_0_data == op_1_data) == res_data) else $error("Not OK %b*%b=%b (expected %b)!!", op_0_data, op_1_data, res_data, op_0_data * op_1_data);
				end
			end else begin
				if (GREATER_OP == 1) begin
					assert ((op_0_data > op_1_data) == res_data) else $error("Not OK %b*%b=%b (expected %b)!!", op_0_data, op_1_data, res_data, op_0_data * op_1_data);
				end else begin
					assert ((op_0_data != op_1_data) == res_data) else $error("Not OK %b*%b=%b (expected %b)!!", op_0_data, op_1_data, res_data, op_0_data * op_1_data);
				end
			end
		end
	end

endmodule