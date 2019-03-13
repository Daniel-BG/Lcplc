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
		x_last			: in  std_logic;
		--all predictions (from both the first layer predictor and the second layer)
		--prediction for first sample included (will be inserted by the first layer predictor)
		prediction_ready: out std_logic;
		prediction_valid: in  std_logic;
		prediction_data : in  std_logic_vector(DATA_WIDTH + 2 downto 0);
		prediction_last : in  std_logic;
		--output distortion, mapped error, parameter kj and prediction
		--mapped error is going to be coded with parameter kj later
		--the distortion might be used to skip coding of the current block
		--predictions will be sent as xhat if the block is skipped
		merr_ready		: in  std_logic;
		merr_valid		: out std_logic;
		merr_data		: out std_logic_vector(DATA_WIDTH + 2 downto 0);
		merr_last		: out std_logic;
		kj_ready		: in  std_logic;
		kj_valid		: out std_logic;
		kj_data			: out std_logic_vector(bits(bits(ACCUMULATOR_WINDOW-1)+DATA_WIDTH) - 1 downto 0);
		xtilde_valid	: out std_logic;
		xtilde_ready	: in  std_logic;
		xtilde_data		: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		xtilde_last		: out std_logic;
		xhatout_valid   : out std_logic;
		xhatout_ready	: in  std_logic;
		xhatout_data	: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		xhatout_last	: out std_logic;
		d_flag_valid	: out std_logic;
		d_flag_ready	: in  std_logic;
		d_flag_data 	: out std_logic
	);
end ERROR_CALC;

