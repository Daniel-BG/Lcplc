----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:14:12 06/08/2018 
-- Design Name: 
-- Module Name:    BPC_output_controller - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description:  take the 11 CxD pair array and serialize it to a FIFO queue.
-- 	It works by checking all valid bits and emitting the associated CxD pairs that have it enabled.
--		After retrieving an array, it first looks at the first pair (valid or not) while it sets a pointer 
--		To the next valid one (so it enters stream mode after 1 cycle). If all remaining pairs are invalid,
--		it immediately queries the next one.
--		So basically, 1 cycle if the array is empty. Then for any array with n valid CxD pairs it takes
--		n cycles if the first pair is valid, and n+1 if not.
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
use work.JypecConstants.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

use STD.textio.all;
use ieee.std_logic_textio.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity BPC_output_controller is
	generic (
		DEBUG: boolean := false
	);
	port (
		clk, rst: in std_logic;
		in_contexts: in BPC_out_contexts_t;
		in_bits: in BPC_out_bits_t;
		in_valid: in BPC_out_valid_t;
		in_available: in std_logic;
		out_full: in std_logic;
		in_request: out std_logic;
		out_context: out context_label_t;
		out_symbol: out std_logic;
		out_valid: out std_logic;
		out_idle: out std_logic			--indicate if this module is doing any processing or if it is idle
	);
end BPC_output_controller;

architecture Behavioral of BPC_output_controller is
	type serializer_state_t is (IDLE, EMIT_FIRST, STREAM);
	signal state_curr, state_next: serializer_state_t;

	
	signal counter, next_counter, first_counter, last_counter, following_counter: natural range 0 to 10;
	
	signal out_context_i: context_label_t;
	signal out_symbol_i: std_logic;
	signal out_valid_i: std_logic;
	
	--debug purposes
	file out_file : text;
	constant out_file_name: string := "out_CXD_bpc.bin";

begin

	out_symbol <= out_symbol_i;
	out_context <= out_context_i;
	out_valid <= out_valid_i;
	out_idle <= '1' when state_curr = IDLE else '0';

	first_counter <=		0 when in_valid(0) = '1' else
								1 when in_valid(1) = '1' else
								2 when in_valid(2) = '1' else
								3 when in_valid(3) = '1' else
								4 when in_valid(4) = '1' else
								5 when in_valid(5) = '1' else
								6 when in_valid(6) = '1' else
								7 when in_valid(7) = '1' else
								8 when in_valid(8) = '1' else
								9 when in_valid(9) = '1' else
								10;
								
	last_counter <=		10 when in_valid(10) = '1' else
								9 when in_valid(9) = '1' else	
								8 when in_valid(8) = '1' else	
								7 when in_valid(7) = '1' else	
								6 when in_valid(6) = '1' else	
								5 when in_valid(5) = '1' else	
								4 when in_valid(4) = '1' else	
								3 when in_valid(3) = '1' else	
								2 when in_valid(2) = '1' else	
								1 when in_valid(1) = '1' else	
								0;

	--go to next valid byte
	following_counter <=	1 when counter < 1 and in_valid(1) = '1' else
								2 when counter < 2 and in_valid(2) = '1' else
								3 when counter < 3 and in_valid(3) = '1' else
								4 when counter < 4 and in_valid(4) = '1' else
								5 when counter < 5 and in_valid(5) = '1' else
								6 when counter < 6 and in_valid(6) = '1' else
								7 when counter < 7 and in_valid(7) = '1' else
								8 when counter < 8 and in_valid(8) = '1' else
								9 when counter < 9 and in_valid(9) = '1' else
								10;
								
	fsm_update: process(clk, rst)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				counter <= 0;
				state_curr <= IDLE;
			else
				counter <= next_counter;
				state_curr <= state_next;
			end if;
		end if;
	end process;
												
								
	fsm_serialize: process(state_curr, in_available, first_counter, last_counter, 
		following_counter, in_contexts, in_bits, in_valid, out_full, counter)
	begin
		in_request <= '0';
		state_next <= state_curr;
		out_context_i <= CONTEXT_ZERO;
		out_symbol_i <= '0';
		out_valid_i <= '0';
		next_counter <= counter;
	
		case state_curr is
			when IDLE =>
				next_counter <= 0;
				if (in_available = '1' and out_full = '0') then
					in_request <= '1';
					state_next <= EMIT_FIRST;
				end if;
			when EMIT_FIRST =>
				if (out_full = '0') then
					out_context_i <= in_contexts(first_counter);
					out_symbol_i <= in_bits(first_counter);
					out_valid_i <= in_valid(first_counter);
					--if only one symbol is present
					if (first_counter = last_counter) then
						--then directly ask for the next array if possible
						--otherwise idle
						if (in_available = '1') then
							in_request <= '1';
							state_next <= EMIT_FIRST;
						else
							state_next <= IDLE;
						end if;
					else
						--stream the next symbols
						state_next <= STREAM;
						next_counter <= first_counter;
					end if;
				end if;
			when STREAM =>
				if (out_full = '0') then
					out_context_i <= in_contexts(following_counter);
					out_symbol_i <= in_bits(following_counter);
					out_valid_i <= in_valid(following_counter);
					--if only one symbol is present
					if (following_counter = last_counter) then
						--then directly ask for the next array if possible
						--otherwise idle
						if (in_available = '1') then
							in_request <= '1';
							state_next <= EMIT_FIRST;
						else
							state_next <= IDLE;
						end if;
					else
						--stream the next symbols
						state_next <= STREAM;
						next_counter <= following_counter;
					end if;
				end if;
		end case;
	end process;
	
	gen_debug: if DEBUG generate
		debug_process: process
			variable out_line: line;
		begin
			file_open(out_file, out_file_name, write_mode);
			--write until finished
			while true loop
				wait until rising_edge(clk);
				if (out_valid_i = '1') then
					write(out_line, out_context_i, right, 2);
					write(out_line, " ", right, 1);
					write(out_line, out_symbol_i, right, 1);
					writeline(out_file, out_line);
				end if;
			end loop;
		end process;
	end generate;
	


end Behavioral;

