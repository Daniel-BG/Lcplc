----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 21.02.2019 09:22:48
-- Design Name: 
-- Module Name: FIRSTBAND_PREDICTOR - Behavioral
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

entity FIRSTBAND_PREDICTOR is
	Generic (
		DATA_WIDTH: positive := 16;
		BLOCK_SIZE_LOG: positive := 8
	);
	Port (
		clk, rst		: in  std_logic;
		--input values
		x_valid			: in  std_logic;
		x_ready			: out std_logic;
		x_data			: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		x_last_row		: in  std_logic;	--1 if the current sample is the last of its row
		x_last_block	: in  std_logic;	--1 if the current sample is the last of its block
		--output mapped error, coding parameter and xhat out value
		--output prediction
		prediction_ready: in std_logic;
		prediction_valid: out std_logic;
		prediction_data : out std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end FIRSTBAND_PREDICTOR;

architecture Behavioral of FIRSTBAND_PREDICTOR is
	type firstband_state_t is (IDLE, PREDICTING);
	signal state_curr, state_next: firstband_state_t;
	signal first_sample: boolean;
	signal first_row: boolean;
	signal first_col: boolean;

	--queue system for previous samples
	signal current_sample, left_sample, upper_sample: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal shift_enable: std_logic;

	--prediction
	signal upleft_addition: std_logic_vector(DATA_WIDTH downto 0);
begin

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= IDLE;
				first_row    <= true;
				first_col    <= true;
			else
				state_curr <= state_next;
				if shift_enable = '1' then
					current_sample <= x_data;
					left_sample <= current_sample;
					if x_last_row = '1' and x_last_block = '1' then
						first_row <= true;
						first_col <= true;
					elsif x_last_row = '1' then
						first_row <= false;
						first_col <= true;
					else
						first_col <= false;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	shift_reg_prev_line: entity work.SHIFT_REG
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			DEPTH => 2**(BLOCK_SIZE_LOG/2)
		)
		Port map (
			clk => clk, enable => shift_enable,
			input => current_sample,
			output => upper_sample
		);
	
	comb: process(state_curr, prediction_ready, x_valid)
	begin
		x_ready <= '0';
		shift_enable <= '0';
		prediction_valid <= '0';
		state_next <= state_curr;
		
		if state_curr = IDLE then
			x_ready <= '1';
			if x_valid = '1' then
				shift_enable <= '1';
				state_next <= PREDICTING;
			end if;
		elsif state_curr = PREDICTING then
			prediction_valid <= '1';
			if prediction_ready = '1' then
				x_ready <= '1';
				if x_valid = '1' then
					shift_enable <= '1';
					state_next <= PREDICTING;
				else
					state_next <= IDLE;
				end if;
			end if;
		end if;
	end process;
		
	prediction_gen: process(first_col, first_row, upper_Sample, left_sample, upleft_addition)
	begin
		if first_col and first_row then
			prediction_data <= (others => '0');
			--prediction <= (prediction'high downto current_sample'high+1 => '0') & current_sample;
		elsif first_col then
			prediction_data <= std_logic_vector(resize(unsigned(upper_sample), prediction_data'length));
		elsif first_row then
			prediction_data <= std_logic_vector(resize(unsigned(left_sample), prediction_data'length));
		else
			prediction_data <= std_logic_vector(resize(unsigned(upleft_addition(upleft_addition'high downto 1)), prediction_data'length));
		end if;
	end process;

	upleft_addition <= std_logic_vector(unsigned("0" & upper_sample) + unsigned("0" & left_sample));

end Behavioral;
