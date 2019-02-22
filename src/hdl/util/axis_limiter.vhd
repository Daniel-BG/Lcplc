----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 14.02.2019 09:23:30
-- Design Name: 
-- Module Name: AXIS_LIMITER - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Limit the flow through an AXIS link. When the number of valid 
--		transactions has been reached, all subsequent ones are ignored (but consumed)
--		the last transaction will have output_last up to signal the end of the stream
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

entity AXIS_LIMITER is
	Generic (
		DATA_WIDTH: integer := 32;
		VALID_TRANSACTIONS: integer := 255
	);
	Port (
		clk, rst: in std_logic;
		input_ready		:	out	std_logic;
		input_valid		:	in	std_logic;
		input_data		: 	in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_ready	:	in 	std_logic;
		output_valid	:	out	std_logic;
		output_last		:	out std_logic;
		output_data		:	out	std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end AXIS_LIMITER;

architecture Behavioral of AXIS_LIMITER is
	type filter_state_t is (VALID, INVALID);
	signal state_curr, state_next, state_first: filter_state_t;

	signal counter_enable, counter_saturating: std_logic;
begin

	counter: entity work.COUNTER
		Generic map (
			COUNT => VALID_TRANSACTIONS
		)
		Port map ( 
			clk => clk, rst	=> rst,
			enable     => counter_enable,
			saturating => counter_saturating
		);

	output_data <= input_data;

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= VALID;
			else
				state_curr <= state_next;
			end if;
		end if;
	end process;
	
	comb: process(state_curr, output_ready, input_valid, counter_saturating)
	begin
		state_next <= state_curr;
		output_last <= '0';
		counter_enable <= '0';
		
		if state_curr = VALID then
			input_ready <= output_ready;
			output_valid <= input_valid;
			if counter_saturating = '1' then
				output_last <= '1';
			end if;
			--check for transaction
			if output_ready = '1' and input_valid = '1' then
				counter_enable <= '1';
				if counter_saturating = '1' then
					state_next <= INVALID;
				end if;
			end if;
		elsif state_curr = INVALID then
			--continue reading but don't send anything to the output
			input_ready <= '1';
			output_valid <= '0';
		end if;
	end process;

end Behavioral;
