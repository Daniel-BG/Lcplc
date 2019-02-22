----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 22.02.2019 14:52:10
-- Design Name: 
-- Module Name: AXIS_HOLDER - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Holds a value until the clear signal is issued, then it holds nothing 
-- 		until it can retrieve another value
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

entity AXIS_HOLDER is
	Generic (
		DATA_WIDTH: integer := 16
	);
	Port (
		clk, rst		: in  std_logic;
		clear			: in  std_logic;
		input_ready		: out std_logic;
		input_valid		: in  std_logic;
		input_data		: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_ready	: in  std_logic;
		output_valid	: out std_logic;
		output_data		: out std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end AXIS_HOLDER;

architecture Behavioral of AXIS_HOLDER is
	signal buf: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal primed: boolean;
begin

	input_ready		<= '1' when not primed else '0';
	output_valid	<= '1' when 	primed else '0';
	
	output_data <= buf;

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				buf <= (others => '0');
				primed <= false;
			else
				if primed then
					if clear = '1' then
						primed <= false;
					end if;
				else
					if input_valid = '1' then
						primed <= true;
						buf <= input_data;
					end if;
				end if;
			end if;
		end if;
	end process;



end Behavioral;
