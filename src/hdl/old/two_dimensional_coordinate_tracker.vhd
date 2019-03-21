----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 21.02.2019 11:31:22
-- Design Name: 
-- Module Name: TWO_DIMENSIONAL_COORDINATE_TRACKER - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TWO_DIMENSIONAL_COORDINATE_TRACKER is
	Generic (
		X_SIZE: integer := 16;
		Y_SIZE: integer := 16
	);
	Port (
		clk, rst, enable: in std_logic;
		saturating: out std_logic;
		x_coord: out natural range 0 to X_SIZE - 1;
		y_coord: out natural range 0 to Y_SIZE - 1
	);
end TWO_DIMENSIONAL_COORDINATE_TRACKER;

architecture Behavioral of TWO_DIMENSIONAL_COORDINATE_TRACKER is
	signal x_counter: natural range 0 to X_SIZE - 1;
	signal y_counter: natural range 0 to Y_SIZE - 1;
begin
	saturating <= '1' when x_counter = X_SIZE - 1 and y_counter = Y_SIZE - 1 else '0';
	
	x_coord <= x_counter;
	y_coord <= y_counter;

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				x_counter <= 0;
				y_counter <= 0;
			elsif enable = '1' then
				if x_counter = X_SIZE - 1 then
					x_counter <= 0;
					if y_counter = Y_SIZE - 1 then
						y_counter <= 0;
					else
						y_counter <= y_counter + 1;
					end if;
				else
					x_counter <= x_counter + 1;
				end if;
			end if;
		end if;
	end process;


end Behavioral;
