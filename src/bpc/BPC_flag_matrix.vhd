----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:47:23 06/06/2018 
-- Design Name: 
-- Module Name:    BPC_flag_matrix - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
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

entity BPC_flag_matrix is
	generic (
		--FIFO size
		SIZE: integer := 1024;
		WIDTH: integer := 4
	);
	port (
		--control signals
		clk, rst, clk_en: in std_logic;
		--value to be added to the FIFO
		in_value: in std_logic_vector(WIDTH - 1 downto 0);
		--value being read from the FIFO
		out_value: out std_logic_vector(WIDTH - 1 downto 0)
	);
end BPC_flag_matrix;


architecture Behavioral of BPC_flag_matrix is
	--custom type for the memory signal. The size is one less than
	--the number of values stored since one is always registered 
	--at the clocked output	
	type storage_t is array(0 to SIZE - 2) of std_logic_vector(WIDTH - 1 downto 0);
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
			out_value <= (others => '0');
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
