----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 24.10.2017 10:26:39
-- Design Name: 
-- Module Name: MQCoder - Behavioral
-- Project Name: Jypec
-- Target Devices: 
-- Tool Versions: 
-- Description: MQ-arithmetic coder. Has internal states for different contexts with
--		the aim of modelling a custom probability for each one, making compression 
--		more efficient. Context generator goes outside
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
use work.JypecConstants.all;

use STD.textio.all;
use ieee.std_logic_textio.all;



--MQCODER entity. No generics, can keep coding forever
entity MQCoder is
	port(
		--control signals
		clk, rst, clk_en: in std_logic;
		--bit to code
		in_bit: in std_logic;
		--flag to end coding and output remaining bits
		end_coding_enable: in std_logic;
		--context with which this is coding
		in_context: in context_label_t;
		--while coding two bytes suffice, but with 3 we can do the final cleanup in one cycle
		out_bytes: out std_logic_vector(23 downto 0);
		--individually enable first, second and third byte. 
		--By design out_en(2) implies out_en(1) implies out_en(0)	
		out_enable: out std_logic_vector(2 downto 0);
		--debug signals
		out_debug: out std_logic_vector(7 downto 0)
	);
end MQCoder;

architecture Behavioral of MQCoder is
	--47 different states
	subtype state_t is natural range 0 to 46;
	--probability table type. Has a prediction (0 or 1) and a state (0 to 46)
	type probability_table_t is record
		prediction: std_logic;
		state: state_t;
	end record probability_table_t; 
	--probability table for all contexts
	type state_table_t is array(0 to 18) of probability_table_t;  

	--constant values shared amongst MQCoder instances
	type transition_t is array(0 to 46) of state_t;
	constant SIGMA_MPS: transition_t := 		
		(1, 2, 3, 4, 5, 38, 7, 8, 9, 10, 
		11, 12, 13, 29, 15, 16, 17, 18, 19, 20, 
		21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 
		31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 
		41, 42, 43, 44, 45, 45, 46);
	
	constant SIGMA_LPS: transition_t := 
		(1, 6, 9, 12, 29, 33, 6, 14, 14, 14, 
		17, 18, 20, 21, 14, 14, 15, 16, 17, 18, 
		19, 19, 20, 21, 22, 23, 24, 25, 26, 27, 
		28, 29, 30, 31, 32, 33, 34, 35, 36, 37,
		38, 39, 40, 41, 42, 43, 46);
		
	type xor_switch_t is array(0 to 46) of std_logic;
	constant X_S: xor_switch_t := 		
		('1', '0', '0', '0', '0', '0', '1', '0', '0', '0', 
		'0', '0', '0', '0', '1', '0', '0', '0', '0', '0',
		'0', '0', '0', '0', '0', '0', '0', '0', '0', '0',
		'0', '0', '0', '0', '0', '0', '0', '0', '0', '0',
		'0', '0', '0', '0', '0', '0', '0');
	
	subtype probability_t is natural range 0 to 2**16-1;
	type probability_estimate_t is array(0 to 46) of probability_t;
	constant P_ESTIMATE: probability_estimate_t :=
		(22017, 13313, 6145, 2753, 1313,  545,   22017, 21505, 18433, 14337, 
		 12289, 9217,  7169, 5633, 22017, 21505, 20737, 18433, 14337, 13313, 
		 12289, 10241, 9217, 8705, 7169,  6145,  5633,  5121,  4609,  4353, 
		 2753,  2497,  2209, 1313, 1089,  673,   545,   321,   273,   133, 
		 73,    37,    21,   9,    5,     1,     22017);
		 
	constant SHIFTED_P_ESTIMATE: probability_estimate_t :=
		(44034, 53252, 49160, 44048, 42016, 34880, 44034, 43010, 36866, 57348,
		 49156, 36868, 57352, 45064, 44034, 43010, 41474, 36866, 57348, 53252,
		 49156, 40964, 36868, 34820, 57352, 49160, 45064, 40968, 36872, 34824,
		 44048, 39952, 35344, 42016, 34848, 43072, 34880, 41088, 34944, 34048,
		 37376, 37888, 43008, 36864, 40960, 32768, 44034);
		 
	subtype number_of_shifts_t is natural range 0 to 15;
	type probability_estimate_shift_t is array(0 to 46) of number_of_shifts_t;
	constant P_ESTIMATE_SHIFT: probability_estimate_shift_t :=
		(1,	2,	3,	4,	5,	6,	1,	1,	1,	2,	
		 2,	2,	3,	3,	1,	1,	1,	1,	2,	2,	
		 2,	2,	2,	2,	3,	3,	3,	3,	3,	3,	
		 4,	4,	4,	5,	5,	6,	6,	7,	7,	8,	
		 9,	10,	11,	12,	13,	15,	1);

	
		 	 
	constant STATE_TABLE_DEFAULT: state_table_t := 
		(('0', 4), ('0', 0), ('0', 0), ('0', 0), ('0', 0), ('0', 0), ('0', 0), ('0', 0), ('0', 0), ('0', 0), 
		 ('0', 0), ('0', 0), ('0', 0), ('0', 0), ('0', 0), ('0', 0), ('0', 0), ('0', 3), ('0', 46));
		 

	signal state_table: state_table_t;
	
	--A
	signal normalized_interval_length: unsigned(15 downto 0);
	--C
	signal normalized_lower_bound: unsigned(27 downto 0);
	--T
	signal temp_byte_buffer: unsigned(7 downto 0);
	--t bar
	subtype countdown_timer_t is natural range 0 to 12;
	signal countdown_timer: countdown_timer_t;
	--L
	subtype bytes_generated_t is natural range 0 to 2**16-1;
	--the number of bytes generated is equal to this variable minus one and yes, 
	--it starts at -1 to offset the initial empty bits of the C register
	signal bytes_generated_plus_one: bytes_generated_t; 
	
	
	--debug purposes
	signal probability_watcher: std_logic_vector(15 downto 0);
	signal hit_watcher: std_logic;
	signal num_shifts_watcher: std_logic_vector(3 downto 0);
	
	file out_file, out_file_prob : text;
	constant out_file_name: string := "out_CXD_old.bin";
	constant out_file_name_prob: string := "out_probhit_old.bin";
	
	
