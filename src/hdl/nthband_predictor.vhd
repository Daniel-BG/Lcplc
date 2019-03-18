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

entity NTHBAND_PREDICTOR is
	Generic (
		DATA_WIDTH: positive := 16;
		ALPHA_WIDTH: positive := 10
	);
	Port (
		clk, rst		: in  std_logic;
		--input xhat, xmean, xhatmean, alpha
		--(xmean the mean for the block slice)
		--xhat is the decoded value of previous block slice
		--alpha is the alpha value for the current block slice
		xhat_valid		: in  std_logic;
		xhat_ready		: out std_logic;
		xhat_data		: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		xhat_last_s		: in  std_logic;
		xmean_valid		: in  std_logic;
		xmean_ready		: out std_logic;
		xmean_data		: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		xhatmean_valid	: in  std_logic;
		xhatmean_ready	: out std_logic;
		xhatmean_data	: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		alpha_valid     : in  std_logic;
		alpha_ready		: out std_logic;
		alpha_data		: in  std_logic_vector(ALPHA_WIDTH - 1 downto 0);
		--output prediction
		xtilde_ready	: in  std_logic;
		xtilde_valid	: out std_logic;
		xtilde_data 	: out std_logic_vector(DATA_WIDTH + 2 downto 0);
		xtilde_last 	: out std_logic
	);
end NTHBAND_PREDICTOR;

architecture Behavioral of NTHBAND_PREDICTOR is
	constant PREDICTION_WIDTH: integer := DATA_WIDTH + 3;

	--input splitter
	signal xhat_last_data: std_logic_vector(DATA_WIDTH downto 0);
	signal xhat_0_ready, xhat_1_ready, xhat_2_ready, xhat_3_ready: std_logic;
	signal xhat_0_valid, xhat_1_valid, xhat_2_valid, xhat_3_valid: std_logic;
	signal xhat_0_last, xhat_1_last, xhat_2_last, xhat_3_last: std_logic;
	signal xhat_0_data, xhat_1_data, xhat_2_data, xhat_3_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xhat_0_last_data, xhat_1_last_data, xhat_2_last_data, xhat_3_last_data: std_logic_vector(DATA_WIDTH downto 0);
	
	--input repeaters
	signal xmean_rep_ready, xmean_rep_valid, xhatmean_rep_ready, xhatmean_rep_valid, alpha_rep_ready, alpha_rep_valid: std_logic;
	signal xmean_rep_data, xhatmean_rep_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal alpha_rep_data: std_logic_vector(ALPHA_WIDTH - 1 downto 0);
	
	--xmean delayer
	signal xmean_rep_ready_delay, xmean_rep_valid_delay: std_logic;
	signal xmean_rep_data_delay: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--alpha delayer
	signal alpha_rep_ready_delay, alpha_rep_valid_delay: std_logic;
	signal alpha_rep_data_delay: std_logic_vector(ALPHA_WIDTH - 1 downto 0);
	
	--prediction stage 0	
	signal prediction_stage_0_data: std_logic_vector(DATA_WIDTH downto 0);
	signal prediction_stage_0_out_valid, prediction_stage_0_out_ready, prediction_stage_0_out_last: std_logic;
	
	--prediction stage 1	
	signal prediction_stage_1_input_b: std_logic_vector(DATA_WIDTH downto 0);
	signal prediction_stage_1_data: std_logic_vector(DATA_WIDTH + ALPHA_WIDTH downto 0);
	signal prediction_stage_1_valid, prediction_stage_1_ready, prediction_stage_1_last: std_logic;
	
	--shift of stage 1 output
	--signal prediction_stage_1_shifted_data: std_logic_vector(DATA_WIDTH + 1 downto 0);
	--signal prediction_stage_1_shifted_ready, prediction_stage_1_shifted_valid: std_logic;
	
	--prediction stage 2
	signal prediction_stage_2_input_b: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	
	
					
