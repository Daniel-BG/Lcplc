----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 22.02.2019 18:08:34
-- Design Name: 
-- Module Name: AXIS_REDUCER - Behavioral
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

entity AXIS_TRASHER is
	Generic (
		DATA_WIDTH: integer := 32;
		INVALID_TRANSACTIONS: integer := 1
	);
	Port (
		clk, rst: in std_logic;
		input_ready:	out	std_logic;
		input_valid:	in	std_logic;
		input_data: 	in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_ready:	in 	std_logic;
		output_valid:	out	std_logic;
		output_data:	out	std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end AXIS_TRASHER;

architecture Behavioral of AXIS_TRASHER is
	type state_t is (INVALID, VALID);
	signal state_curr, state_next: state_t;
	
	signal counter_enable, counter_saturating: std_logic;
begin


	cnt: entity work.COUNTER
		generic map (COUNT => INVALID_TRANSACTIONS)
		port map ( 
			clk => clk, rst => rst,
			enable => counter_enable,
			saturating => counter_saturating
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

	comb: process(state_curr, input_valid, counter_saturating, output_ready)
	begin
		input_ready <= '0';
		state_next  <= state_curr;
		counter_enable <= '0';
		output_valid <= '0';

		if state_curr = INVALID then
			input_ready <= '1';
			if input_valid = '1' then
				counter_enable <= '1';
				if counter_saturating = '1' then
					state_next <= VALID;
				end if;
			end if;
		elsif state_curr = VALID then
			output_valid <= input_valid;
			input_ready  <= output_ready;
		end if;
	end process;

	output_data <= input_data;


end Behavioral;
