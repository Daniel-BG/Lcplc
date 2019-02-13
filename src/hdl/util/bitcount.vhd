----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11.02.2019 10:30:52
-- Design Name: 
-- Module Name: bitcount - Behavioral
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

entity BITCOUNT is
	Generic (
		DATA_WIDTH: positive := 32;
		COUNTER_WIDTH: positive := 6 --make this ceil(log2(DATA_WIDTH) + 1) 
	);
	Port (
		data: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		bitcount: out std_logic_Vector(COUNTER_WIDTH - 1 downto 0)
	);
end BITCOUNT;

architecture Behavioral of BITCOUNT is
	constant zeroes: unsigned(COUNTER_WIDTH - 2 downto 0) := (others => '0');
begin

	calc: process(data)	
		variable a: unsigned(COUNTER_WIDTH - 1 downto 0);
	begin
		a := (others => '0');
		for i in 0 to DATA_WIDTH - 1 loop
			a := unsigned(a) + (zeroes & data(i));
		end loop;
		bitcount <= std_logic_vector(a);
	end process;


end Behavioral;
