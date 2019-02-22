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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity NTHBAND_PREDICTOR is
	Generic (
		DATA_WIDTH: positive := 16;
		ALPHA_WIDTH: positive := 10;
		BLOCK_SIZE_LOG: positive := 8
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
		xmean_valid		: in  std_logic;
		xmean_ready		: out std_logic;
		xmean_data		: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		xhatmean_valid	: in  std_logic;
		xhatmean_ready	: out std_logic;
		xhatmean_data	: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		alpha_valid     : in  std_logic;
		alpha_ready		: out std_logic;
		alpha_data		: in std_logic_vector(ALPHA_WIDTH - 1 downto 0);
		--output prediction
		prediction_ready: in std_logic;
		prediction_valid: out std_logic;
		prediction_data : out std_logic_vector(DATA_WIDTH + 2 downto 0)
	);
end NTHBAND_PREDICTOR;

architecture Behavioral of NTHBAND_PREDICTOR is
	constant PREDICTION_WIDTH: integer := DATA_WIDTH + 3;
	
	--input repeaters
	signal xmean_rep_ready, xmean_rep_valid, xhatmean_rep_ready, xhatmean_rep_valid, alpha_rep_ready, alpha_rep_valid: std_logic;
	signal xmean_rep_data, xhatmean_rep_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal alpha_rep_data: std_logic_vector(ALPHA_WIDTH - 1 downto 0);
	
	--prediction stage 0	
	signal prediction_stage_0_data: std_logic_vector(DATA_WIDTH downto 0);
	signal prediction_stage_0_out_valid, prediction_stage_0_out_ready: std_logic;
	
	--prediction stage 1	
	signal prediction_stage_1_input_b: std_logic_vector(DATA_WIDTH downto 0);
	signal prediction_stage_1_data: std_logic_vector(DATA_WIDTH + ALPHA_WIDTH downto 0);
	signal prediction_stage_1_out_valid, prediction_stage_1_out_ready: std_logic;
	
	--prediction stage 2
	signal prediction_stage_2_input_b: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	
	
					
begin

	-------------------
	--INPUT REPEATERS--
	-------------------
	
	xmean_repeater: entity work.AXIS_DATA_REPEATER
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			NUMBER_OF_REPETITIONS => 2**BLOCK_SIZE_LOG
		)
		Port map (
			clk => clk, rst => rst,
			input_ready => xmean_ready,
			input_valid => xmean_valid,
			input_data  => xmean_data,
			output_ready=> xmean_rep_ready,
			output_valid=> xmean_rep_valid,
			output_data => xmean_rep_data
		);

	xhatmean_repeater: entity work.AXIS_DATA_REPEATER
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			NUMBER_OF_REPETITIONS => 2**BLOCK_SIZE_LOG
		)
		Port map (
			clk => clk, rst => rst,
			input_ready => xhatmean_ready,
			input_valid => xhatmean_valid,
			input_data  => xhatmean_data,
			output_ready=> xhatmean_rep_ready,
			output_valid=> xhatmean_rep_valid,
			output_data => xhatmean_rep_data
		);
		
	alpha_repeater: entity work.AXIS_DATA_REPEATER
		Generic map (
			DATA_WIDTH => ALPHA_WIDTH,
			NUMBER_OF_REPETITIONS => 2**BLOCK_SIZE_LOG
		)
		Port map (
			clk => clk, rst => rst,
			input_ready => alpha_ready,
			input_valid => alpha_valid,
			input_data  => alpha_data,
			output_ready=> alpha_rep_ready,
			output_valid=> alpha_rep_valid,
			output_data => alpha_rep_data
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
			SIGNED_OP => true
		)
		Port map (
			clk => clk, rst => rst,
			input_0_data  => xhat_data,
			input_0_valid => xhat_valid,
			input_0_ready => xhat_ready,
			input_1_data  => xhatmean_rep_data,
			input_1_valid => xhatmean_rep_valid,
			input_1_ready => xhatmean_rep_ready,
			output_data   => prediction_stage_0_data,
			output_valid  => prediction_stage_0_out_valid,
			output_ready  => prediction_stage_0_out_ready
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
			SIGNED_OP => true
		)
		Port map (
			clk => clk, rst => rst,
			input_0_data  => prediction_stage_0_data,
			input_0_valid => prediction_stage_0_out_valid,
			input_0_ready => prediction_stage_0_out_ready,
			input_1_data  => alpha_rep_data,
			input_1_valid => alpha_rep_valid,
			input_1_ready => alpha_rep_ready,
			output_data   => prediction_stage_1_data,
			output_valid  => prediction_stage_1_out_valid,
			output_ready  => prediction_stage_1_out_ready
		);
	
	--third stage		
	prediction_stage_2: entity work.AXIS_ARITHMETIC_OP
		Generic Map (
			DATA_WIDTH_0 => DATA_WIDTH + 2,
			DATA_WIDTH_1 => DATA_WIDTH,
			OUTPUT_DATA_WIDTH => DATA_WIDTH + 3,
			IS_ADD => true,
			SIGN_EXTEND_0 => true,
			SIGN_EXTEND_1 => false,
			SIGNED_OP => true
		)
		Port Map (
			clk => clk, rst => rst,
			input_0_data =>  prediction_stage_1_data(ALPHA_WIDTH + DATA_WIDTH downto ALPHA_WIDTH - 1),
			input_0_valid => prediction_stage_1_out_valid,
			input_0_ready => prediction_stage_1_out_ready,
			input_1_data  => xmean_rep_data,
			input_1_valid => xmean_rep_valid,
			input_1_ready => xmean_rep_ready,
			output_data   => prediction_data,
			output_valid  => prediction_valid,
			output_ready  => prediction_ready
		);

end Behavioral;
