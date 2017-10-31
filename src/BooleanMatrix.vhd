----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.10.2017 15:02:52
-- Design Name: 
-- Module Name: BooleanMatrix - Behavioral
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

entity BooleanMatrix is
	generic (
		SIZE: integer := 4096
	);
	port (
		clk: in std_logic;
		rst: in std_logic;
		clk_en: in std_logic;
		in_value: in std_logic;
		out_value: out std_logic
	);
end BooleanMatrix;

architecture Behavioral of BooleanMatrix is
--	type storage_t is array(0 to 1023) of std_logic;
--	signal storage: storage_t;

	type storage_t is array(0 to SIZE - 2) of std_logic;
	signal storage: storage_t;
	
	signal index: natural range 0 to SIZE - 2;

begin

--	rst_proc: process(clk, rst)
--	begin
--		if (rst = '1') then
--			for i in 0 to 1023 loop 
--				storage(i) <= '0';
--			end loop;
--			out_value <= '0';
--		elsif (rising_edge(clk) and clk_en = '1') then
--			out_value <= storage(0);
--			for i in 0 to 1022 loop 
--				storage(i) <= storage(i + 1);
--			end loop;
--			storage(1023) <= in_value;
--		end if;
--	end process;
	
	update: process(clk, rst, clk_en) 
	begin
		if (rst = '1') then
			index <= 0;
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
