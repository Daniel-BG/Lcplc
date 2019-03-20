----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 15.02.2019 09:28:59
-- Design Name: 
-- Module Name: exp_zero_golomb - Behavioral
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
use work.functions.all;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity EXP_ZERO_GOLOMB is
	Generic (
		DATA_WIDTH: integer := 19
	);
	Port (
		clk, rst			: in 	std_logic;
		input_data			: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_valid			: in	std_logic;
		input_ready			: out	std_logic;
		output_code			: out	std_logic_vector(DATA_WIDTH*2 downto 0);
		output_length		: out	std_logic_vector(bits(DATA_WIDTH) downto 0); -- natural range 0 to DATA_WIDTH*2+1;
		output_valid		: out	std_logic;
		output_ready		: in 	std_logic
	);
end EXP_ZERO_GOLOMB;

architecture Behavioral of EXP_ZERO_GOLOMB is
	signal input_plus_one: std_logic_vector(DATA_WIDTH downto 0);
	
	signal final_bit_count: natural range 0 to DATA_WIDTH;
	
	
	
	--registration
	signal enable: std_logic;
	
	signal input_plus_one_buf: std_logic_vector(DATA_WIDTH downto 0);
	signal input_buf_full: std_logic;
	
	signal output_code_buf: std_logic_vector(DATA_WIDTH*2 downto 0);
	signal output_length_buf: std_logic_vector(bits(DATA_WIDTH) downto 0);
	signal output_buf_full: std_logic;
begin

	input_plus_one <= std_logic_vector(unsigned("0" & input_data) + to_unsigned(1, DATA_WIDTH+1));
	
	get_bit_cnt: process(input_plus_one_buf)
	begin
		for i in DATA_WIDTH downto 0 loop
			final_bit_count <= 1;
			if input_plus_one_buf(i) = '1' then
				final_bit_count <= i;
				exit;
			end if;
		end loop;
	end process;
	
	seq: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				output_buf_full <= '0';
			elsif enable = '1' then
				input_buf_full    <= input_valid;
				input_plus_one_buf<= input_plus_one;
			
				output_buf_full   <= input_buf_full;
				output_code_buf   <= (DATA_WIDTH*2 downto DATA_WIDTH + 1 => '0') & input_plus_one_buf;
				output_length_buf <= std_logic_vector(to_unsigned(final_bit_count, output_length'length - 1)) & '1';
			end if;
		end if;
	end process;
	
	output_code <= output_code_buf; --(DATA_WIDTH*2 downto DATA_WIDTH + 1 => '0') & input_plus_one;
	output_valid <= output_buf_full; --input_valid;
	output_length <= output_length_buf; --std_logic_vector(to_unsigned(final_bit_count, output_length'length));

	enable <= '1' when output_buf_full = '0' or output_ready = '1' else '0';
	input_ready <= enable;


	--add 1 to input_data (unsigned)
	--count its number of bits n
	--white n-1 zeroes and then write input_data+1 with n bits
end Behavioral;
