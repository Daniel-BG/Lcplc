----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06.06.2018 10:52:16
-- Design Name: 
-- Module Name: BPC_mem - Behavioral
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

entity BPC_mem is
	generic (
		WIDTH: integer := 64;
		STRIPS: integer := 16;
		BIT_DEPTH: integer := 16
	);
	Port ( 
		rst, clk, clk_en : in std_logic;
		input: in std_logic_vector(BIT_DEPTH*4 - 1 downto 0);
		input_loc: in natural range 0 to WIDTH*STRIPS - 1;
		input_en: in std_logic;
		s0, s1, s2, s3: out std_logic_vector(BIT_DEPTH - 1 downto 0)
	);
end BPC_mem;

architecture Behavioral of BPC_mem is

	type memtype is array(0 to WIDTH*STRIPS - 1) of std_logic_vector(4*BIT_DEPTH - 1 downto 0);
	
	signal mem: memtype;
	
	signal pointer: natural range 0 to WIDTH*STRIPS - 1;
	
	signal memout: std_logic_vector(4*BIT_DEPTH - 1 downto 0);

begin

	s0 <= memout(4*BIT_DEPTH - 1 downto 3*BIT_DEPTH);
	s1 <= memout(3*BIT_DEPTH - 1 downto 2*BIT_DEPTH);
	s2 <= memout(2*BIT_DEPTH - 1 downto 1*BIT_DEPTH);
	s3 <= memout(  BIT_DEPTH - 1 downto 0          );

	gen_proc: process(clk, rst, clk_en, input, input_loc, input_en) 
	begin
		if rising_edge(clk) then
			if (rst = '1') then
				pointer <= 0;
			elsif (clk_en = '1') then
				memout <= mem(pointer);
				if (pointer = WIDTH*STRIPS - 1) then
					pointer <= 0;
				else
					pointer <= pointer + 1;
				end if;
			end if;
			if (input_en = '1') then
				mem(input_loc) <= input;
			end if;
		end if;
	end process;

end Behavioral;
