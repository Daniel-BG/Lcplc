----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 21.02.2019 09:32:49
-- Design Name: 
-- Module Name: SHIFT_REG - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Put some data of DATA_WIDTH bits and retrieve it DEPTH clks later
--			does not work with DEPTH<=1
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

entity SHIFT_REG is
	Generic (
		DATA_WIDTH: integer := 16;
		DEPTH: integer := 16
	);
	Port (
		clk, enable: in std_logic;
		input: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		output: out std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end SHIFT_REG;

architecture Behavioral of SHIFT_REG is
	constant LIMIT: integer := DEPTH - 2;
	
	type memory_t is array(0 to LIMIT) of std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal memory: memory_t;
	
	signal counter: natural range 0 to LIMIT;
	
	signal output_reg: std_logic_vector(DATA_WIDTH - 1 downto 0);
begin

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if enable = '1' then
				output_reg <= memory(counter);
				memory(counter) <= input;
				if counter = LIMIT then
					counter <= 0;
				else
					counter <= counter + 1;
				end if;
			end if;
		end if;
	end process;

	output <= output_reg;



end Behavioral;
