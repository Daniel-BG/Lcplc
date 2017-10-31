----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel
-- 
-- Create Date: 23.10.2017 15:02:52
-- Design Name: 
-- Module Name: BooleanMatrixLookahead - Behavioral
-- Project Name: Vypec
-- Target Devices: 
-- Tool Versions: 
-- Description: FIFO storage for std_logic values 
--		with the possibility of peeking ahead in the queue
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

entity BooleanMatrixLookahead is
	generic (
		--total size of the queue
		SIZE: integer := 4096;
		--number of samples we want to look ahead for
		LOOKAHEAD: integer := 3
	);
	port (
		--control signals
		clk, rst, clk_en: in std_logic;
		--input value
		in_value: in std_logic;
		--output value (current in MSB, next and subsequent follow)
		out_values: out std_logic_vector(LOOKAHEAD downto 0) 
	);
end BooleanMatrixLookahead;

architecture Behavioral of BooleanMatrixLookahead is
	--memory size
	constant MAX_INDEX: integer := SIZE - 2 - LOOKAHEAD;
	
	--memory and index signals
	type storage_t is array(0 to MAX_INDEX) of std_logic;
	signal storage: storage_t;
	signal index: natural range 0 to MAX_INDEX;
	
	--shift register for looking ahead
	signal shiftreg: std_logic_vector(LOOKAHEAD - 1 downto 0);
	--memory out
	signal mem_out: std_logic;

begin

	--string together the shift register and memory output
	out_values <= shiftreg & mem_out;
	
	--read next value, shift exisiting ones, and save current input
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
