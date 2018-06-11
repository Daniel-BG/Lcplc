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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity BPC_output_controller is
	port (
		clk, rst, clk_en: in std_logic;
		in_contexts: in BPC_out_contexts_t;
		in_bits: in BPC_out_bits_t;
		in_valid: in BPC_out_valid_t;
		in_available: in std_logic;
		out_full: in std_logic;
		in_request: out std_logic;
		out_context: out context_label_t;
		out_symbol: out std_logic;
		out_valid: out std_logic
	);
end BPC_output_controller;

architecture Behavioral of BPC_output_controller is

	signal counter, next_counter, next_counter_first, next_counter_after: natural range 0 to 11;
	signal outputting: std_logic;
	signal all_invalid: std_logic;

begin

	all_invalid <= '1' when	in_valid(0) = '0' and in_valid(1) = '0' and in_valid(2) = '0' and in_valid(3) = '0' and 
									in_valid(4) = '0' and in_valid(5) = '0' and in_valid(6) = '0' and in_valid(7) = '0' and 
									in_valid(8) = '0' and in_valid(9) = '0' and in_valid(10) = '0' 
								else '0';

	--go to next valid byte
	next_counter <=		1 when counter < 1 and in_valid(1) = '1' else
								2 when counter < 2 and in_valid(2) = '1' else
								3 when counter < 3 and in_valid(3) = '1' else
								4 when counter < 4 and in_valid(4) = '1' else
								5 when counter < 5 and in_valid(5) = '1' else
								6 when counter < 6 and in_valid(6) = '1' else
								7 when counter < 7 and in_valid(7) = '1' else
								8 when counter < 8 and in_valid(8) = '1' else
								9 when counter < 9 and in_valid(9) = '1' else
								10;


	serialize: process(clk, rst, clk_en)
	begin
		if (rising_edge(clk)) then
			--defaults
			in_request <= '0';
			out_context <= CONTEXT_ZERO;
			out_symbol <= '0';
			out_valid <= '0';
			
			--change state and output
			if (rst = '1') then
				counter <= 0;
				outputting <= '0';
			elsif (clk_en = '1') then
				if (outputting = '0') then
					--if data is available, change to outputting mode
					if (in_available = '1') then
						in_request <= '1';
						outputting <= '1';
					end if;
				else
					--try outputting if output queue is not full
					if (out_full = '0') then
						out_context <= in_contexts(counter);
						out_symbol <= in_bits(counter);
						out_valid <= in_valid(counter); --doesnt matter if we output an invalid one, it will just not be processed
						--check if we have output all
						if (counter = 10) then
							counter <= 0;
							outputting <= '0';
							--we were gonna reset, might as well retrieve new data now
							if (in_available = '1') then
								in_request <= '1';
								outputting <= '1';
							end if;
						else
							counter <= next_counter;
						end if;
					end if;
					--skip this batch if all invalid
					if (all_invalid = '1') then
						counter <= 0;
						outputting <= '0';
						--we were gonna reset, might as well retrieve new data now
						if (in_available = '1') then
							in_request <= '1';
							outputting <= '1';
						end if;
					end if;
				end if;
			end if;
		end if;
	
	end process;


end Behavioral;

