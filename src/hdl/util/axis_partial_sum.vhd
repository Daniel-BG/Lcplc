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
use IEEE.NUMERIC_STD.ALL;

entity AXIS_PARTIAL_SUM is
	Generic (
		INPUT_WIDTH_LOG		: integer := 6;		    --max accepted input value
		COUNTER_WIDTH_LOG	: integer := 7;			--counter width
		RESET_VALUE			: integer := 2**7-1;	--reset value
		IS_ADD				: boolean := false		--true if the counter adds the input_shift, false if it substracts it
	);
	Port (
		clk, rst		: in  std_logic;
		input_data		: in  std_logic_vector(INPUT_WIDTH_LOG - 1 downto 0);
		input_valid		: in  std_logic;
		input_ready		: out std_logic;
		output_data 	: out std_logic_vector(COUNTER_WIDTH_LOG - 1 downto 0);
		output_valid	: out std_logic;
		output_ready	: in  std_logic
	);
end AXIS_PARTIAL_SUM;

architecture Behavioral of AXIS_PARTIAL_SUM is
	signal inner_accumulator, inner_accumulator_next: std_logic_vector(COUNTER_WIDTH_LOG - 1 downto 0); 
begin

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				inner_accumulator <= std_logic_vector(to_unsigned(RESET_VALUE, COUNTER_WIDTH_LOG));
			elsif input_valid = '1' and output_ready = '1' then
				inner_accumulator <= inner_accumulator_next;
			end if;	
		end if;
	end process;
	
	output_valid <= input_valid;
	input_ready  <= output_ready;
	output_data  <= inner_accumulator;
	
	gen_sub: if not IS_ADD generate
		inner_accumulator_next <= std_logic_vector(unsigned(inner_accumulator) - resize(unsigned(input_data), COUNTER_WIDTH_LOG));	
	end generate;

	gen_add: if IS_ADD generate
		inner_accumulator_next <= std_logic_vector(unsigned(inner_accumulator) + resize(unsigned(input_data), COUNTER_WIDTH_LOG));	
	end generate;



end Behavioral;
