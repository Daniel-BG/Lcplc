----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 22.02.2019 16:04:50
-- Design Name: 
-- Module Name: COUNTER - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Simple counter to avoid declaring signals everywhere a counter
--		is used to keep track of a number.
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

entity COUNTER is
	Generic (
		COUNT: integer := 256
	);
	Port ( 
		clk, rst	: in  std_logic;
		enable		: in  std_logic;
		saturating	: out std_logic
	);
end COUNTER;

architecture Behavioral of COUNTER is
	signal counter: natural range 0 to COUNT - 1;
begin

	saturating <= '1' when counter = COUNT - 1 else '0';

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				counter <= 0;
			elsif enable = '1' then
				if counter = COUNT - 1 then
					counter <= 0;
				else
					counter <= counter + 1;
				end if;
			end if;
		end if;
	end process;


end Behavioral;
