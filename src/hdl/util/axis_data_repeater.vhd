----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 14.02.2019 10:11:24
-- Design Name: 
-- Module Name: AXIS_DATA_REPEATER - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Takes values from the input and repeats them a specified number
--		of times over the output
--
-- Dependencies: None 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity AXIS_DATA_REPEATER is
	Generic (
		DATA_WIDTH: integer := 16;
		NUMBER_OF_REPETITIONS: integer := 256
	);
	Port (
		clk, rst: in std_logic;
		input_ready		: out std_logic;
		input_valid		: in  std_logic;
		input_data		: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_ready	: in  std_logic;
		output_valid	: out std_logic;
		output_data		: out std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end AXIS_DATA_REPEATER;

architecture Behavioral of AXIS_DATA_REPEATER is
	type repeater_state_t is (READING, REPEATING);
	signal state_curr, state_next: repeater_state_t;
	
	signal buf, buf_next: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--counter
	signal counter_enable, counter_saturating: std_logic;
begin

	counter: entity work.COUNTER 
		Generic map (
			COUNT => NUMBER_OF_REPETITIONS
		)
		Port map ( 
			clk => clk, rst => rst,
			enable		=> counter_enable,
			saturating	=> counter_saturating
		);

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= READING;
				buf <= (others => '0');
			else
				state_curr <= state_next;
				buf <= buf_next;
			end if;
		end if;
	end process;
	
	comb: process(state_curr, input_valid, buf, input_data, output_ready, counter_saturating)
	begin
		input_ready <= '0';
		buf_next <= buf;
		state_next <= state_curr;
		output_valid <= '0';
		counter_enable <= '0';
	
		if state_curr = READING then
			input_ready <= '1';
			if input_valid = '1' then
				buf_next <= input_data;
				state_next <= REPEATING;
			end if;	
		elsif state_curr = REPEATING then
			output_valid <= '1';
			if output_ready = '1' then
				counter_enable <= '1';
				if counter_saturating = '1' then
					state_next <= READING;
				end if;
			end if;
		end if;
	end process;
	
	output_data <= buf;


end Behavioral;
