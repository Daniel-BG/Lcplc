----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 21.02.2019 09:22:48
-- Design Name: 
-- Module Name: FIRSTBAND_PREDICTOR_V2 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Module that makes the prediction for the first band in a given 
--			image block. Takes raw values and outputs prediction data
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

entity FIRSTBAND_PREDICTOR_V2 is
	Generic (
		DATA_WIDTH: positive := 16;
		MAX_SLICE_SIZE_LOG: positive := 8;
		QUANTIZER_SHIFT_WIDTH: positive := 4
	);
	Port (
		clk, rst		: in  std_logic;
		--input values
		x_valid			: in  std_logic;
		x_ready			: out std_logic;
		x_data			: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		x_last_r		: in  std_logic;	--1 if the current sample is the last of its row
		x_last_s		: in  std_logic;	--1 if the current sample is the last of its block
		--output prediction
		xtilde_ready: in  std_logic;
		xtilde_valid: out std_logic;
		xtilde_data : out std_logic_vector(DATA_WIDTH - 1 downto 0);
		xtilde_last : out std_logic; --last slice
		--configurable shift for quantizers
		cfg_quant_shift	: in  std_logic_vector(QUANTIZER_SHIFT_WIDTH - 1 downto 0)
	);
end FIRSTBAND_PREDICTOR_V2;

architecture Behavioral of FIRSTBAND_PREDICTOR_V2 is
	--input qol signals
	signal x_last_r_s: std_logic_vector(1 downto 0);

	--input splitter signals
	signal x_0_valid, x_0_ready, x_1_valid, x_1_ready: std_logic;
	signal x_0_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal x_1_last_r_s: std_logic_vector(1 downto 0);

	--error sub signals
	signal raw_err_data: std_logic_vector(DATA_WIDTH downto 0);
	signal raw_err_valid, raw_err_ready: std_logic;

	--error qdq signals
	signal qdq_err_ready, qdq_err_valid: std_logic;
	signal qdq_err_data: std_logic_vector(DATA_WIDTH downto 0);

	--raw decoded adder
	signal raw_decoded_data: std_logic_vector(DATA_WIDTH downto 0);
	signal raw_decoded_valid, raw_decoded_ready: std_logic;
	signal raw_decoded_last_r_s: std_logic_vector(1 downto 0);

	--clamped decoded value
	signal decoded_data: std_logic_vector(DATA_WIDTH downto 0);
	signal decoded_valid, decoded_ready: std_logic;
	signal decoded_last_r_s: std_logic_vector(1 downto 0);

	--prediction
	signal prediction_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal prediction_ready, prediction_valid: std_logic;
	signal prediction_last_s: std_logic;

	--merged prediction
	signal mer_prediction_valid, mer_prediction_ready: std_logic;
	signal mer_prediction_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal mer_prediction_last: std_logic;

	--filter out last prediction
	signal filt_pred_valid, filt_pred_ready: std_logic;
	signal filt_pred_data: std_logic_vector(DATA_WIDTH - 1 downto 0);

	--final syncer
	signal synced_pred_valid, synced_pred_ready: std_logic;
	signal synced_pred_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal synced_pred_last_r_s: std_logic_vector(1 downto 0);

	--prediction splitter
	signal pred_0_valid, pred_1_valid, pred_2_valid: std_logic;
	signal pred_0_ready, pred_1_ready, pred_2_ready: std_logic;
	signal pred_0_data, pred_1_data, pred_2_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal pred_0_user, pred_1_user, pred_2_user: std_logic_vector(1 downto 0);


