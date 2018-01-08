----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel
-- 
-- Create Date: 23.10.2017 15:02:52
-- Design Name: 
-- Module Name: BooleanMatrix - Behavioral
-- Project Name: Vypec
-- Target Devices: 
-- Tool Versions: 
-- Description: FIFO for boolean values
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

entity BooleanMatrix is
	generic (
		--FIFO size
		SIZE: integer := 4096
	);
	port (
		--control signals
		clk, rst, clk_en: in std_logic;
		--value to be added to the FIFO
		in_value: in std_logic;
		--value being read from the FIFO
		out_value: out std_logic
	);
end BooleanMatrix;


architecture Behavioral of BooleanMatrix is
	--custom type for the memory signal. The size is one less than
	--the number of values stored since one is always registered 
	--at the clocked output	
	type storage_t is array(0 to SIZE - 2) of std_logic;
	--memory and index.
	signal storage: storage_t;
	signal index: natural range 0 to SIZE - 2;
begin

	--write the input value in the current position, which gets overwriten,
	--and update the pointer to the next one
	update: process(clk, rst, clk_en) 
	begin
		if (rst = '1') then
			index <= 0;
			out_value <= '0';
		elsif (rising_edge(clk) and clk_en = '1') then
			out_value <= storage(index);
			storage(index) <= in_value;
			if (index = SIZE - 2) then
				index <= 0;
			else
				index <= index + 1;
			end if;
		end if;
	end process;

end Behavioral;
