----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.02.2019 16:45:31
-- Design Name: 
-- Module Name: AXIS_AVERAGER_POW2 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Calculate the mean of a previously specified count of numbers
--		(that should be a power of two). NOTE: no checks are done in the module,
--		the signal input_last is supposed to be up with the Nth sample, where N
--		is the assumed power of two
-- 
-- Dependencies: AXIS_ACCUMULATOR to calculate the addition of all elements
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments: 
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity AXIS_AVERAGER_POW2 is
	Generic (
		DATA_WIDTH: integer := 36;
		COUNT_LOG: integer := 8;
		IS_SIGNED: boolean := true
	);
	Port (
		clk, rst: in std_logic;
		input_data	: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_valid	: in  std_logic;
		input_ready	: out std_logic;
		input_last	: in  std_logic;
		output_data	: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_valid: out std_logic;
		output_ready: in  std_logic
	);
end AXIS_AVERAGER_POW2;

architecture Behavioral of AXIS_AVERAGER_POW2 is
	signal output_tmp: std_logic_vector(DATA_WIDTH + COUNT_LOG - 1 downto 0);
begin

	accumulator: entity work.AXIS_ACCUMULATOR
		Generic map (
			DATA_WIDTH  => DATA_WIDTH,
			COUNT_LOG => COUNT_LOG,
			IS_SIGNED	=> IS_SIGNED
		)
		Port map (
			clk => clk, rst => rst,
			input_data => input_data,
			input_valid => input_valid,
			input_ready	=> input_ready,
			input_last  => input_last,
			output_data => output_tmp,
			output_valid => output_valid,
			output_ready => output_ready
		);
		
	output_data <= output_tmp(DATA_WIDTH + COUNT_LOG - 1 downto COUNT_LOG);

end Behavioral;
