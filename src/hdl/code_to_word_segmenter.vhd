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

entity CODE_TO_WORD_SEGMENTER is
	Generic (
		DATA_WIDTH: integer := 39;
		WORD_WIDTH_LOG: integer := 5
	);
	Port (
		clk, rst		: in	std_logic;
		input_data		: in 	std_logic_vector(DATA_WIDTH - 1 + 2**WORD_WIDTH_LOG - 1 downto 0);
		input_quantity	: in	natural range 0 to DATA_WIDTH;
		input_ready		: out	std_logic;
		input_valid		: in	std_logic;
		output_data		: out 	std_logic_vector(2**WORD_WIDTH_LOG - 1 downto 0);
		output_ends_word: out 	std_logic;
		output_ready	: in	std_logic;
		output_valid	: out	std_logic
	);
end CODE_TO_WORD_SEGMENTER;

architecture Behavioral of CODE_TO_WORD_SEGMENTER is
	type c2w_seg_t is (IDLE, BUFFERED);
	signal state_curr, state_next: c2w_seg_t;
	
	--buffers
	signal input_data_buff, input_data_buff_next: std_logic_vector(DATA_WIDTH - 1 + 2**WORD_WIDTH_LOG - 1 downto 0);
	signal input_quantity_buff, input_quantity_buff_next: natural range 0 to DATA_WIDTH + 2**WORD_WIDTH_LOG;
	
	--internal counters
	signal bit_counter, bit_counter_next: natural range 0 to 2**WORD_WIDTH_LOG; 
	signal bit_counter_lookahead, bit_counter_lookahead_next: natural range 0 to 2**WORD_WIDTH_LOG + DATA_WIDTH;
--	signal bit_counter_lookahead_a, bit_counter_lookahead_b, bit_counter_lookahead_c, bit_counter_lookahead_d: natural range 0 to 2**WORD_WIDTH_LOG + DATA_WIDTH;
--	signal bit_counter_la_sel: std_logic_vector(2 downto 0);
begin

	

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= IDLE;
				bit_counter <= 0;
				input_data_buff <= (others => '0');
				input_quantity_buff <= 0;
				bit_counter_lookahead <= 0;
			else
				state_curr <= state_next;
				bit_counter <= bit_counter_next;
				input_data_buff <= input_data_buff_next;
				input_quantity_buff <= input_quantity_buff_next;
				bit_counter_lookahead <= bit_counter_lookahead_next;
			end if;
		end if;
	end process;
			
	output_data <= input_data_buff(input_data_buff'high downto input_data'high - 2**WORD_WIDTH_LOG + 1);
	
	comb: process(state_curr, input_valid, input_data, input_quantity, bit_counter, output_ready, input_data_buff, input_quantity_buff, bit_counter_lookahead)
	begin
		
		input_ready <= '0';
		output_valid <= '0';
		output_ends_word <= '0';
		input_data_buff_next <= input_data_buff;
		input_quantity_buff_next <= input_quantity_buff;
		bit_counter_lookahead_next <= 0;		   
		state_next <= state_curr;
		bit_counter_next <= bit_counter;
		
		--bit_counter_la_sel <= "000";
		
		if state_curr = IDLE then
			input_ready <= '1';
			if input_valid = '1' then
				input_data_buff_next <= input_data;
				input_quantity_buff_next <= input_quantity;
				--bit_counter_la_sel <= "000";
				bit_counter_lookahead_next <= bit_counter + input_quantity;
				state_next <= BUFFERED;
			end if;
		elsif state_curr = BUFFERED then
			output_valid <= '1';
			if output_ready = '1' then
				if bit_counter_lookahead > 2**WORD_WIDTH_LOG then
					output_ends_word <= '1';
					bit_counter_next <= 0;
					--bit_counter_la_sel <= "001";
					bit_counter_lookahead_next <= bit_counter_lookahead - 2**WORD_WIDTH_LOG;
					input_data_buff_next <= input_data_buff(input_data_buff'high - 2**WORD_WIDTH_LOG downto 0) & (2**WORD_WIDTH_LOG - 1 downto 0 => '0');
				elsif bit_counter_lookahead = 2**WORD_WIDTH_LOG then
					output_ends_word <= '1';
					bit_counter_next <= 0;
					input_ready <= '1';
					if input_valid = '1' then
						--bit_counter_la_sel <= "010";
						bit_counter_lookahead_next <= input_quantity;
						input_data_buff_next <= input_data;
						input_quantity_buff_next <= input_quantity;
					else
						state_next <= IDLE;
					end if;
				else
					bit_counter_next <= bit_counter_lookahead;
					input_ready <= '1';
					if input_valid = '1' then
						--bit_counter_la_sel <= "011";
						bit_counter_lookahead_next <= bit_counter_lookahead + input_quantity;
						input_data_buff_next <= input_data;
						input_quantity_buff_next <= input_quantity;
					else
						state_next <= IDLE;
					end if; 
				end if;
			end if;
			
		end if;
		
	
	end process;
	
--	bit_counter_lookahead_a <= bit_counter + input_quantity;
--	bit_counter_lookahead_b <= bit_counter_lookahead - 2**WORD_WIDTH_LOG;
--	bit_counter_lookahead_c <= input_quantity;
--	bit_counter_lookahead_d <= bit_counter_lookahead + input_quantity;
	
--	bit_counter_lookahead_next_sel: process(
--		bit_counter_lookahead_a, bit_counter_lookahead_b, bit_counter_lookahead_c, bit_counter_lookahead_d,
--		bit_counter_la_sel,bit_counter_lookahead)
--	begin
--		if bit_counter_la_sel = "000" then
--			bit_counter_lookahead_next <= bit_counter_lookahead_a; 
--		elsif bit_counter_la_sel = "001" then
--			bit_counter_lookahead_next <= bit_counter_lookahead_b;
--		elsif bit_counter_la_sel = "010" then
--			bit_counter_lookahead_next <= bit_counter_lookahead_c;
--		elsif bit_counter_la_sel = "011" then
--			bit_counter_lookahead_next <= bit_counter_lookahead_d;
--		else
--			bit_counter_lookahead_next <= bit_counter_lookahead;
--		end if;
	
--	end process;
	


end Behavioral;
