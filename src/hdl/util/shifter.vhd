----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01.03.2019 09:54:32
-- Design Name: 
-- Module Name: shifter - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Barrel shifter
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

entity shifter is
	Generic (
		DATA_WIDTH: positive := 80;
		MAX_SHAMT: positive := 31;
		LEFT: boolean := false;
		ARITHMETIC: boolean := false
	);
	Port ( 
		clk, rst: in std_logic;
		input_data	: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_shift	: in  natural range 0 to MAX_SHAMT;
		output_data	: out std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end shifter;

architecture Behavioral of shifter is
	signal input_data_delay , input_data_delay_delay : std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal input_shift_delay: natural range 0 to MAX_SHAMT;
begin

	seq: process(clk)
	begin
		if rising_edge(clk) then
			input_data_delay <= input_data;
			input_shift_delay <= input_shift;
			if LEFT then
				input_data_delay_delay <= std_logic_vector(shift_left(unsigned(input_data_delay), input_shift_delay));
			else
				if ARITHMETIC then
					input_data_delay_delay <= std_logic_vector(shift_right(signed(input_data_delay), input_shift_delay));
				else
					input_data_delay_delay <= std_logic_vector(shift_right(unsigned(input_data_delay), input_shift_delay));
				end if;
			end if;
		end if;
	end process;

	output_data <= input_data_delay_delay;
	
--	left_shift: if LEFT generate
--		output_data <= std_logic_vector(shift_left(unsigned(input_data), input_shift));
--	end generate;
--
--	right_shift: if not LEFT generate
--		right_shift_arith: if ARITHMETIC generate
--			output_data <= std_logic_vector(shift_right(signed(input_data), input_shift));
--		end generate;
--		right_shift_logic: if not ARITHMETIC generate
--			output_data <= std_logic_vector(shift_right(unsigned(input_data), input_shift));
--		end generate;
--	end generate;

end Behavioral;
