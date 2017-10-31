----------------------------------------------------------------------------------
-- Company:º 
-- Engineer: 
-- 
-- Create Date: 24.10.2017 10:26:39
-- Design Name: 
-- Module Name: MQCoder - Behavioral
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
use work.JypecConstants.all;

entity MQCoder is
	port(
		clk, rst, clk_en: in std_logic;
		in_bit: in std_logic;
		end_coding_enable: in std_logic;
		in_context: in context_label_t;
		out_bytes: out std_logic_vector(23 downto 0);	--while coding two bytes suffice, but with 3 we can do the final cleanup in one cycle
		out_enable: out std_logic_vector(2 downto 0) 	--individually enable first and second and third byte. By design out_en(2) implies out_en(1) implies out_en(0)
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
	
	
begin


	update_mqcoder: process(rst, clk, clk_en)
		variable current_table: probability_table_t;
		variable original_prediction: std_logic;
		variable normalized_probability: probability_t;
		variable next_normalized_interval: unsigned(15 downto 0);
		variable temp_next_normalized_interval: unsigned(15 downto 0);
		variable next_normalized_lower_bound: unsigned(27 downto 0);
		variable next_countdown_timer: countdown_timer_t;
		variable next_temp_byte_buffer: unsigned(7 downto 0);
		variable next_bytes_generated: bytes_generated_t;
		variable number_of_shifts: natural range 0 to 14 := 0;
		variable temp_shift: natural range 0 to 8 := 0;
		
		
		--last for variables
		variable full_byte: std_logic;
		variable next_output_bytes: std_logic_vector(23 downto 0) := (others => '0');
		variable next_output_enable: std_logic_vector(2 downto 0);
		
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
		elsif (rising_edge(clk) and clk_en = '1') then
			--read stuff
			current_table := state_table(in_context);
			normalized_probability := P_ESTIMATE(current_table.state);
			original_prediction := current_table.prediction;
			next_countdown_timer := countdown_timer;
			next_temp_byte_buffer := temp_byte_buffer;
			--CODE--
			
			--adjust prediction
			next_normalized_interval := normalized_interval_length - normalized_probability;
			if (next_normalized_interval < normalized_probability) then
				if (original_prediction = '1') then
					original_prediction := '0';
				else
					original_prediction := '1';
				end if;
			end if;
			--adjust interval
			if (in_bit = original_prediction) then
				next_normalized_lower_bound := normalized_lower_bound + normalized_probability;
			else
				next_normalized_lower_bound := to_unsigned(normalized_probability, 28);
			end if;
			
			--change state
			if (next_normalized_interval < 32768) then
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
					current_table.state := SIGMA_MPS(current_table.state);
				end if;
			end if;
			
			--get number of shifts
			temp_next_normalized_interval := next_normalized_interval;
			for i in 0 to 13 loop
				if (temp_next_normalized_interval < 32768) then
					exit;
				end if;
				temp_next_normalized_interval := temp_next_normalized_interval(14 downto 0) & '0';
				number_of_shifts := number_of_shifts + 1;
			end loop;
			
			--at most three shifts
			for i in 0 to 2 loop
				--shift
				if (number_of_shifts > 0) then
					--shift max possible quantity
					temp_shift := number_of_shifts;
					if (next_countdown_timer < number_of_shifts) then
						temp_shift := next_countdown_timer;
					end if;
					--update results
					next_normalized_interval := shift_left(next_normalized_interval, temp_shift);
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
				next_bytes_generated := bytes_generated_plus_one;
				next_output_enable := "000";
				
				for i in 0 to 2 loop
					next_bytes_generated := next_bytes_generated + 1;
					next_output_enable := next_output_enable(1 downto 0) & '1';
						
					if (next_temp_byte_buffer = "11111111") then
						next_output_bytes := next_output_bytes(15 downto 0) & std_logic_vector(next_temp_byte_buffer);
						next_temp_byte_buffer := next_normalized_lower_bound(27 downto 20);
						next_normalized_lower_bound := "00000000" & next_normalized_lower_bound(19 downto 0);
						next_countdown_timer := 7;
					else
						next_temp_byte_buffer := next_temp_byte_buffer + 1;
						next_normalized_lower_bound := '0' & next_normalized_lower_bound(26 downto 0);
						next_output_bytes := next_output_bytes(15 downto 0) & std_logic_vector(next_temp_byte_buffer);
						if (next_temp_byte_buffer = "11111111") then
							next_temp_byte_buffer := next_normalized_lower_bound(26 downto 19);
							next_normalized_lower_bound := next_normalized_lower_bound(27) & "00000000" & next_normalized_lower_bound(18 downto 0);
							next_countdown_timer := 8;
						else
							next_temp_byte_buffer := next_normalized_lower_bound(27 downto 20);
							next_normalized_lower_bound := "00000000" & next_normalized_lower_bound(19 downto 0);
							next_countdown_timer := 7;
						end if;
					end if;
				
					--end loop when there are no more bits
					if (n_bits <= 0) then
						exit;
					end if;
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
	end process;


end Behavioral;



--code below is how it was defined at first before optimizations took place

--			--renormalization shift
--			for i in 0 to 13 loop --need to set for the max possible number of iterations
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