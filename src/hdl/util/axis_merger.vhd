----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 14.02.2019 12:54:33
-- Design Name: 
-- Module Name: merger_axi - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Module that connects the input buses for the given amount of times
--		with the outputs. The last input is left connected until clear or rst is
--		brought up. As long as clear is held up, the first axis bus is connected so 
--		transactions will be made through it!
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

entity AXIS_MERGER is
	Generic (
		DATA_WIDTH: integer := 16;
		FROM_PORT_ZERO: integer := 256;
		FROM_PORT_ONE: integer := 256
	);
	Port ( 
		clk, rst: in std_logic;
		clear: in std_logic;
		--to input axi port
		input_0_valid	: in	std_logic;
		input_0_ready	: out	std_logic;
		input_0_data	: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_1_valid	: in	std_logic;
		input_1_ready	: out	std_logic;
		input_1_data	: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_2_valid	: in	std_logic;
		input_2_ready	: out	std_logic;
		input_2_data	: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		--to output axi ports
		output_valid	: out 	std_logic;
		output_ready	: in 	std_logic;
		output_data		: out	std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end AXIS_MERGER;

architecture Behavioral of AXIS_MERGER is
	signal counter_zero_enable, counter_zero_saturating: std_logic;
	signal counter_one_enable, counter_one_saturating: std_logic;
	
	type merger_state_t is (READING_PORT_ZERO, READING_PORT_ONE, READING_PORT_TWO);
	signal state_curr, state_next: merger_state_t;

	signal rst_or_clear: std_logic;
	
begin

	rst_or_clear <= rst or clear;

	counter_zero: entity work.COUNTER
		generic map (
			COUNT => FROM_PORT_ZERO
		)
		Port map (
			clk => clk, rst => rst_or_clear,
			enable => counter_zero_enable,
			saturating => counter_zero_saturating
		);

	counter_one: entity work.COUNTER
		generic map (
			COUNT => FROM_PORT_ONE
		)
		Port map (
			clk => clk, rst => rst_or_clear,
			enable => counter_one_enable,
			saturating => counter_one_saturating
		);

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst_or_clear = '1' then
				state_curr <= READING_PORT_ZERO;
			else
				state_curr <= state_next;
			end if;
		end if;
	end process;

	comb: process(state_curr, 
		input_0_valid, input_1_valid, input_2_valid,
		input_0_data, input_1_data, input_2_data,
		output_ready, counter_zero_saturating, counter_one_saturating)
	begin
		state_next <= state_curr;
		counter_zero_enable <= '0';
		counter_one_enable <= '0';

		input_0_ready <= '0';
		input_1_ready <= '0';
		input_2_ready <= '0';
		output_valid  <= '0';
		output_data   <= (others => '0');

		if state_curr = READING_PORT_ZERO then
			input_0_ready <= output_ready;
			output_valid  <= input_0_valid;
			output_data   <= input_0_data;
			if input_0_valid = '1' and output_ready = '1' then
				counter_zero_enable <= '1';
				if counter_zero_saturating = '1' then
					state_next <= READING_PORT_ONE;
				end if;
			end if;
		elsif state_curr = READING_PORT_ONE then
			input_1_ready <= output_ready;
			output_valid  <= input_1_valid;
			output_data   <= input_1_data;
			if input_1_valid = '1' and output_ready = '1' then
				counter_one_enable <= '1';
				if counter_one_saturating = '1' then
					state_next <= READING_PORT_TWO;
				end if;
			end if;
		elsif state_curr = READING_PORT_TWO then
			--stay here
			input_2_ready <= output_ready;
			output_valid  <= input_2_valid;
			output_data   <= input_2_data;
		end if;
 	end process;


end Behavioral;
