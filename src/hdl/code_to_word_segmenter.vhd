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

--up to DATA_WIDTH bits can come in the input vector
--at least 1 is used in the first cycle, and then they are used
--in groups of up to 2**WORD_WIDTH_LOG
--so if D_WIDTH = 39 it can take up to 3 cycles. 
--the WORD_CNT_SLACK is needed to be able to know how many cycles we need to
--spend on each input since we shift by 2**WORD_WIDTH_LOG each time.
--the input_quantity tells us where we are, and a 2-bit counter keeps track
entity CODE_TO_WORD_SEGMENTER is
	Generic (
		DATA_WIDTH: integer := 39;
		WORD_WIDTH_LOG: integer := 5;
		WORD_CNT_SLACK: integer := 2
	);
	Port (
		clk, rst		: in	std_logic;
		input_data		: in 	std_logic_vector(DATA_WIDTH - 1 + 2**WORD_WIDTH_LOG - 1 downto 0);
		input_quantity	: in	std_logic_vector(WORD_WIDTH_LOG + WORD_CNT_SLACK - 1 downto 0);
		input_ready		: out	std_logic;
		input_valid		: in	std_logic;
		output_data		: out 	std_logic_vector(2**WORD_WIDTH_LOG - 1 downto 0);
		output_ends_word: out 	std_logic;
		output_ready	: in	std_logic;
		output_valid	: out	std_logic;
		has_data_buffered:out	std_logic
	);
end CODE_TO_WORD_SEGMENTER;

architecture Behavioral of CODE_TO_WORD_SEGMENTER is
	type state_segmenter_t is (WORKING, BUFFERED);
	signal state_curr, state_next: state_segmenter_t;

	signal inner_counter, inner_counter_next: std_logic_vector(WORD_CNT_SLACK - 1 downto 0);
	
	signal input_data_buff, input_data_buff_next: std_logic_vector(DATA_WIDTH - 1 - 1 downto 0); -- -1 since 1 is always at least lost in first cycle so we don't need it
	signal input_quantity_buff, input_quantity_buff_next: std_logic_vector(WORD_WIDTH_LOG + WORD_CNT_SLACK - 1 downto 0);
	
begin

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= WORKING;
				inner_counter <= (others => '0');
				input_data_buff <= (others => '0');
				input_quantity_buff <= (others => '0');
			else
				state_curr <= state_next;
				inner_counter <= inner_counter_next;
				input_data_buff <= input_data_buff_next;
				input_quantity_buff <= input_quantity_buff_next;
			end if;
		end if;
	end process;
	

	has_data_buffered <= '1' when state_curr = BUFFERED else '0';
	
	comb: process(state_curr, input_quantity_buff, input_data_buff, inner_counter, input_valid, output_ready, input_data, input_quantity)
	begin
		output_ends_word <= '0';
		input_quantity_buff_next <= input_quantity_buff;
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
				if input_quantity(input_quantity'high downto input_quantity'high - WORD_CNT_SLACK + 1) = inner_counter then
					if input_quantity(WORD_WIDTH_LOG - 1 downto 0) = (WORD_WIDTH_LOG - 1 downto 0 => '0') then
						output_ends_word <= '1';
						inner_counter_next <= std_logic_vector(unsigned(inner_counter) - to_unsigned(1, inner_counter'length));
					else
						--do nothing special
					end if;
				else
					output_ends_word <= '1';
					inner_counter_next <= std_logic_vector(unsigned(inner_counter) - to_unsigned(1, inner_counter'length));
					input_quantity_buff_next <= input_quantity;
					input_data_buff_next <= input_data(input_data'high - 2**WORD_WIDTH_LOG downto 0);
					state_next <= BUFFERED;
				end if;
			end if;
		elsif state_curr = BUFFERED then
			output_valid <= '1';
			output_data <= input_data_buff(input_data_buff'high downto input_data_buff'high - 2**WORD_WIDTH_LOG + 1);
			
			if output_ready = '1' then
				if input_quantity_buff(input_quantity_buff'high downto input_quantity_buff'high - WORD_CNT_SLACK + 1) = inner_counter then
					state_next <= WORKING;
					if input_quantity_buff(WORD_WIDTH_LOG - 1 downto 0) = (WORD_WIDTH_LOG - 1 downto 0 => '0') then
						output_ends_word <= '1';
						inner_counter_next <= std_logic_vector(unsigned(inner_counter) - to_unsigned(1, inner_counter'length));
					else
						--do nothing special
					end if;
				else
					output_ends_word <= '1';
					inner_counter_next <= std_logic_vector(unsigned(inner_counter) - to_unsigned(1, inner_counter'length));
					input_quantity_buff_next <= input_quantity_buff;
					input_data_buff_next <= input_data_buff(input_data_buff'high - 2**WORD_WIDTH_LOG downto 0) & (2**WORD_WIDTH_LOG - 1 downto 0 => '0');
				end if;
			end if;
		end if;
	
	end process;
	
	


end Behavioral;
