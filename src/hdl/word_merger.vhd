----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.02.2019 10:18:12
-- Design Name: 
-- Module Name: WORD_MERGER - Behavioral
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

entity WORD_MERGER is
	Generic (
		WORD_WIDTH: integer := 32
	);
	Port (
		clk, rst		: in	std_logic;
		input_data		: in 	std_logic_vector(WORD_WIDTH-1 downto 0);
		input_ends_word : in	std_logic;
		input_valid		: in 	std_logic;
		input_ready		: out	std_logic;
		input_last 		: in 	std_logic;
		output_data		: out	std_logic_vector(WORD_WIDTH-1 downto 0);
		output_valid	: out	std_logic;
		output_ready	: in 	std_logic;
		output_last		: out 	std_logic
	);
end WORD_MERGER;

architecture Behavioral of WORD_MERGER is
	signal data_buf, data_buf_next: std_logic_vector(WORD_WIDTH-1 downto 0);

	signal data_buf_full, data_buf_full_next: std_logic;
	signal data_buf_last, data_buf_last_next: std_logic;

	signal output_valid_in, input_ready_in: std_logic;
	
begin
	
	seq: process(clk)
	begin
		if rising_Edge(clk) then
			if rst = '1' then
				data_buf <= (others => '0');
				data_buf_full <= '0';
				data_buf_last <= '0';
			else
				data_buf <= data_buf_next;
				data_buf_full <= data_buf_full_next;
				data_buf_last <= data_buf_last_next;
			end if;
		end if;
	end process;

	
	output_valid_in <= data_buf_full;
	output_valid 	<= output_valid_in;
	input_ready_in  <= '1' when data_buf_full = '0' or output_ready = '1' else '0';
	input_ready  	<= input_ready_in;
	output_last     <= data_buf_last;
	output_data		<= data_buf;

	calc_next: process(output_valid_in, input_ready_in, output_ready, input_valid,
		data_buf, data_buf_full, data_buf_last, input_data, input_last, input_ends_word)
	begin
		--defaults
		data_buf_next <= data_buf;
		data_buf_full_next <= data_buf_full;
		data_buf_last_next <= data_buf_last;
		--
		if output_valid_in = '1' and output_ready = '1' and input_ready_in = '1' and input_valid = '1' then
			data_buf_next <= input_data;
			data_buf_last_next <= input_last;
			data_buf_full_next <= input_ends_word or input_last;
		elsif output_valid_in = '1' and output_ready = '1' then
			data_buf_next <= (data_buf_next'range => '0');
			data_buf_last_next <= '0';
			data_buf_full_next <= '0';
		elsif input_ready_in = '1' and input_valid = '1' then
			data_buf_next <= data_buf or input_data;
			data_buf_last_next <= data_buf_last or input_last;
			data_buf_full_next <= data_buf_full or input_ends_word or input_last;
		end if;
	end process;

end Behavioral;
