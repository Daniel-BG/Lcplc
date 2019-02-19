----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.02.2019 10:30:57
-- Design Name: 
-- Module Name: ACCUMULATED_SHIFTAMT_CALC - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ACCUMULATED_SHIFTAMT_CALC is
	Generic (
		INPUT_WIDTH: integer := 39;
		OUTPUT_WIDTH_LOG: integer := 5;
		--this value should be big enough to distinguish overflows when adding INPUT_WIDTH to a counter
		--of OUTPUT_WIDTH_LOG bits
		OUTPUT_WIDTH_SLACK: integer := 2
	);
	Port (
		clk, rst		: in	std_logic;
		input_shift		: in natural range 0 to INPUT_WIDTH;
		input_valid		: in std_logic;
		input_ready		: out std_logic;
		output_shift	: out std_logic_vector(OUTPUT_WIDTH_LOG + OUTPUT_WIDTH_SLACK - 1 downto 0);
		output_valid	: out std_logic;
		output_ready	: in std_logic
	);
end ACCUMULATED_SHIFTAMT_CALC;

architecture Behavioral of ACCUMULATED_SHIFTAMT_CALC is
	signal inner_accumulator, inner_accumulator_next: std_logic_vector(OUTPUT_WIDTH_LOG + OUTPUT_WIDTH_SLACK - 1 downto 0); 
begin

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				inner_accumulator <= std_logic_vector(to_unsigned(2**(OUTPUT_WIDTH_LOG + OUTPUT_WIDTH_SLACK) - 1, OUTPUT_WIDTH_LOG + OUTPUT_WIDTH_SLACK));
			elsif input_valid = '1' and output_ready = '1' then
				inner_accumulator <= inner_accumulator_next;
			end if;	
		end if;
	end process;
	
	output_valid <= input_valid;
	input_ready <= output_ready;
	output_shift <= inner_accumulator;
	
	inner_accumulator_next <= std_logic_vector(unsigned(inner_accumulator) - to_unsigned(input_shift, OUTPUT_WIDTH_LOG + OUTPUT_WIDTH_SLACK));	



end Behavioral;
