----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11.02.2019 10:02:47
-- Design Name: 
-- Module Name: nthbandmodule - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.data_types.all;
use work.functions.all;

entity ERROR_CALC is
	Generic (
		DATA_WIDTH: positive := 16;
		BLOCK_SIZE_LOG: positive := 8;
		ACCUMULATOR_WINDOW: positive := 32;
		UPSHIFT: positive := 1;
		DOWNSHIFT: positive := 1;
		THRESHOLD: std_logic_vector := "100000000000000" --has to be std_logic_vector because its value might be greater than 2^32-1: the max of positive
	);
	Port (
		clk, rst		: in  std_logic;
		--original samples (all included)
		x_valid			: in  std_logic;
		x_ready			: out std_logic;
		x_data			: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		x_last_s		: in  std_logic;
		x_last_b		: in  std_logic;
		x_last_i		: in  std_logic;
		--all predictions (from both the first layer predictor and the second layer)
		--prediction for first sample included (will be inserted by the first layer predictor)
		xtilde_in_ready	: out std_logic;
		xtilde_in_valid	: in  std_logic;
		xtilde_in_data 	: in  std_logic_vector(DATA_WIDTH + 2 downto 0);
		xtilde_in_last_s: in  std_logic;
		--output distortion, mapped error, parameter kj and prediction
		--mapped error is going to be coded with parameter kj later
		--the distortion might be used to skip coding of the current block
		--predictions will be sent as xhat if the block is skipped
		merr_ready		: in  std_logic;
		merr_valid		: out std_logic;
		merr_data		: out std_logic_vector(DATA_WIDTH + 2 downto 0);
		merr_last_s		: out std_logic;
		merr_last_b		: out std_logic;
		merr_last_i		: out std_logic;
		kj_ready		: in  std_logic;
		kj_valid		: out std_logic;
		kj_data			: out std_logic_vector(bits(bits(ACCUMULATOR_WINDOW-1)+DATA_WIDTH) - 1 downto 0);
		xtilde_out_valid: out std_logic;
		xtilde_out_ready: in  std_logic;
		xtilde_out_data	: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		xtilde_out_last_s: out std_logic;
		xhatout_valid   : out std_logic;
		xhatout_ready	: in  std_logic;
		xhatout_data	: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		xhatout_last_s	: out std_logic;
		xhatout_last_b	: out std_logic;
		d_flag_valid	: out std_logic;
		d_flag_ready	: in  std_logic;
		d_flag_data 	: out std_logic
	);
end ERROR_CALC;

