----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 14.02.2019 09:23:30
-- Design Name: 
-- Module Name: filter_axi - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Substituter for an AXIS bus. It will replace the first INVALID_TRANSACTIONS
--		with the input_sub port instead of their original value.
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

entity AXIS_SUBSTITUTER is
	Generic (
		DATA_WIDTH: integer := 32;
		INVALID_TRANSACTIONS: integer := 1
	);
	Port (
		clk, rst: in std_logic;
		input_ready:	out	std_logic;
		input_valid:	in	std_logic;
		input_data: 	in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_sub:		in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_last:		in  std_logic;
		output_ready:	in 	std_logic;
		output_valid:	out	std_logic;
		output_data:	out	std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_last:	out std_logic
	);
end AXIS_SUBSTITUTER;

architecture Behavioral of AXIS_SUBSTITUTER is
	type filter_state_t is (VALID, INVALID);
	signal state_curr, state_next: filter_state_t;

	signal counter_saturating: std_logic;
	signal counter_enable: std_logic;

begin

	counter: entity work.COUNTER
		Generic map (
			COUNT => INVALID_TRANSACTIONS
		)
		Port map ( 
			clk => clk, rst	=> rst,
			enable		=> counter_enable,
			saturating	=> counter_saturating
		);
		
	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= INVALID;
			else
				state_curr <= state_next;
			end if;
		end if;
	end process;
	
	input_ready <= output_ready;
	output_valid <= input_valid;
	
	comb: process(state_curr, output_ready, input_valid,counter_saturating, input_data, input_sub, 
		counter_saturating, input_last)
	begin
		state_next <= state_curr;
		counter_enable <= '0';
		output_last <= '0';
		
		if state_curr = INVALID then
			output_last <= '0';
			output_data <= input_sub;
			--check for transaction (only on input, output is disconnected)
			if input_valid = '1' and output_ready = '1' then
				counter_enable <= '1';
				if counter_saturating = '1' then
					if input_last = '0' then
						state_next <= VALID;
					end if;
				end if;
			end if;
		elsif state_curr = VALID then
			output_data <= input_data;
			output_last <= input_last;
			--check for transaction (only on input, output is disconnected)
			if input_valid = '1' and output_ready = '1' then
				if input_last = '1' then
					state_next <= INVALID;
				end if;
			end if;
		end if;
	end process;


end Behavioral;
