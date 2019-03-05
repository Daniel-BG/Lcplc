----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01.03.2019 09:54:32
-- Design Name: 
-- Module Name: power_of_two_signed_shifter - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Shift right a certain amount and, if negative, make sure it rounds 
--		towards zero instead of towards minus infinity
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

entity POWER_OF_TWO_SIGNED_SHIFTER is
	Generic (
		DATA_WIDTH: positive := 26;
		SHAMT: positive := 9
	);
	Port ( 
		input_data	: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_ready : out std_logic;
		input_valid : in  std_logic;
		output_data	: out std_logic_vector(DATA_WIDTH - SHAMT - 1 downto 0);
		output_ready: in  std_logic;
		output_valid: out std_logic
	);
end POWER_OF_TWO_SIGNED_SHIFTER;

architecture Behavioral of POWER_OF_TWO_SIGNED_SHIFTER is
	signal overflow: boolean; 

	signal input_data_shifted, input_data_shifted_plus_one: std_logic_vector(DATA_WIDTH - SHAMT - 1 downto 0);
begin

	input_ready <= output_ready;
	output_valid <= input_valid;

	overflow <= input_data(SHAMT - 1 downto 0) /= (SHAMT - 1 downto 0 => '0') and input_data(input_data'high) = '1';
	input_data_shifted 			<= input_data(input_data'high downto SHAMT);
	input_data_shifted_plus_one <= std_logic_vector(signed(input_data_shifted) + to_signed(1, input_data_shifted_plus_one'length));
	output_data <= input_data_shifted when not overflow else input_data_shifted_plus_one;

end Behavioral;
