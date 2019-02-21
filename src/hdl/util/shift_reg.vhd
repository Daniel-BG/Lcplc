----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 21.02.2019 09:32:49
-- Design Name: 
-- Module Name: SHIFT_REG - Behavioral
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
	type memory_t is array(0 to DEPTH - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal memory: memory_t;
	
	signal counter: natural range 0 to DEPTH - 1;
	
	signal output_reg: std_logic_vector(DATA_WIDTH - 1 downto 0);
begin

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if enable = '1' then
				output_reg <= memory(counter);
				memory(counter) <= input;
				if counter = DEPTH - 1 then
					counter <= 0;
				else
					counter <= counter + 1;
				end if;
			end if;
		end if;
	end process;

	output <= output_reg;



end Behavioral;
