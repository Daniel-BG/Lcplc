----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 18.02.2019 16:48:12
-- Design Name: 
-- Module Name: CODE_TO_WORD_SEGMENTER - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: This module is tasked with merging different outputs into the final 32-bit words.
--		The input is received as a pair (bits, position).
--			-bits: contain the raw bits. They are already aligned where they are 
--			supposed to be output (hence the extra 2**WWL-1 bits). The number of bits
--			to be output is variable, and will be determined by position.
--			-position: the lowest WWL bits contain the offset of the word (where
--			the valid bits start). The upper bits contain a counter indicating 
--			relative word count
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

--up to BASE_WIDTH bits can come in the input vector
--at least 1 is used in the first cycle, and then they are used
--in groups of up to 2**WORD_WIDTH_LOG
--so if B_WIDTH = 39 it can take up to 3 cycles. 
--the WORD_CNT_SLACK is needed to be able to know how many cycles we need to
--spend on each input since we shift by 2**WORD_WIDTH_LOG each time.
--the input_quantity tells us where we are, and a 2-bit counter keeps track
entity CODE_TO_WORD_SEGMENTER is
	Generic (
		BASE_WIDTH: integer := 39;
		WORD_WIDTH_LOG: integer := 5;
		WORD_CNT_SLACK: integer := 2
	);
	Port (
		clk, rst		: in	std_logic;
		bits_data		: in 	std_logic_vector(BASE_WIDTH - 1 + 2**WORD_WIDTH_LOG - 1 downto 0);
		bits_ready		: out	std_logic;
		bits_valid		: in	std_logic;
		position_data	: in	std_logic_vector(WORD_WIDTH_LOG + WORD_CNT_SLACK - 1 downto 0);
		position_ready	: out	std_logic;
		position_valid	: in 	std_logic;
		output_data		: out 	std_logic_vector(2**WORD_WIDTH_LOG - 1 downto 0);
		output_ends_word: out 	std_logic;
		output_ready	: in	std_logic;
		output_valid	: out	std_logic;
		has_data_buffered:out	std_logic
	);
end CODE_TO_WORD_SEGMENTER;

architecture Behavioral of CODE_TO_WORD_SEGMENTER is
	constant FULL_INPUT_WIDTH: integer := BASE_WIDTH + 2**WORD_WIDTH_LOG - 1;
	constant POSITION_WIDTH: integer := WORD_WIDTH_LOG + WORD_CNT_SLACK;

	--synchronizer
	signal input_valid, input_ready: std_logic;
	signal input_data: std_logic_vector(FULL_INPUT_WIDTH - 1 downto 0);
	signal input_position: std_logic_vector(POSITION_WIDTH - 1 downto 0);

	--others
	type state_segmenter_t is (WORKING, BUFFERED);
	signal state_curr, state_next: state_segmenter_t;

	signal inner_counter, inner_counter_next: std_logic_vector(WORD_CNT_SLACK - 1 downto 0);
	
	signal input_data_buff, input_data_buff_next: std_logic_vector(BASE_WIDTH - 1 - 1 downto 0); -- -1 since 1 is always at least lost in first cycle so we don't need it
	signal input_position_buff, input_position_buff_next: std_logic_vector(POSITION_WIDTH - 1 downto 0);
	
begin


	synchronizer: entity work.AXIS_SYNCHRONIZER_2
		Generic map (
			DATA_WIDTH_0 => FULL_INPUT_WIDTH,
			DATA_WIDTH_1 => POSITION_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			input_0_valid => bits_valid,
			input_0_ready => bits_ready,
			input_0_data  => bits_data,
			input_1_valid => position_valid,
			input_1_ready => position_ready,
			input_1_data  => position_data,
			--to output axi ports
			output_valid  => input_valid,
			output_ready  => input_ready,
			output_data_0 => input_data,
			output_data_1 => input_position
		);


	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= WORKING;
				inner_counter <= (others => '1'); --start @1 since that is how the partial sum starts
				input_data_buff <= (others => '0');
				input_position_buff <= (others => '1'); --start @1 since that is how the partial sum starts
			else
				state_curr <= state_next;
				inner_counter <= inner_counter_next;
				input_data_buff <= input_data_buff_next;
				input_position_buff <= input_position_buff_next;
			end if;
		end if;
	end process;
	

	has_data_buffered <= '1' when state_curr = BUFFERED else '0';
	
	comb: process(state_curr, input_position_buff, input_data_buff, inner_counter, input_valid, output_ready, input_data, input_position)
	begin
		output_ends_word <= '0';
		input_position_buff_next <= input_position_buff;
		input_data_buff_next <= input_data_buff;
		output_valid <= '0';
		input_ready <= '0';
		inner_counter_next <= inner_counter;
		state_next <= state_curr;
		
		if state_curr = WORKING then
			output_valid <= input_valid;
			input_ready <= output_ready;
			output_data <= input_data(input_data'high downto input_data'high - 2**WORD_WIDTH_LOG + 1);
			
			if input_valid = '1' and output_ready = '1' then
				if input_position(input_position'high downto input_position'high - WORD_CNT_SLACK + 1) = inner_counter then
					if input_position(WORD_WIDTH_LOG - 1 downto 0) = (WORD_WIDTH_LOG - 1 downto 0 => '0') then
						output_ends_word <= '1';
						inner_counter_next <= std_logic_vector(unsigned(inner_counter) - to_unsigned(1, inner_counter'length));
					else
						--do nothing special
					end if;
				else
					output_ends_word <= '1';
					inner_counter_next <= std_logic_vector(unsigned(inner_counter) - to_unsigned(1, inner_counter'length));
					input_position_buff_next <= input_position;
					input_data_buff_next <= input_data(input_data'high - 2**WORD_WIDTH_LOG downto 0);
					state_next <= BUFFERED;
				end if;
			end if;
		elsif state_curr = BUFFERED then
			output_valid <= '1';
			output_data <= input_data_buff(input_data_buff'high downto input_data_buff'high - 2**WORD_WIDTH_LOG + 1);
			
			if output_ready = '1' then
				if input_position_buff(input_position_buff'high downto input_position_buff'high - WORD_CNT_SLACK + 1) = inner_counter then
					state_next <= WORKING;
					if input_position_buff(WORD_WIDTH_LOG - 1 downto 0) = (WORD_WIDTH_LOG - 1 downto 0 => '0') then
						output_ends_word <= '1';
						inner_counter_next <= std_logic_vector(unsigned(inner_counter) - to_unsigned(1, inner_counter'length));
					else
						--do nothing special
					end if;
				else
					output_ends_word <= '1';
					inner_counter_next <= std_logic_vector(unsigned(inner_counter) - to_unsigned(1, inner_counter'length));
					input_position_buff_next <= input_position_buff;
					input_data_buff_next <= input_data_buff(input_data_buff'high - 2**WORD_WIDTH_LOG downto 0) & (2**WORD_WIDTH_LOG - 1 downto 0 => '0');
				end if;
			end if;
		end if;
	end process;

end Behavioral;


--output_overflow	<= input_data(input_data'high - 2**WORD_WIDTH_LOG downto max(input_data'high - 2*2**WORD_WIDTH_LOG + 1, 0))
--				& (max(input_data'high - 2*2**WORD_WIDTH_LOG + 1, 0) - 1 downto 0 => '0');