begin

	-------------------
	--INPUT  SPLITTER--
	-------------------
	xhat_last_data <= xhat_last_s & xhat_data;
	xhat_splitter: entity work.AXIS_SPLITTER_4
		Generic map (
			DATA_WIDTH => DATA_WIDTH + 1 --one extra for flag
		)
		Port map (
			clk => clk, rst => rst,
			input_valid		=> xhat_valid,
			input_data		=> xhat_last_data,
			input_ready		=> xhat_ready,
			output_0_valid	=> xhat_0_valid,
			output_0_data	=> xhat_0_last_data,
			output_0_ready	=> xhat_0_ready,
			output_1_valid	=> xhat_1_valid,
			output_1_data	=> xhat_1_last_data,
			output_1_ready	=> xhat_1_ready,
			output_2_valid	=> xhat_2_valid,
			output_2_data	=> xhat_2_last_data,
			output_2_ready	=> xhat_2_ready,
			output_3_valid	=> xhat_3_valid,
			output_3_data	=> xhat_3_last_data,
			output_3_ready	=> xhat_3_ready
		);
	xhat_0_last <= xhat_0_last_data(xhat_0_last_data'high);
	xhat_0_data <= xhat_0_last_data(xhat_0_data'high downto 0);
	xhat_1_last <= xhat_1_last_data(xhat_1_last_data'high);
	xhat_1_data <= xhat_1_last_data(xhat_1_data'high downto 0);
	xhat_2_last <= xhat_2_last_data(xhat_2_last_data'high);
	xhat_2_data <= xhat_2_last_data(xhat_2_data'high downto 0);
	xhat_3_last <= xhat_3_last_data(xhat_3_last_data'high);
	xhat_3_data <= xhat_3_last_data(xhat_3_data'high downto 0);

	-------------------
	--INPUT   HOLDERS--
	-------------------

	xmean_holder: entity work.AXIS_HOLDER
		Generic map (
			DATA_WIDTH => DATA_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			clear_ready		=> xhat_0_ready,
			clear_valid		=> xhat_0_valid,
			clear_data		=> xhat_0_last,
			input_ready		=> xmean_ready,
			input_valid		=> xmean_valid,
			input_data		=> xmean_data,
			output_ready	=> xmean_rep_ready,
			output_valid	=> xmean_rep_valid,
			output_data		=> xmean_rep_data
		);
		
	--alpha delayer
	xmean_delay: entity work.AXIS_FIFO 
		generic map (
			DATA_WIDTH => DATA_WIDTH,
			FIFO_DEPTH => 7
		)
		port map (
			clk => clk, rst => rst,
			input_data  => xmean_rep_data,
			input_ready => xmean_rep_ready,
			input_valid => xmean_rep_valid,
			output_data => xmean_rep_data_delay,
			output_ready=> xmean_rep_ready_delay,
			output_valid=> xmean_rep_valid_delay
		);

	xhatmean_holder: entity work.AXIS_HOLDER
		Generic map (
			DATA_WIDTH => DATA_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			clear_ready		=> xhat_1_ready,
			clear_valid		=> xhat_1_valid,
			clear_data		=> xhat_1_last,
			input_ready		=> xhatmean_ready,
			input_valid		=> xhatmean_valid,
			input_data		=> xhatmean_data,
			output_ready	=> xhatmean_rep_ready,
			output_valid	=> xhatmean_rep_valid,
			output_data		=> xhatmean_rep_data
		);

	alpha_holder: entity work.AXIS_HOLDER
		Generic map (
			DATA_WIDTH => ALPHA_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			clear_ready		=> xhat_2_ready,
			clear_valid		=> xhat_2_valid,
			clear_data		=> xhat_2_last,
			input_ready		=> alpha_ready,
			input_valid		=> alpha_valid,
			input_data		=> alpha_data,
			output_ready	=> alpha_rep_ready,
			output_valid	=> alpha_rep_valid,
			output_data		=> alpha_rep_data
		);
		
	--alpha delayer
	alpha_delay: entity work.AXIS_FIFO 
		generic map (
			DATA_WIDTH => ALPHA_WIDTH,
			FIFO_DEPTH => 3	
		)
		port map (
			clk => clk, rst => rst,
			input_data  => alpha_rep_data,
			input_ready => alpha_rep_ready,
			input_valid => alpha_rep_valid,
			output_data => alpha_rep_data_delay,
			output_ready=> alpha_rep_ready_delay,
			output_valid=> alpha_rep_valid_delay
		);
		
	--------------
	--PREDICTION--
	--------------
	
	--first stage	
	prediction_stage_0: entity work.AXIS_ARITHMETIC_OP
		Generic map (
			DATA_WIDTH_0 => DATA_WIDTH,
			DATA_WIDTH_1 => DATA_WIDTH,
			OUTPUT_DATA_WIDTH => DATA_WIDTH + 1,
			IS_ADD => false,
			SIGN_EXTEND_0 => false,
			SIGN_EXTEND_1 => false,
			SIGNED_OP => true,
			LAST_POLICY => PASS_ZERO
		)
		Port map (
			clk => clk, rst => rst,
			input_0_data  => xhat_3_data,
			input_0_valid => xhat_3_valid,
			input_0_ready => xhat_3_ready,
			input_0_last  => xhat_3_last,
			input_1_data  => xhatmean_rep_data,
			input_1_valid => xhatmean_rep_valid,
			input_1_ready => xhatmean_rep_ready,
			input_1_last  => '0',
			output_data   => prediction_stage_0_data,
			output_valid  => prediction_stage_0_out_valid,
			output_ready  => prediction_stage_0_out_ready,
			output_last   => prediction_stage_0_out_last
		);
		
	--second stage
	prediction_stage_1_input_b <= (DATA_WIDTH downto ALPHA_WIDTH => '0') & alpha_rep_data;
	prediction_stage_1: entity work.AXIS_MULTIPLIER
		Generic map (
			DATA_WIDTH_0 => DATA_WIDTH + 1,
			DATA_WIDTH_1 => ALPHA_WIDTH,
			OUTPUT_WIDTH => DATA_WIDTH + 1 + ALPHA_WIDTH,
			SIGN_EXTEND_0 => true,
			SIGN_EXTEND_1 => false,
			SIGNED_OP => true,
			LAST_POLICY => PASS_ZERO
		)
		Port map (
			clk => clk, rst => rst,
			input_0_data  => prediction_stage_0_data,
			input_0_valid => prediction_stage_0_out_valid,
			input_0_ready => prediction_stage_0_out_ready,
			input_0_last  => prediction_stage_0_out_last,
			input_1_data  => alpha_rep_data_delay,
			input_1_valid => alpha_rep_valid_delay,
			input_1_ready => alpha_rep_ready_delay,
			input_1_last  => '0',
			output_data   => prediction_stage_1_data,
			output_valid  => prediction_stage_1_valid,
			output_ready  => prediction_stage_1_ready,
			output_last   => prediction_stage_1_last
		);
		
	--shifter b4 final stage
-- 	signed_shifter: entity work.POWER_OF_TWO_SIGNED_SHIFTER
--		Generic map (
--			DATA_WIDTH => prediction_stage_1_data'length,
--			SHAMT => ALPHA_WIDTH - 1
--		)
--		Port map ( 
--			input_data	=> prediction_stage_1_data,
--			input_ready => prediction_stage_1_out_ready,
--			input_valid => prediction_stage_1_out_valid,
--			output_data	=> prediction_stage_1_shifted_data,
--			output_ready=> prediction_stage_1_shifted_ready,
--			output_valid=> prediction_stage_1_shifted_valid
--		);
	
	--third stage		
	prediction_stage_2: entity work.AXIS_ARITHMETIC_OP
		Generic Map (
			DATA_WIDTH_0 => DATA_WIDTH + 2,
			DATA_WIDTH_1 => DATA_WIDTH,
			OUTPUT_DATA_WIDTH => DATA_WIDTH + 3,
			IS_ADD => true,
			SIGN_EXTEND_0 => true,
			SIGN_EXTEND_1 => false,
			SIGNED_OP => true,
			LAST_POLICY => PASS_ZERO
		)
		Port Map (
			clk => clk, rst => rst,
			input_0_data  => prediction_stage_1_data(prediction_stage_1_data'high downto ALPHA_WIDTH - 1),
			input_0_valid => prediction_stage_1_valid,
			input_0_ready => prediction_stage_1_ready,
			input_0_last  => prediction_stage_1_last,
			input_1_data  => xmean_rep_data_delay,
			input_1_valid => xmean_rep_valid_delay,
			input_1_ready => xmean_rep_ready_delay,
			input_1_last  => '0',
			output_data   => xtilde_data,
			output_valid  => xtilde_valid,
			output_ready  => xtilde_ready,
			output_last   => xtilde_last
		);

end Behavioral;
