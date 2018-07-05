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
		--control signals
		clk, rst: in std_logic;
		--data input
		data_in: in std_logic_vector(BIT_DEPTH - 1 downto 0);
		--data input is available
		data_in_en: in std_logic;
		--data output is requested
		data_out_en: in std_logic;
		--data output
		data_out: out std_logic_vector(BIT_DEPTH * 4 - 1 downto 0);
		--flag to signal if the next data_out_en will produce new data or not. 
		--passing data_out_en = '1' when data_out_available will NOT change 
		--the inner state
		data_out_available: out std_logic
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
			res(i) := std_logic_vector(to_unsigned((i*PRIME) mod (2**BIT_DEPTH), BIT_DEPTH));
		end loop;
		return res;
	end gen_rom;
	--------------------------------------------------------------------
	
	
	signal memory: mem_t;-- := gen_rom;
	
	signal index_out, index_in: natural range 0 to ROWS * COLS - 1;
	signal all_input: std_logic;
	
	signal shift_reg: std_logic_vector(BIT_DEPTH * 4 - 1 downto 0);
	signal data_available: std_logic;
begin
	
	data_out <= shift_reg;
	data_out_available <= data_available;
	
	--static calcualtion
	data_available <= '1' when index_in > index_out or all_input = '1' else '0';

	--update memory output
	update_output: process(clk, rst, data_out_en) begin
		if (rst = '1') then
			index_out <= 0;
			shift_reg <= (others => '0');		
		--check if data is available
		elsif(rising_edge(clk) and data_out_en = '1') then
			if (data_available = '1') then 
				--update output
				if (index_out = ROWS * COLS - 1) then
					index_out <= 0;
				else 
					index_out <= index_out + 1;
				end if;
				shift_reg <= shift_reg(BIT_DEPTH * 3 - 1 downto 0) & memory(index_out);
			end if;
		end if;
	end process;
	
	--update memory input
	update_input: process(clk, rst, data_in_en, all_input) begin
		if (rst = '1') then
			index_in <= 0;
			all_input <= '0';		
		elsif(rising_edge(clk) and data_in_en = '1' and all_input = '0') then
			--check for bounds 
			--update input (if necessary)
			memory(index_in) <= data_in;
			if (index_in = ROWS * COLS - 1) then
				all_input <= '1'; --stop updating
			else
				index_in <= index_in + 1;
			end if;
		end if;
	end process;
	

end Behavioral;