architecture Behavioral of ERROR_CALC is
	constant PREDICTION_WIDTH: integer := DATA_WIDTH + 3;
	constant ACC_WINDOW_BITS: integer := bits(ACCUMULATOR_WINDOW);
	constant ACC_WINDOW_M1_BITS: integer := bits(ACCUMULATOR_WINDOW-1);
	
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
	constant XHATOUT_CALC_FIFO_DEPTH: positive := 16; --as much as the quantizing and dequantizing take
	signal xhatout_calc_fifo_ready, xhatout_calc_fifo_valid: std_logic;
	signal xhatout_calc_fifo_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	
	--unquant error calculation
	signal unquant_error_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	signal unquant_error_valid, unquant_error_ready, unquant_error_last: std_logic;
	
	--error splitter signals
	signal error_splitter_valid_0, error_splitter_valid_1, error_splitter_ready_0, error_splitter_ready_1: std_logic;
	signal error_splitter_last_0, error_splitter_last_1: std_logic;
	signal error_splitter_data_0, error_splitter_data_1: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	
	--distortion multiplier
	signal distortion_mult_data: std_logic_vector(PREDICTION_WIDTH*2-1 downto 0);
	signal distortion_mult_valid, distortion_mult_ready, distortion_mult_last: std_logic;
	
	--distortion stuff
	signal distortion_valid, distortion_ready: std_logic;
	signal distortion_data: std_logic_vector((DATA_WIDTH + 3)*2 + BLOCK_SIZE_LOG - 1 downto 0);
	
	--distortion flag stuff
	signal d_flag_thres: std_logic_vector((DATA_WIDTH + 3)*2 + BLOCK_SIZE_LOG - 1 downto 0); 
	
	--error quantizer
	signal error_quant_ready, error_quant_valid, error_quant_last: std_logic;
	signal error_quant_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	
	--error quantizer splitter
	signal error_quant_splitter_valid_0, error_quant_splitter_ready_0, error_quant_splitter_valid_1, error_quant_splitter_ready_1: std_logic;
	signal error_quant_splitter_last_0, error_quant_splitter_last_1: std_logic;
	signal error_quant_splitter_data_0, error_quant_splitter_data_1: std_logic_vector(PREDICTION_WIDTH - 1 downto 0); 
	
	--error dequantizer
	signal error_unquant_ready, error_unquant_valid, error_unquant_last: std_logic;
	signal error_unquant_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	
	--error dequantizer splitter
	signal error_unquant_splitter_valid_0, error_unquant_splitter_ready_0, error_unquant_splitter_valid_1, error_unquant_splitter_ready_1: std_logic; 
	signal error_unquant_splitter_last_0, error_unquant_splitter_last_1: std_logic;
	signal error_unquant_splitter_data_0, error_unquant_splitter_data_1: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	
	--xhatout raw calc
	signal xhatout_raw_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	signal xhatout_raw_valid, xhatout_raw_ready, xhatout_raw_last: std_logic;
	
	--xhatout clamp
	signal xhatout_raw_data_out: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	
	--error mapper
	signal mapped_error_data_raw:	std_logic_vector (PREDICTION_WIDTH downto 0);
	
	--error sliding accumulator
	signal error_acc_in_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
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
			input_valid => prediction_valid,
			input_data  => prediction_data,
			input_ready => prediction_ready,
			input_last	=> prediction_last,
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
			output_valid => xtilde_valid,
			output_ready => xtilde_ready,
			output_last  => xtilde_last
		);
	xtilde_data <= xtilde_clamped_raw_data(DATA_WIDTH - 1 downto 0);
	
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
	unquant_error_calc: entity work.AXIS_ARITHMETIC_OP
		Generic Map (
			DATA_WIDTH_0 	  => DATA_WIDTH,
			DATA_WIDTH_1 	  => PREDICTION_WIDTH,
			OUTPUT_DATA_WIDTH => PREDICTION_WIDTH,
			IS_ADD => false,
			SIGN_EXTEND_0     => false,
			SIGN_EXTEND_1	  => true,
			SIGNED_OP		  => true,
			LAST_POLICY		  => PASS_ONE --ignore x last since we are already using pred last so that it can be trimmed away
		)
		Port Map (
			clk => clk, rst => rst,
			input_0_data  => x_data,
			input_0_valid => x_valid,
			input_0_ready => x_ready,
			input_0_last  => x_last,
			input_1_data  => prediction_splitter_data_2,
			input_1_valid => prediction_splitter_valid_2,
			input_1_ready => prediction_splitter_ready_2,
			input_1_last  => prediction_splitter_last_2,
			output_data   => unquant_error_data,
			output_valid  => unquant_error_valid,
			output_ready  => unquant_error_ready,
			output_last   => unquant_error_last
		);
		
	--error splitter (1 for distortion calculation and 1 for continuing with calcs
	error_splitter: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			input_valid => unquant_error_valid,
			input_ready => unquant_error_ready,
			input_data  => unquant_error_data,
			input_last  => unquant_error_last,
			output_0_valid => error_splitter_valid_0,
			output_0_data  => error_splitter_data_0,
			output_0_ready => error_splitter_ready_0,
			output_0_last  => error_splitter_last_0,
			output_1_valid => error_splitter_valid_1,
			output_1_data  => error_splitter_data_1,
			output_1_ready => error_splitter_ready_1,
			output_1_last  => error_splitter_last_1
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
			input_0_last    => error_splitter_last_0,
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
			DATA_WIDTH => PREDICTION_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			input_ready => error_splitter_ready_1,
			input_valid => error_splitter_valid_1,
			input_data  => error_splitter_data_1,
			input_last  => error_splitter_last_1,
			output_ready => error_quant_ready,
			output_valid => error_quant_valid,
			output_data  => error_quant_data,
			output_last  => error_quant_last
		);
		
	--splitter for quantized error 
		--one goes to error mapping
		--one goes to dequantizing and decoding for next layer
	quantized_error_splitter: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			input_valid => error_quant_valid,
			input_ready => error_quant_ready,
			input_data  => error_quant_data,
			input_last  => error_quant_last,
			output_0_valid => error_quant_splitter_valid_0,
			output_0_data  => error_quant_splitter_data_0,
			output_0_ready => error_quant_splitter_ready_0,
			output_0_last  => error_quant_splitter_last_0,
			output_1_valid => error_quant_splitter_valid_1,
			output_1_data  => error_quant_splitter_data_1,
			output_1_ready => error_quant_splitter_ready_1,
			output_1_last  => error_quant_splitter_last_1
		);
	
	--error dequantizer
	error_dequantizer: entity work.BINARY_DEQUANTIZER
		Generic map (
			UPSHIFT => UPSHIFT,
			DOWNSHIFT_MINUS_1 => DOWNSHIFT - 1,
			DATA_WIDTH => PREDICTION_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			input_ready => error_quant_splitter_ready_0,
			input_valid => error_quant_splitter_valid_0,
			input_data  => error_quant_splitter_data_0,
			input_last  => error_quant_splitter_last_0,
			output_ready => error_unquant_ready,
			output_valid => error_unquant_valid,
			output_data  => error_unquant_data,
			output_last  => error_unquant_last
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
			input_last  => error_unquant_last,
			output_0_valid => error_unquant_splitter_valid_0,
			output_0_data  => error_unquant_splitter_data_0,
			output_0_ready => error_unquant_splitter_ready_0,
			output_0_last  => error_unquant_splitter_last_0,
			output_1_valid => error_unquant_splitter_valid_1,
			output_1_data  => error_unquant_splitter_data_1,
			output_1_ready => error_unquant_splitter_ready_1,
			output_1_last  => error_unquant_splitter_last_1
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
			LAST_POLICY   => PASS_ONE
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
			input_1_last  => error_unquant_splitter_last_0,
			output_data   => xhatout_raw_data,
			output_valid  => xhatout_raw_valid,
			output_ready  => xhatout_raw_ready,
			output_last   => xhatout_raw_last
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
			input_last  => xhatout_raw_last,
			output_data => xhatout_raw_data_out,
			output_valid => xhatout_valid,
			output_ready => xhatout_ready,
			output_last  => xhatout_last
		);
	xhatout_data <= xhatout_raw_data_out(DATA_WIDTH - 1 downto 0);
		
	--error mapper
	error_mapper: entity work.ERROR_MAPPER
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			input_ready => error_quant_splitter_ready_1,
			input_valid => error_quant_splitter_valid_1,
			input_data  => error_quant_splitter_data_1,
			input_last  => error_quant_splitter_last_1,
			output_ready => merr_ready,
			output_valid => merr_valid,
			output_data  => mapped_error_data_raw,
			output_last  => merr_last
		);
	--no need for last bit since that can only be set when the error value is -2^n and that is not possible here
	merr_data <= mapped_error_data_raw(PREDICTION_WIDTH - 1 downto 0); 
	
	
	error_acc_in_data <= error_unquant_splitter_data_1 when error_unquant_splitter_data_1(error_unquant_splitter_data_1'high) = '0' else 
		std_logic_vector(-signed(error_unquant_splitter_data_1));
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
			input_valid => error_unquant_splitter_valid_1,
			input_ready => error_unquant_splitter_ready_1,
			input_last  => error_unquant_splitter_last_1,
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