begin
	--static assignments
	x_last_r_s <= x_last_r & x_last_s;

	--input x splitter. data goes through the pipeline while 
	--control signals go towards the output control
	input_splitter: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			USER_WIDTH => 2
		)
		Port map (
			clk => clk, rst => rst,
			input_valid => x_valid,
			input_ready => x_ready,
			input_data  => x_data,
			input_user  => x_last_r_s,
			output_0_valid => x_0_valid,
			output_0_data  => x_0_data,
			output_0_ready => x_0_ready,
			output_1_valid => x_1_valid,
			output_1_ready => x_1_ready,
			output_1_user  => x_1_last_r_s
		);

	--substract prediction from raw input value
	error_sub: entity work.AXIS_ARITHMETIC_OP
		Generic map (
			DATA_WIDTH_0 => DATA_WIDTH,
			DATA_WIDTH_1 => DATA_WIDTH,
			OUTPUT_DATA_WIDTH => DATA_WIDTH + 1,
			IS_ADD => false,
			SIGN_EXTEND_0 => false,
			SIGN_EXTEND_1 => false,
			SIGNED_OP	  => true
		)
		Port map(
			clk => clk, rst => rst,
			input_0_data  => x_0_data,
			input_0_valid => x_0_valida,
			input_0_ready => x_0_ready,
			input_1_data  => pred_0_data,
			input_1_valid => pred_0_valid,
			input_1_ready => pred_0_ready,
			output_data   => raw_err_data,
			output_valid  => raw_err_valid,
			output_ready  => raw_err_ready
		);

	--quantize and dequantize
	error_qdq: entity work.BINARY_QDQ
		Generic map (
			SHIFT_WIDTH => QUANTIZER_SHIFT_WIDTH,
			DATA_WIDTH	=> DATA_WIDTH + 1
		)
		Port map (
			clk => clk, rst => rst,
			input_ready	=> raw_err_ready,
			input_valid	=> raw_err_valid,
			input_data	=> raw_err_data,
			output_ready=> qdq_err_ready,
			output_valid=> qdq_err_valid,
			output_data => qdq_err_data,
			--configuration ports
			input_shift	=> cfg_quant_shift
		);

	--simulate decoded values for the predictor
	decode_adder: entity work.AXIS_ARITHMETIC_OP
		Generic map (
			DATA_WIDTH_0 => DATA_WIDTH + 1,
			DATA_WIDTH_1 => DATA_WIDTH,
			OUTPUT_DATA_WIDTH => DATA_WIDTH + 1,
			IS_ADD => true,
			SIGN_EXTEND_0 => true,
			SIGN_EXTEND_1 => false,
			SIGNED_OP	  => true,
			LAST_POLICY   => PASS_ONE,
			USER_WIDTH    => 2,
			USER_POLICY   => PASS_ONE
		)
		Port map(
			clk => clk, rst => rst,
			input_0_data  => qdq_err_data,
			input_0_valid => qdq_err_valid,
			input_0_ready => qdq_err_ready,
			input_1_data  => pred_1_data,
			input_1_valid => pred_1_valid,
			input_1_ready => pred_1_ready,
			input_1_user  => pred_1_user,
			output_data   => raw_decoded_data,
			output_valid  => raw_decoded_valid,
			output_ready  => raw_decoded_ready,
			output_user   => raw_decoded_last_r_s
		);

	decode_clamp: entity work.AXIS_INTERVAL_CLAMPER
		Generic map (
			DATA_WIDTH => DATA_WIDTH + 1
			IS_SIGNED => true,
			LOWER_LIMIT => 0
			UPPER_LIMIT => 2**DATA_WIDTH - 1
			USER_WIDTH => 2
		)
		Port map (
			clk => clk, rst => rst,
			input_data	=> raw_decoded_data,
			input_valid	=> raw_decoded_valid,
			input_ready	=> raw_decoded_ready,
			input_user	=> raw_decoded_last_r_s,
			output_data	=> decoded_data,
			output_valid=> decoded_valid,
			output_ready=> decoded_ready,
			output_user => decoded_last_r_s
		);

	predictor: entity work.TWO_D_PREDICTOR
		generic map (
			DATA_WIDTH => DATA_WIDTH
		)
		port map (
			clk => clk, rst => rst,
			input_data 		=> decoded_data(DATA_WIDTH - 1 downto 0),
			input_ready 	=> decoded_ready,
			input_valid 	=> decoded_valid,
			input_last_r 	=> decoded_last_r_s(1),
			input_last_s 	=> decoded_last_r_s(0),
			output_data 	=> prediction_data,
			output_ready 	=> prediction_ready,
			output_valid 	=> prediction_valid,
			output_last_s 	=> prediction_last_s
		);


	first_prediction_merger: entity work.AXIS_MERGER_2
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			START_ON_PORT => 1
		);
		Port map ( 
			clk => clk, rst => rst,
			--to input axi port
			input_0_valid	=> prediction_valid,
			input_0_ready	=> prediction_ready,
			input_0_data	=> prediction_data,
			input_0_last	=> prediction_last_s,
			input_0_merge	=> prediction_last_s,
			input_1_valid	=> '1',
			input_1_data	=> (DATA_WIDTH - 1 downto 0 => '0');
			input_1_last	=> '0',
			input_1_merge	=> '1',
			--to output axi ports
			output_valid	=> mer_prediction_valid,
			output_ready	=> mer_prediction_ready,
			output_data		=> mer_prediction_data,
			output_last		=> mer_prediction_last
		);



	last_prediction_filter: entity work.AXIS_FILTER
		Generic (
			DATA_WIDTH => DATA_WIDTH,
			ELIMINATE_ON_UP => true
		)
		Port (
			clk => clk, rst => rst,
			input_valid		=> mer_prediction_valid,
			input_ready		=> mer_prediction_ready,
			input_data		=> mer_prediction_data,
			flag_valid		=> mer_prediction_valid,
			flag_ready		=> open,
			flag_data		=> mer_prediction_last,
			--to output axi ports
			output_valid	=> filt_pred_valid,
			output_ready	=> filt_pred_ready,
			output_data		=> filt_pred_data
		);

	flag_sync: entity work.AXIS_SYNCHRONIZER_2
		Generic map (
			DATA_WIDTH_0 => DATA_WIDTH,
			DATA_WIDTH_1 => 2,
			LATCH => true
		)
		Port map (
			clk => clk, rst => rst,
			--to input axi port
			input_0_valid => filt_pred_valid,
			input_0_ready => filt_pred_ready,
			input_0_data  => filt_pred_data,
			input_1_valid => x_1_valid,
			input_1_ready => x_1_ready,
			input_1_data  => x_1_last_r_s,
			--to output axi ports
			output_valid  => synced_pred_valid,
			output_ready  => synced_pred_ready,
			output_data_0 => synced_pred_data,
			output_data_1 => synced_pred_last_r_s
		);

	prediction_split: entity work.AXIS_SPLITTER_3
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			USER_WIDTH => 2
		)
		Port map (
			clk => clk, rst => rst,
			--to input axi port
			input_valid		=> synced_pred_valid,
			input_data		=> synced_pred_data,
			input_ready		=> synced_pred_ready,
			input_user		=> synced_pred_last_r_s,
			--to output axi ports
			output_0_valid	=> pred_0_valid,
			output_0_data	=> pred_0_data,
			output_0_ready	=> pred_0_ready,
			output_0_user	=> pred_0_user,
			output_1_valid	=> pred_1_valid,
			output_1_data	=> pred_1_data,
			output_1_ready	=> pred_1_ready,
			output_1_user	=> pred_1_user,
			output_2_valid	=> pred_2_valid,
			output_2_data	=> pred_2_data,
			output_2_ready	=> pred_2_ready,
			output_2_user	=> pred_2_user
		);

	pred_2_ready <= xtilde_ready;
	xtilde_valid <= pred_2_valid;
	xtilde_data  <= pred_2_data;
	xtilde_last  <= pred_2_user(0);

end Behavioral;