begin


	out_debug <= in_bit & std_logic_vector(to_unsigned(in_context, 7)); --normalized_lower_bound(7 downto 0));

	--this process updates the coder. Usually shifting is done to the normalized lower bound
	--until it goes over the normalized interval length. This can happen a bounded number of
	--times (14), and in at most two of those a byte is output. This process precalculates
	--that number, and then does the outputting in only one cycle, by shifting twice a variable
	--number of bits. This complicates the underlying circuit, but allows for faster 
	--compression
	--You should be familiar with the mq coding process first to understand how this works
	--(can be checked at https://github.com/Daniel-BG/Jypec in the MQCoder class), this is
	--basically a hardware translation of that software
	update_mqcoder: process(rst, clk, clk_en)
		variable current_table: probability_table_t;
		variable original_prediction: std_logic;
		variable normalized_probability: probability_t;
		variable next_normalized_interval: unsigned(15 downto 0);
		variable next_normalized_lower_bound: unsigned(27 downto 0);
		variable next_countdown_timer: countdown_timer_t;
		variable next_temp_byte_buffer: unsigned(7 downto 0);
		variable next_bytes_generated: bytes_generated_t;
		variable number_of_shifts: natural range 0 to 15 := 0;
		variable temp_shift: natural range 0 to 8 := 0;
		
		
		--last for variables
		variable full_byte: std_logic;
		--output values are zero unless otherwise specified.
		--thus, the output holds up for only one cycle before being erased when
		--mq_enable is up
		variable next_output_bytes: std_logic_vector(23 downto 0) := (others => '0');
		variable next_output_enable: std_logic_vector(2 downto 0) := (others => '0');
		
		--spetial encoding vars
		variable n_bits: integer range -7 to 12 := 0;
	begin
		if (rst = '1') then
			normalized_interval_length <= to_unsigned(32768, 16);
			normalized_lower_bound <= (others => '0');
			temp_byte_buffer <= (others => '0');
			countdown_timer <= 12;
			bytes_generated_plus_one <= 0;
			state_table <= STATE_TABLE_DEFAULT;
			out_bytes <= (others => '0');
			out_enable <= (others => '0');
		elsif (rising_edge(clk) and clk_en = '1') then
			--debug
--			if (rising_edge(clk)) then
--				report "MQCoder state debug: "
--					& "(A, C, T, tbar) -> " & integer'image(to_integer(unsigned(normalized_interval_length))) & ", "   
--					& integer'image(to_integer(unsigned(normalized_lower_bound))) & ", "
--					& integer'image(to_integer(unsigned(temp_byte_buffer))) & ", "
--					& countdown_timer_t'image(countdown_timer)
--				& " Coder: (bin, cin, enable) -> "
--					& std_logic'image(in_bit) & "," 
--					& context_label_t'image(in_context) & "," 
--					& std_logic'image(clk_en) & "," & LF;
--			end if;
			
			
			--read stuff
			current_table := state_table(in_context);
			normalized_probability := P_ESTIMATE(current_table.state);
			original_prediction := current_table.prediction;
			next_countdown_timer := countdown_timer;
			next_temp_byte_buffer := temp_byte_buffer;
			next_bytes_generated := bytes_generated_plus_one;
			next_normalized_lower_bound := normalized_lower_bound;
			next_normalized_interval := normalized_interval_length;
			number_of_shifts := 0;
			temp_shift := 0;
			next_output_bytes := (others => '0');
			next_output_enable := (others => '0');
			--CODE--
			
			--adjust prediction
			next_normalized_interval := next_normalized_interval - normalized_probability;
			if (next_normalized_interval < normalized_probability) then
				if (original_prediction = '1') then
					original_prediction := '0';
				else
					original_prediction := '1';
				end if;
			end if;
			
			--adjust interval			
			probability_watcher <= (others => '0');-----------------------
			if (in_bit = original_prediction) then
				probability_watcher <= std_logic_vector(to_unsigned(normalized_probability, 16));-----------------------
				hit_watcher <= '1';-----------------
				next_normalized_lower_bound := next_normalized_lower_bound + normalized_probability;
				--only three posibilities. Nothing, renorm once or renorm twice
				if (next_normalized_interval(15) = '1') then
					number_of_shifts := 0;
					next_normalized_interval := next_normalized_interval;
				elsif (next_normalized_interval(14) = '1') then
					number_of_shifts := 1;
					next_normalized_interval := next_normalized_interval(14 downto 0) & '0';
				else
					number_of_shifts := 2;
					next_normalized_interval := next_normalized_interval(13 downto 0) & "00";
				end if;
			else
				hit_watcher <= '0'; ------------------------
				next_normalized_interval := to_unsigned(SHIFTED_P_ESTIMATE(current_table.state), 16);
				number_of_shifts := P_ESTIMATE_SHIFT(current_table.state);
			end if;
			num_shifts_watcher <= std_logic_vector(to_unsigned(number_of_shifts, 4)); ---------------------
			
			--change state
			if (number_of_shifts /= 0) then
				if (in_bit = current_table.prediction) then
					current_table.state := SIGMA_MPS(current_table.state);
				else
					if (X_S(current_table.state) = '1') then
						if (current_table.prediction = '1') then
							current_table.prediction := '0';
						else
							current_table.prediction := '1';
						end if;
					end if;
					current_table.state := SIGMA_LPS(current_table.state);
				end if;
			end if;
			
			--at most three shifts
			for i in 0 to 2 loop
				--shift
				if (number_of_shifts > 0) then
					--shift max possible quantity
					temp_shift := number_of_shifts;
					if (temp_shift > next_countdown_timer) then
						temp_shift := next_countdown_timer;
					end if;
					--update results
					next_normalized_lower_bound := shift_left(next_normalized_lower_bound, temp_shift);
					next_countdown_timer := next_countdown_timer - temp_shift;
					number_of_shifts := number_of_shifts - temp_shift;
				else
					exit;
				end if;
				
				if i = 2 then
					exit; --outputting is only done twice
				end if;
				
				--if byte is to be output, output it
				if (next_countdown_timer = 0) then
					full_byte := '1';
					if (next_temp_byte_buffer = "11111111") then
						full_byte := '0';
					else
						next_temp_byte_buffer := next_temp_byte_buffer + ("0000000" & next_normalized_lower_bound(27));
						next_normalized_lower_bound := '0' & next_normalized_lower_bound(26 downto 0);
						if (next_temp_byte_buffer = "11111111") then
							full_byte := '0';
						end if;
					end if;
					if (next_bytes_generated /= 0) then
						next_output_enable := next_output_enable(1 downto 0) & '1';
						next_output_bytes := next_output_bytes(15 downto 0) & std_logic_vector(next_temp_byte_buffer);
					end if;
					next_bytes_generated := next_bytes_generated + 1;
					--updateafterbyte
					if (full_byte = '1') then
						next_temp_byte_buffer := next_normalized_lower_bound(26 downto 19);
						next_normalized_lower_bound := next_normalized_lower_bound(27) & "00000000" & next_normalized_lower_bound(18 downto 0);
						next_countdown_timer := 8;
					else
						next_temp_byte_buffer := next_normalized_lower_bound(27 downto 20);
						next_normalized_lower_bound := "00000000" & next_normalized_lower_bound(19 downto 0);
						next_countdown_timer := 7;
					end if;	
				end if;
			
			end loop;
			
			--need to output the last bits of this thing
			--basically output tempbytebuffer plus the first (and maybe second) bytes of the normalized lower bound, taking care that
			--a 0xff does not appear
			if (end_coding_enable = '1') then
				n_bits := 12 - countdown_timer;
				next_output_bytes := (others => '0');
				next_temp_byte_buffer := temp_byte_buffer; 
				next_output_enable := "000";
				next_normalized_lower_bound := normalized_lower_bound;
				next_countdown_timer := countdown_timer;
				next_bytes_generated := bytes_generated_plus_one;
				
				for i in 0 to 2 loop
					if (next_bytes_generated /= 0) then --just in case do not enable if we have yet to output a bit
						next_output_enable := next_output_enable(1 downto 0) & '1';
					end if;
					next_bytes_generated := next_bytes_generated + 1;
					next_normalized_lower_bound := shift_left(next_normalized_lower_bound, next_countdown_timer);
						
					if (next_temp_byte_buffer = "11111111") then
						next_output_bytes := next_output_bytes(15 downto 0) & std_logic_vector(next_temp_byte_buffer);
						next_temp_byte_buffer := next_normalized_lower_bound(27 downto 20);
						next_normalized_lower_bound := "00000000" & next_normalized_lower_bound(19 downto 0);
						next_countdown_timer := 7;
					else
						next_temp_byte_buffer := next_temp_byte_buffer + ("0000000" & next_normalized_lower_bound(27));
						next_normalized_lower_bound := '0' & next_normalized_lower_bound(26 downto 0);
						next_output_bytes := next_output_bytes(15 downto 0) & std_logic_vector(next_temp_byte_buffer);
						if (next_temp_byte_buffer = "11111111") then
							next_temp_byte_buffer := next_normalized_lower_bound(27 downto 20);
							next_normalized_lower_bound := "00000000" & next_normalized_lower_bound(19 downto 0);
							next_countdown_timer := 7;
						else
							next_temp_byte_buffer := next_normalized_lower_bound(26 downto 19);
							next_normalized_lower_bound := next_normalized_lower_bound(27) & "00000000" & next_normalized_lower_bound(18 downto 0);
							next_countdown_timer := 8;
						end if;
					end if;
					--end loop when there are no more bits (delayed by one cycle)
					if (n_bits <= 0) then
						exit;
					end if;
					n_bits := n_bits - next_countdown_timer;
				end loop;

			end if;
			
			--assign back variables to signals!
			state_table(in_context) <= current_table;
			normalized_interval_length <= next_normalized_interval;
			normalized_lower_bound <= next_normalized_lower_bound;
			countdown_timer <= next_countdown_timer;
			temp_byte_buffer <= next_temp_byte_buffer;
			bytes_generated_plus_one <= next_bytes_generated;
			out_bytes <= next_output_bytes;
			out_enable <= next_output_enable;
		end if;
	end process update_mqcoder;
	
	

	debug_process: process
		variable out_line: line;
	begin
		file_open(out_file, out_file_name, write_mode);
		--write until finished
		while true loop
			wait until rising_edge(clk);
			if (clk_en = '1') then
				write(out_line, in_context, right, 2);
				write(out_line, " ", right, 1);
				write(out_line, in_bit, right, 1);
				writeline(out_file, out_line);
			end if;
		end loop;
	end process;
	
	debug_process_prob: process
		variable out_line: line;
	begin
		file_open(out_file_prob, out_file_name_prob, write_mode);
		--write until finished
		while true loop
			wait until rising_edge(clk);
			if (clk_en = '1' and (hit_watcher = '1' or num_shifts_watcher /= "0000") and hit_watcher /= 'U') then
				write(out_line, probability_watcher, right, 16);
				write(out_line, " ", right, 1);
				write(out_line, num_shifts_watcher, right, 4);
				write(out_line, " ", right, 1);
				write(out_line, hit_watcher, right, 1);
				writeline(out_file_prob, out_line);
			end if;
		end loop;
	end process;


end Behavioral;



--code below is how it was defined at first before optimizations took place, contains a for loop of 14 iterations instead of the 3 required now

--			--renormalization shift
--			for i in 0 to 14 loop --need to set for the max possible number of iterations
--				--if finished, stop doing stuff
--				if (next_normalized_interval < 32768) then
--					exit;
--				end if;
--				--do stuff
--				next_normalized_interval := next_normalized_interval(14 downto 0) & '0';
--				next_normalized_lower_bound := next_normalized_lower_bound(26 downto 0) & '0'; 
--				next_countdown_timer := next_countdown_timer - 1;
--				if (next_countdown_timer = 0) then
--					full_byte := '1';
--					if (next_temp_byte_buffer = "11111111") then
--						full_byte := '0';
--					else
--						next_temp_byte_buffer := next_temp_byte_buffer + ("0000000" & next_normalized_lower_bound(27));
--						next_normalized_lower_bound := '0' & next_normalized_lower_bound(26 downto 0);
--						if (next_temp_byte_buffer = "11111111") then
--							full_byte := '0';
--						end if;
--					end if;
--					if (next_bytes_generated /= 0) then
--						if (first_byte_output = '0') then
--							first_byte_output := '1';
--							next_output_bytes(7 downto 0) := std_logic_vector(next_temp_byte_buffer);
--						else
--							second_byte_output := '1';
--							next_output_bytes(15 downto 8) := next_output_bytes(7 downto 0);
--							next_output_bytes(7 downto 0) := std_logic_vector(next_temp_byte_buffer);
--						end if;
--						--output tempByteBuffer
--					end if;
--					next_bytes_generated := next_bytes_generated + 1;
--					--updateafterbyte
--					if (full_byte = '1') then
--						next_temp_byte_buffer := next_normalized_lower_bound(26 downto 19);
--						next_normalized_lower_bound := next_normalized_lower_bound(27) & "00000000" & next_normalized_lower_bound(18 downto 0);
--						next_countdown_timer := 8;
--					else
--						next_temp_byte_buffer := next_normalized_lower_bound(27 downto 20);
--						next_normalized_lower_bound := "00000000" & next_normalized_lower_bound(19 downto 0);
--						next_countdown_timer := 7;
--					end if;
--				end if; 
--			end loop;