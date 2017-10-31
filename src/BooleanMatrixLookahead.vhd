----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.10.2017 15:02:52
-- Design Name: 
-- Module Name: BooleanMatrixLookahead - Behavioral
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

entity BooleanMatrixLookahead is
	generic (
		SIZE: integer := 4096;
		LOOKAHEAD: integer := 3
	);
	port (
		clk: in std_logic;
		rst: in std_logic;
		clk_en: in std_logic;
		in_value: in std_logic;
		out_values: out std_logic_vector(LOOKAHEAD downto 0) --most significant is oldest value, next are newer ones
	);
end BooleanMatrixLookahead;

architecture Behavioral of BooleanMatrixLookahead is
	constant MAX_INDEX: integer := SIZE - 2 - LOOKAHEAD;

	type storage_t is array(0 to MAX_INDEX) of std_logic;
	signal storage: storage_t;
	
	signal index: natural range 0 to MAX_INDEX;
	
	signal shiftreg: std_logic_vector(LOOKAHEAD - 1 downto 0);
	signal mem_out: std_logic;

begin


	out_values <= shiftreg & mem_out;
	
	update: process(clk, rst, clk_en) 
	begin
		if (rst = '1') then
			index <= 0;
		elsif (rising_edge(clk) and clk_en = '1') then
			mem_out <= storage(index);
			shiftreg <= shiftreg(LOOKAHEAD - 2 downto 0) & mem_out;
			storage(index) <= in_value;
			if (index = MAX_INDEX) then
				index <= 0;
			else
				index <= index + 1;
			end if;
		end if;
	end process;


end Behavioral;
