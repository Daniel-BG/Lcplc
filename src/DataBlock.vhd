----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 25.10.2017 12:54:48
-- Design Name: 
-- Module Name: DataBlock - Behavioral
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
use ieee.numeric_std.all;

--temporary entity to module a memory block which should be loaded by a processor
entity DataBlock is
	generic (
		BIT_DEPTH: integer := 16;
		ROWS: integer := 64;
		COLS: integer := 64
	);
	port (
		clk, rst, clk_en: in std_logic;
		data: out std_logic_vector(BIT_DEPTH * 4 - 1 downto 0)
	);
end DataBlock;

architecture Behavioral of DataBlock is
	type mem_t is array(0 to ROWS * COLS - 1) of std_logic_vector(BIT_DEPTH - 1 downto 0);
	
	--------------------------------------------------------------------
	--For testing purposes, this is supposed to be loaded by a processor
	constant PRIME: integer := 9973; --for pseudo randomly generating numbers
	
	function gen_rom return mem_t is
		variable res: mem_t;
	begin
		for i in 0 to ROWS*COLS - 1 loop
			--choose a random prime number
			res(i) := std_logic_vector(to_unsigned((i*PRIME) mod (2**BIT_DEPTH - 1), BIT_DEPTH));
		end loop;
		return res;
	end gen_rom;
	--------------------------------------------------------------------
	
	
	signal memory: mem_t := gen_rom;
	
	signal index: natural range 0 to ROWS * COLS - 1;
	
	signal shift_reg: std_logic_vector(BIT_DEPTH * 4 - 1 downto 0);
begin
	
	data <= shift_reg;

	output: process(clk, rst, clk_en) begin
		if (rst = '1') then
			index <= 0;
			shift_reg <= (others => '0');			
		elsif(rising_edge(clk) and clk_en = '1') then
			if (index = ROWS * COLS - 1) then
				index <= 0;
			else 
				index <= index + 1;
			end if;
			shift_reg <= shift_reg(BIT_DEPTH * 3 - 1 downto 0) & memory(index);
		end if;
	end process;

end Behavioral;