architecture Behavioral of ERROR_CALC is
	constant PREDICTION_WIDTH: integer := DATA_WIDTH + 3;
	constant ACC_WINDOW_BITS: integer := bits(ACCUMULATOR_WINDOW);
	constant ACC_WINDOW_M1_BITS: integer := bits(ACCUMULATOR_WINDOW-1);
	
	--
	signal x_last_ibs: std_logic_vector(2 downto 0);
	
	--prediction splitter into 3: 
		--(0) first one goes to output prediction (in case we skip coding)
		--(1) second one goes on to error calculation
		--(2) third one is saved for calculating xhatout
	signal prediction_splitter_valid_0, prediction_splitter_valid_1, prediction_splitter_valid_2: std_logic;
	signal prediction_splitter_ready_0, prediction_splitter_ready_1, prediction_splitter_ready_2: std_logic;
	signal prediction_splitter_data_0, prediction_splitter_data_1, prediction_splitter_data_2: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	signal prediction_splitter_last_0, prediction_splitter_last_2: std_logic;
		
	
	--clamp for x tilde
	signal xtilde_clamped_raw_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	
	--fifo for xhatout calculation later (after quantizing/dequantizing the error)
	constant XHATOUT_CALC_FIFO_DEPTH: positive := 8; --as much as the quantizing and dequantizing take
	signal xhatout_calc_fifo_ready, xhatout_calc_fifo_valid: std_logic;
	signal xhatout_calc_fifo_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	
	--unquant error calculation
	signal unquant_error_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	signal unquant_error_valid, unquant_error_ready: std_logic;
	signal unquant_error_last_ibs: std_logic_vector(2 downto 0);
	
	--error splitter signals
	signal error_splitter_valid_0, error_splitter_valid_1, error_splitter_ready_0, error_splitter_ready_1: std_logic;
	signal error_splitter_data_0, error_splitter_data_1: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	signal error_splitter_last_ibs_0, error_splitter_last_ibs_1: std_logic_vector(2 downto 0);
	
	--distortion multiplier
	signal distortion_mult_data: std_logic_vector(PREDICTION_WIDTH*2-1 downto 0);
	signal distortion_mult_valid, distortion_mult_ready, distortion_mult_last: std_logic;
	
	--distortion stuff
	signal distortion_valid, distortion_ready: std_logic;
	signal distortion_data: std_logic_vector((DATA_WIDTH + 3)*2 + BLOCK_SIZE_LOG - 1 downto 0);
	
	--distortion flag stuff
	signal d_flag_thres: std_logic_vector((DATA_WIDTH + 3)*2 + BLOCK_SIZE_LOG - 1 downto 0); 
	
	--error quantizer
	signal error_quant_ready, error_quant_valid: std_logic;
	signal error_quant_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	signal error_quant_last_ibs: std_logic_vector(2 downto 0);
	
	--error quantizer splitter
	signal error_quant_splitter_valid_0, error_quant_splitter_ready_0, error_quant_splitter_valid_1, error_quant_splitter_ready_1: std_logic;
	signal error_quant_splitter_last_ibs_0, error_quant_splitter_last_ibs_1: std_logic_vector(2 downto 0);
	alias  error_quant_splitter_last_s_0 : std_logic is error_quant_splitter_last_ibs_0(0);
	alias  error_quant_splitter_last_b_0 : std_logic is error_quant_splitter_last_ibs_0(1);
	alias  error_quant_splitter_last_i_0 : std_logic is error_quant_splitter_last_ibs_0(2);
	alias  error_quant_splitter_last_s_1 : std_logic is error_quant_splitter_last_ibs_1(0);
	alias  error_quant_splitter_last_b_1 : std_logic is error_quant_splitter_last_ibs_1(1);
	alias  error_quant_splitter_last_i_1 : std_logic is error_quant_splitter_last_ibs_1(2);
	signal error_quant_splitter_data_0, error_quant_splitter_data_1: std_logic_vector(PREDICTION_WIDTH - 1 downto 0); 
	
	--error dequantizer
	signal error_unquant_ready, error_unquant_valid: std_logic;
	signal error_unquant_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	signal error_unquant_last_s: std_logic;
	signal error_unquant_last_b_stdlv: std_logic_vector(0 downto 0);
	
	--error dequantizer splitter
	signal error_unquant_splitter_valid_0, error_unquant_splitter_ready_0, error_unquant_splitter_valid_1, error_unquant_splitter_ready_1: std_logic; 
	signal error_unquant_splitter_last_s_0, error_unquant_splitter_last_s_1: std_logic;
	signal error_unquant_splitter_data_0, error_unquant_splitter_data_1: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	signal error_unquant_splitter_last_b_stdlv_0: std_logic_vector(0 downto 0);
	
	--xhatout raw calc
	signal xhatout_raw_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	signal xhatout_raw_valid, xhatout_raw_ready: std_logic;
	signal xhatout_raw_last_s: std_logic;
	signal xhatout_raw_last_b_stdlv: std_logic_vector(0 downto 0);
	
	--xhatout clamp
	signal xhatout_raw_data_out: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	signal xhatout_last_b_stdlv: std_logic_vector(0 downto 0);
	
	--error mapper
	signal mapped_error_data_raw:	std_logic_vector (PREDICTION_WIDTH downto 0);
	signal merr_last_ibs: std_logic_vector(2 downto 0);
	
	--error sliding accumulator latch
	signal error_acc_in_data, error_acc_in_latch_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	signal error_acc_in_valid, error_acc_in_ready, error_acc_in_last_s: std_logic;
	
	--error sliding acc 
	signal error_acc_cnt: std_logic_vector(ACC_WINDOW_BITS - 1 downto 0);
	signal error_acc_data: std_logic_vector(PREDICTION_WIDTH + ACC_WINDOW_M1_BITS - 1 downto 0);
	signal error_acc_valid, error_acc_ready: std_logic;
					
