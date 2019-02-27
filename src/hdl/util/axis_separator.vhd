----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 14.02.2019 12:54:33
-- Design Name: 
-- Module Name: AXIS_SEPARATOR - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Separate samples to two different ports. You can set how many go 
--		to each port until the next is selected
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

entity AXIS_SEPARATOR is
	Generic (
		DATA_WIDTH: integer := 16;
		TO_PORT_ZERO: integer := 1;
		TO_PORT_ONE: integer := 255
	);
	Port ( 
		clk, rst: in std_logic;
		--to input axi port
		input_valid		: in	std_logic;
		input_ready		: out	std_logic;
		input_data		: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		--to output axi ports
		output_0_valid	: out 	std_logic;
		output_0_ready	: in 	std_logic;
		output_0_data	: out	std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_1_valid	: out 	std_logic;
		output_1_ready	: in 	std_logic;
		output_1_data	: out	std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end AXIS_SEPARATOR;

architecture Behavioral of AXIS_SEPARATOR is
	type separator_state_t is (PORT_ZERO, PORT_ONE);
	signal state_curr, state_next: separator_state_t;
	
	signal counter_zero_saturating, counter_zero_enable: std_logic;
	signal counter_one_saturating, counter_one_enable: std_logic;
begin
	--counters
	counter_zero: entity work.COUNTER
		Generic map (
			COUNT => TO_PORT_ZERO
		)
		Port map ( 
			clk => clk, rst	=> rst,
			enable 		=> counter_zero_enable,
			saturating	=> counter_zero_saturating
		);
	counter_one: entity work.COUNTER
		Generic map (
			COUNT => TO_PORT_ONE
		)
		Port map ( 
			clk => clk, rst	=> rst,
			enable 		=> counter_one_enable,
			saturating	=> counter_one_saturating
		);

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= PORT_ZERO;
			else
				state_curr <= STATE_NEXT;
			end if;
		end if;
	end process;
	
	output_0_data <= input_data;
	output_1_data <= input_data;
	
	comb: process(state_curr, output_0_ready, output_1_ready, input_valid, counter_zero_saturating, counter_one_saturating)
	begin
		state_next <= state_curr;
		counter_one_enable <= '0';
		counter_zero_enable <= '0';
		
		if state_curr = PORT_ZERO then
			input_ready <= output_0_ready;
			output_0_valid <= input_valid;
			output_1_valid <= '0';
			--check if a transaction is made
			if input_valid = '1' and output_0_ready = '1' then
				counter_zero_enable <= '1';
				if counter_zero_saturating = '1' then
					state_next <= PORT_ONE;
				end if;
			end if;
		elsif state_curr = PORT_ONE then
			input_ready <= output_1_ready;
			output_1_valid <= input_valid;
			output_0_valid <= '0';
			--check if a transaction is made
			if input_valid = '1' and output_1_ready = '1' then
				counter_one_enable <= '1';
				if counter_one_saturating = '1' then
					state_next <= PORT_ZERO;
				end if;
			end if;
		end if;
	end process;

end Behavioral;
