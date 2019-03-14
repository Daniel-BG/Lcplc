----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 14.02.2019 12:54:33
-- Design Name: 
-- Module Name: AXIS_DIVERTER - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Divert input samples. One will go through port zero, and then 
--		through port one until input_last is asserted.
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

entity AXIS_DIVERTER is
	Generic (
		DATA_WIDTH: integer := 16
	);
	Port ( 
		clk, rst: in std_logic;
		--to input axi port
		input_valid		: in	std_logic;
		input_ready		: out	std_logic;
		input_data		: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_last_zero	: in 	std_logic;
		input_last_one	: in 	std_logic;
		--to output axi ports
		output_0_valid	: out 	std_logic;
		output_0_ready	: in 	std_logic;
		output_0_data	: out	std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_1_valid	: out 	std_logic;
		output_1_ready	: in 	std_logic;
		output_1_data	: out	std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end AXIS_DIVERTER;

architecture Behavioral of AXIS_DIVERTER is
	type separator_state_t is (PORT_ZERO, PORT_ONE);
	signal state_curr, state_next: separator_state_t;
	
begin
	output_0_data <= input_data;
	output_1_data <= input_data;

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
	
	comb: process(state_curr, output_0_ready, output_1_ready, input_valid, input_last_zero, input_last_one)
	begin
		state_next <= state_curr;
		
		if state_curr = PORT_ZERO then
			input_ready <= output_0_ready;
			output_0_valid <= input_valid;
			output_1_valid <= '0';
			--check if a transaction is made
			if input_valid = '1' and output_0_ready = '1' then
				if input_last_zero = '1' then
					state_next <= PORT_ONE;
				end if;
			end if;
		elsif state_curr = PORT_ONE then
			input_ready <= output_1_ready;
			output_1_valid <= input_valid;
			output_0_valid <= '0';
			--check if a transaction is made
			if input_valid = '1' and output_1_ready = '1' then
				if input_last_one = '1' then
					state_next <= PORT_ZERO;
				end if;
			end if;
		end if;
	end process;

end Behavioral;