begin

	
	

	--------------
	--PREDICTION--
	--------------

	--prediction splitter (to output queue and to error calculation)
	prediction_splitter: entity work.AXIS_SPLITTER_3
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			--to input axi port
			input_valid => xtilde_in_valid,
			input_data  => xtilde_in_data,
			input_ready => xtilde_in_ready,
			input_last	=> xtilde_in_last_s,
			--to output axi ports
			output_0_valid => prediction_splitter_valid_0,
			output_0_data  => prediction_splitter_data_0,
			output_0_ready => prediction_splitter_ready_0,
			output_0_last  => prediction_splitter_last_0,
			output_1_valid => prediction_splitter_valid_1,
			output_1_data  => prediction_splitter_data_1,
			output_1_ready => prediction_splitter_ready_1,
			output_1_last  => open,
			output_2_valid => prediction_splitter_valid_2,
			output_2_data  => prediction_splitter_data_2,
			output_2_ready => prediction_splitter_ready_2,
			output_2_last  => prediction_splitter_last_2
		);
	
	clamp_xtildeout: entity work.AXIS_INTERVAL_CLAMPER
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH,
			IS_SIGNED => true,
			LOWER_LIMIT => 0,
			UPPER_LIMIT => 2**DATA_WIDTH - 1
		)
		Port map (
			clk => clk, rst => rst,
			input_data   => prediction_splitter_data_0,
			input_valid  => prediction_splitter_valid_0,
			input_ready  => prediction_splitter_ready_0,
			input_last   => prediction_splitter_last_0,
			output_data  => xtilde_clamped_raw_data,
			output_valid => xtilde_out_valid,
			output_ready => xtilde_out_ready,
			output_last  => xtilde_out_last_s
		);
	xtilde_out_data <= xtilde_clamped_raw_data(DATA_WIDTH - 1 downto 0);
	
	--fifo to xhatout calculation
	xhatout_calc_fifo: entity work.AXIS_FIFO
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH,
			FIFO_DEPTH => XHATOUT_CALC_FIFO_DEPTH
		)
		Port map (
			clk => clk, rst => rst,
			input_valid  => prediction_splitter_valid_1,
			input_ready  => prediction_splitter_ready_1,
			input_data   => prediction_splitter_data_1,
			output_ready => xhatout_calc_fifo_ready,
			output_valid => xhatout_calc_fifo_valid,
			output_data  => xhatout_calc_fifo_data
		);
	
	
	
	--error calculation
	x_last_ibs <= x_last_i & x_last_b & x_last_s;
	unquant_error_calc: entity work.AXIS_ARITHMETIC_OP
		Generic Map (
			DATA_WIDTH_0 	  => DATA_WIDTH,
			DATA_WIDTH_1 	  => PREDICTION_WIDTH,
			OUTPUT_DATA_WIDTH => PREDICTION_WIDTH,
			IS_ADD => false,
			SIGN_EXTEND_0     => false,
			SIGN_EXTEND_1	  => true,
			SIGNED_OP		  => true,
			USER_WIDTH		  => 3,
			USER_POLICY 	  => PASS_ZERO
		)	
		Port Map (
			clk => clk, rst => rst,
			input_0_data  => x_data,
			input_0_valid => x_valid,
			input_0_ready => x_ready,
			input_0_user  => x_last_ibs,
			input_1_data  => prediction_splitter_data_2,
			input_1_valid => prediction_splitter_valid_2,
			input_1_ready => prediction_splitter_ready_2,
			output_data   => unquant_error_data,
			output_valid  => unquant_error_valid,
			output_ready  => unquant_error_ready,
			output_user   => unquant_error_last_ibs
		);
		
	--error splitter (1 for distortion calculation and 1 for continuing with calcs
	error_splitter: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH,
			USER_WIDTH => 3
		)
		Port map (
			clk => clk, rst => rst,
			input_valid => unquant_error_valid,
			input_ready => unquant_error_ready,
			input_data  => unquant_error_data,
			input_user  => unquant_error_last_ibs,
			output_0_valid => error_splitter_valid_0,
			output_0_data  => error_splitter_data_0,
			output_0_ready => error_splitter_ready_0,
			output_0_user  => error_splitter_last_ibs_0,
			output_1_valid => error_splitter_valid_1,
			output_1_data  => error_splitter_data_1,
			output_1_ready => error_splitter_ready_1,
			output_1_user  => error_splitter_last_ibs_1
		);
		
	--distortion multiplier
	distortion_multiplier: entity work.AXIS_MULTIPLIER
		Generic map (
			DATA_WIDTH_0 => PREDICTION_WIDTH,
			DATA_WIDTH_1 => PREDICTION_WIDTH,
			OUTPUT_WIDTH => PREDICTION_WIDTH*2,
			SIGN_EXTEND_0=> true,
			SIGN_EXTEND_1=> true,
			SIGNED_OP	 => true,
			LAST_POLICY  => PASS_ZERO
		)
		Port map (
			clk => clk, rst => rst,
			input_0_data	=> error_splitter_data_0,
			input_0_valid	=> error_splitter_valid_0,
			input_0_ready	=> error_splitter_ready_0,
			input_0_last    => error_splitter_last_ibs_0(0),
			input_1_data	=> error_splitter_data_0,
			input_1_valid	=> error_splitter_valid_0,
			input_1_ready	=> open, --no need for this ready since i already have it from port 0 (they sync)
			input_1_last    => '0',  --comes from port zero
			output_data 	=> distortion_mult_data,
			output_valid 	=> distortion_mult_valid,
			output_ready 	=> distortion_mult_ready,
			output_last     => distortion_mult_last
		);
		
		

	--distortion accumulator
	distortion_accumulator: entity work.AXIS_ACCUMULATOR
		Generic map (
			DATA_WIDTH 		=> PREDICTION_WIDTH*2,
			COUNT_LOG		=> BLOCK_SIZE_LOG,
			IS_SIGNED 		=> true
		)
		Port map (
			clk => clk, rst => rst,
			input_data 	=> distortion_mult_data,
			input_valid => distortion_mult_valid,
			input_ready => distortion_mult_ready,
			input_last  => distortion_mult_last,
			output_data => distortion_data,
			output_valid=> distortion_valid,
			output_ready=> distortion_ready
		);
		
	d_flag_thres <= std_logic_vector(resize(unsigned(THRESHOLD),(DATA_WIDTH + 3)*2 + BLOCK_SIZE_LOG));
	d_threshold_comparator: entity work.AXIS_COMPARATOR
		Generic map (
			DATA_WIDTH => (DATA_WIDTH + 3)*2 + BLOCK_SIZE_LOG,
			IS_SIGNED => false,
			IS_EQUAL => false,
			IS_GREATER => true,
			SYNCHRONIZE => false
		)
		Port map (
			clk => clk, rst => rst,
			input_0_data  => distortion_data,
			input_0_valid => distortion_valid,
			input_0_ready => distortion_ready,
			input_1_data  => d_flag_thres,
			input_1_valid => '1',
			input_1_ready => open,
			output_data	  => d_flag_data,
			output_valid  => d_flag_valid,
			output_ready  => d_flag_ready
		);
	--1 on flag means it is greater than the threshold
		
	--error quant/dequant
	error_quantizer: entity work.BINARY_QUANTIZER
		Generic map (
			UPSHIFT => UPSHIFT,
			DOWNSHIFT_MINUS_1 => DOWNSHIFT - 1,
			DATA_WIDTH => PREDICTION_WIDTH,
			USER_WIDTH => 3
		)
		Port map (
			clk => clk, rst => rst,
			input_ready => error_splitter_ready_1,
			input_valid => error_splitter_valid_1,
			input_data  => error_splitter_data_1,
			input_user  => error_splitter_last_ibs_1,
			output_ready => error_quant_ready,
			output_valid => error_quant_valid,
			output_data  => error_quant_data,
			output_user  => error_quant_last_ibs
		);
		
	--splitter for quantized error 
		--one goes to error mapping
		--one goes to dequantizing and decoding for next layer
	quantized_error_splitter: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH,
			USER_WIDTH => 3
		)
		Port map (
			clk => clk, rst => rst,
			input_valid => error_quant_valid,
			input_ready => error_quant_ready,
			input_data  => error_quant_data,
			input_user  => error_quant_last_ibs,
			output_0_valid => error_quant_splitter_valid_0,
			output_0_data  => error_quant_splitter_data_0,
			output_0_ready => error_quant_splitter_ready_0,
			output_0_user  => error_quant_splitter_last_ibs_0,
			output_1_valid => error_quant_splitter_valid_1,
			output_1_data  => error_quant_splitter_data_1,
			output_1_ready => error_quant_splitter_ready_1,
			output_1_user  => error_quant_splitter_last_ibs_1
		);
	
	--error dequantizer
	error_dequantizer: entity work.BINARY_DEQUANTIZER
		Generic map (
			UPSHIFT => UPSHIFT,
			DOWNSHIFT_MINUS_1 => DOWNSHIFT - 1,
			DATA_WIDTH => PREDICTION_WIDTH,
			USER_WIDTH => 1
		)
		Port map (
			clk => clk, rst => rst,
			input_ready => error_quant_splitter_ready_0,
			input_valid => error_quant_splitter_valid_0,
			input_data  => error_quant_splitter_data_0,
			input_last  => error_quant_splitter_last_s_0,
			input_user  => error_quant_splitter_last_ibs_0(1 downto 1),
			output_ready => error_unquant_ready,
			output_valid => error_unquant_valid,
			output_data  => error_unquant_data,
			output_last  => error_unquant_last_s,
			output_user  => error_unquant_last_b_stdlv
		);
		
	--splitter for error dequantizer
		--one going to the decoded block calculation
		--other one going to the sliding accumulator
	unquantized_error_splitter: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			input_valid => error_unquant_valid,
			input_ready => error_unquant_ready,
			input_data  => error_unquant_data,
			input_last  => error_unquant_last_s,
			input_user  => error_unquant_last_b_stdlv,
			output_0_valid => error_unquant_splitter_valid_0,
			output_0_data  => error_unquant_splitter_data_0,
			output_0_ready => error_unquant_splitter_ready_0,
			output_0_last  => error_unquant_splitter_last_s_0,
			output_0_user  => error_unquant_splitter_last_b_stdlv_0,
			output_1_valid => error_unquant_splitter_valid_1,
			output_1_data  => error_unquant_splitter_data_1,
			output_1_ready => error_unquant_splitter_ready_1,
			output_1_last  => error_unquant_splitter_last_s_1
		);
		
	--decoded block out for next layer calculation
	xhatout_calc: entity work.AXIS_ARITHMETIC_OP
		Generic map (
			DATA_WIDTH_0 => PREDICTION_WIDTH,
			DATA_WIDTH_1 => PREDICTION_WIDTH,
			OUTPUT_DATA_WIDTH => PREDICTION_WIDTH,
			IS_ADD => true,
			SIGN_EXTEND_0 => true,
			SIGN_EXTEND_1 => true,
			SIGNED_OP	  => true,
			LAST_POLICY   => PASS_ONE,
			USER_WIDTH    => 1,
			USER_POLICY   => PASS_ONE
		)
		Port map(
			clk => clk, rst => rst,
			input_0_data  => xhatout_calc_fifo_data,
			input_0_valid => xhatout_calc_fifo_valid,
			input_0_ready => xhatout_calc_fifo_ready,
			input_0_last  => '0',
			input_1_data  => error_unquant_splitter_data_0,
			input_1_valid => error_unquant_splitter_valid_0,
			input_1_ready => error_unquant_splitter_ready_0,
			input_1_last  => error_unquant_splitter_last_s_0,
			input_1_user  => error_unquant_splitter_last_b_stdlv_0,
			output_data   => xhatout_raw_data,
			output_valid  => xhatout_raw_valid,
			output_ready  => xhatout_raw_ready,
			output_last   => xhatout_raw_last_s,
			output_user   => xhatout_raw_last_b_stdlv
		);
		
	--clamp decoded block to real interval
	clamp_xhatout: entity work.AXIS_INTERVAL_CLAMPER
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH,
			IS_SIGNED => true,
			LOWER_LIMIT => 0,
			UPPER_LIMIT => 2**DATA_WIDTH - 1
		)
		Port map (
			clk => clk, rst => rst,
			input_data  => xhatout_raw_data,
			input_valid => xhatout_raw_valid,
			input_ready => xhatout_raw_ready,
			input_last  => xhatout_raw_last_s,
			input_user  => xhatout_raw_last_b_stdlv,
			output_data => xhatout_raw_data_out,
			output_valid => xhatout_valid,
			output_ready => xhatout_ready,
			output_last  => xhatout_last_s,
			output_user  => xhatout_last_b_stdlv
		);
	xhatout_data <= xhatout_raw_data_out(DATA_WIDTH - 1 downto 0);
	xhatout_last_b <= xhatout_last_b_stdlv(0);
		
	--error mapper
	error_mapper: entity work.ERROR_MAPPER
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH,
			USER_WIDTH => 3
		)
		Port map (
			clk => clk, rst => rst,
			input_ready => error_quant_splitter_ready_1,
			input_valid => error_quant_splitter_valid_1,
			input_data  => error_quant_splitter_data_1,
			input_user  => error_quant_splitter_last_ibs_1,
			output_ready => merr_ready,
			output_valid => merr_valid,
			output_data  => mapped_error_data_raw,
			output_user  => merr_last_ibs
		);
	--no need for last bit since that can only be set when the error value is -2^n and that is not possible here
	merr_data <= mapped_error_data_raw(PREDICTION_WIDTH - 1 downto 0); 
	merr_last_i <= merr_last_ibs(2);
	merr_last_b <= merr_last_ibs(1);
	merr_last_s <= merr_last_ibs(0);
	
	
	error_acc_in_latch_data <= error_unquant_splitter_data_1 when error_unquant_splitter_data_1(error_unquant_splitter_data_1'high) = '0' else 
		std_logic_vector(-signed(error_unquant_splitter_data_1));
		
	--need one latch here
	error_acc_input_data_latch: entity work.AXIS_DATA_LATCH
		generic map (
			DATA_WIDTH => PREDICTION_WIDTH
		)
		port map (
			clk => clk, rst => rst,
			input_valid => error_unquant_splitter_valid_1,
			input_ready => error_unquant_splitter_ready_1,
			input_data  => error_acc_in_latch_data,
			input_last  => error_unquant_splitter_last_s_1,
			output_valid=> error_acc_in_valid,
			output_ready=> error_acc_in_ready,
			output_data => error_acc_in_data,
			output_last => error_acc_in_last_s
		);
		
	--sliding accumulator for kj finding
	error_acc: entity work.SLIDING_ACCUMULATOR
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH,
			BLOCK_SIZE_LOG => BLOCK_SIZE_LOG,
			ACCUMULATOR_WINDOW => ACCUMULATOR_WINDOW
		)
		Port map (
			clk => clk, rst => rst,
			input_data  => error_acc_in_data, 
			input_valid => error_acc_in_valid,
			input_ready => error_acc_in_ready,
			input_last  => error_acc_in_last_s,
			output_cnt  => error_acc_cnt, 
			output_data => error_acc_data,
			output_valid => error_acc_valid,
			output_ready => error_acc_ready
		);
		
	--kj calculation
	kj_calculator: entity work.KJCALC_AXI
		Generic map (
			EXTRA_RJ_WIDTH => ACC_WINDOW_M1_BITS,
			J_WIDTH 	   => ACC_WINDOW_BITS,
			DATA_WIDTH 	   => PREDICTION_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			input_rj => error_acc_data,
			input_j  => error_acc_cnt,
			input_valid => error_acc_valid,
			input_ready => error_acc_ready,
			output_kj => kj_data,
			output_valid => kj_valid,
			output_ready => kj_ready
		);
		

end Behavioral;
