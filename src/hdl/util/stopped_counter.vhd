----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 22.02.2019 16:04:50
-- Design Name: 
-- Module Name: STOPPED_COUNTER - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Counter with multiple stops, producing a flag on each
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
use work.data_types.all;
use work.functions.all;

entity STOPPED_COUNTER is
	Generic (
		STOPS: array_of_integers := (121, 235, 323, 498, 528, 619, 749)
	);
	Port ( 
		clk, rst	: in  std_logic;
		enable		: in  std_logic;
		saturating	: out std_logic_vector(stops'length-1 downto 0)
	);
end STOPPED_COUNTER;

architecture Behavioral of STOPPED_COUNTER is
	constant UPPER_LIMIT: integer := sum(STOPS);
	constant NUM_STOPS: integer := STOPS'length;


	signal counter: natural range 0 to UPPER_LIMIT - 1;
	signal saturating_in: std_logic_vector(NUM_STOPS - 1 downto 0);
begin

	saturating <= saturating_in;

	gen_flags: for i in 0 to NUM_STOPS - 1 generate
		comb: process(counter) begin
			if counter = partsum(STOPS, i+1) - 1 then
				saturating_in(i) <= '1';
			else
				saturating_in(i) <= '0';
			end if;
		end process;
	end generate;

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				counter <= 0;
			elsif enable = '1' then
				if counter = UPPER_LIMIT - 1 then
					counter <= 0;
				else
					counter <= counter + 1;
				end if;
			end if;
		end if;
	end process;

end Behavioral;
