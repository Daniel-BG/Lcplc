----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01.12.2017 11:37:02
-- Design Name: 
-- Module Name: SignificanceNeighFilter - Behavioral
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

use work.JypecConstants.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity SignificanceNeighFilter is
	generic (
		ROWS: integer := 64;
		COLS: integer := 64
	);
	port (
		raw_neighborhood: in sign_neighborhood_t;
		row: in natural range 0 to ROWS - 1;
		col: in natural range 0 to COLS - 1;
		first_cleanup_pass_flag: in std_logic; 
		current_significance: out significance_state_t;
		neighborhood: out neighborhood_3x3_t;
		run_length_neighborhood: out run_length_neighborhood_t
	);
--  Port ( );
end SignificanceNeighFilter;

architecture Behavioral of SignificanceNeighFilter is

begin

	--create current significance
	current_significance <= raw_neighborhood.curr_c when first_cleanup_pass_flag = '0' else INSIGNIFICANT;

	--from the input neighborhood (which includes tons of useless data)
	--extract the exact 3x3 neighborhood of the current sample
	extract_neighborhood: process(raw_neighborhood, row, col, first_cleanup_pass_flag) 
	begin
		--assign top
		if (row = 0) then
			neighborhood.top <= INSIGNIFICANT;
		elsif (row mod 4 = 0) then
			neighborhood.top <= raw_neighborhood.prev_p3;
		else
			neighborhood.top <= raw_neighborhood.curr_m1;
		end if;
		
		--assign top left
		if (row = 0 or col = 0) then
			neighborhood.top_left <= INSIGNIFICANT;
		elsif (row mod 4 = 0) then
			neighborhood.top_left <= raw_neighborhood.prev_m1;
		else
			neighborhood.top_left <= raw_neighborhood.curr_m5;
		end if;
		
		--assign top right
		if (row = 0 or col = COLS - 1) then
			neighborhood.top_right <= INSIGNIFICANT;
		elsif (row mod 4 = 0) then
			neighborhood.top_right <= raw_neighborhood.prev_p7;
		else
			if (first_cleanup_pass_flag = '1') then
				neighborhood.top_right <= INSIGNIFICANT;
			else
				neighborhood.top_right <= raw_neighborhood.curr_p3;
			end if;
		end if;
		
		--assign right
		if (col = COLS - 1 or first_cleanup_pass_flag = '1') then
			neighborhood.right <= INSIGNIFICANT;
		else
			neighborhood.right <= raw_neighborhood.curr_p4;
		end if;
		
		--assign bottom right
		if (col = COLS - 1 or row = ROWS - 1 or first_cleanup_pass_flag = '1') then
			neighborhood.bottom_right <= INSIGNIFICANT;
		elsif (((row + 1) mod 4) = 0) then
			neighborhood.bottom_right <= raw_neighborhood.next_p1;
		else
			neighborhood.bottom_right <= raw_neighborhood.curr_p5;
		end if;
		
		--assign bottom
		if (row = ROWS - 1 or first_cleanup_pass_flag = '1') then
			neighborhood.bottom <= INSIGNIFICANT;
		elsif (((row + 1) mod 4) = 0) then
			neighborhood.bottom <= raw_neighborhood.next_m3;
		else
			neighborhood.bottom <= raw_neighborhood.curr_p1;
		end if;
		
		--assign bottom left
		if (col = 0 or row = ROWS - 1 or (first_cleanup_pass_flag = '1' and ((row + 1) mod 4 = 0))) then
			neighborhood.bottom_left <= INSIGNIFICANT;
		elsif (((row + 1) mod 4) = 0) then
			neighborhood.bottom_left <= raw_neighborhood.next_m7;
		else
			neighborhood.bottom_left <= raw_neighborhood.curr_m3;
		end if;
		
		--assign left
		if (col = 0) then
			neighborhood.left <= INSIGNIFICANT;
		else
			neighborhood.left <= raw_neighborhood.curr_m4;
		end if;
	end process;
	
	extract_run_length_neighborhood: process(raw_neighborhood, row, col, first_cleanup_pass_flag) 
	begin
		--by default assign same values, we will filter later
		run_length_neighborhood.curr_m4 <= raw_neighborhood.curr_m4;
		run_length_neighborhood.curr_m3 <= raw_neighborhood.curr_m3;
		run_length_neighborhood.curr_m2 <= raw_neighborhood.curr_m2;
		run_length_neighborhood.curr_m1 <= raw_neighborhood.curr_m1;
		run_length_neighborhood.curr_c  <= raw_neighborhood.curr_c;
		run_length_neighborhood.curr_p1 <= raw_neighborhood.curr_p1;
		run_length_neighborhood.curr_p2 <= raw_neighborhood.curr_p2;
		run_length_neighborhood.curr_p3 <= raw_neighborhood.curr_p3;
		run_length_neighborhood.curr_p4 <= raw_neighborhood.curr_p4;
		run_length_neighborhood.curr_p5 <= raw_neighborhood.curr_p5;
		run_length_neighborhood.curr_p6 <= raw_neighborhood.curr_p6;
		run_length_neighborhood.curr_p7 <= raw_neighborhood.curr_p7;
		run_length_neighborhood.prev_m1 <= raw_neighborhood.prev_m1;
		run_length_neighborhood.prev_p3 <= raw_neighborhood.prev_p3;
		run_length_neighborhood.prev_p7 <= raw_neighborhood.prev_p7;
		run_length_neighborhood.next_m4 <= raw_neighborhood.next_m4;
		run_length_neighborhood.next_c  <= raw_neighborhood.next_c;
		run_length_neighborhood.next_p4 <= raw_neighborhood.next_p4;
		
		--now if any is out of bounds, set as insignificant
		if (col = 0) then
			run_length_neighborhood.prev_m1 <= INSIGNIFICANT;
			run_length_neighborhood.curr_m1 <= INSIGNIFICANT;
			run_length_neighborhood.curr_m2 <= INSIGNIFICANT;
			run_length_neighborhood.curr_m3 <= INSIGNIFICANT;
			run_length_neighborhood.curr_m4 <= INSIGNIFICANT;
			run_length_neighborhood.next_m4 <= INSIGNIFICANT;
		end if;
		
		if (col = ROWS - 1) then
			run_length_neighborhood.prev_p7 <= INSIGNIFICANT;
			run_length_neighborhood.curr_p4 <= INSIGNIFICANT;
			run_length_neighborhood.curr_p5 <= INSIGNIFICANT;
			run_length_neighborhood.curr_p6 <= INSIGNIFICANT;
			run_length_neighborhood.curr_p7 <= INSIGNIFICANT;
			run_length_neighborhood.next_p4 <= INSIGNIFICANT;
		end if;
		
		if (row = 0) then
			run_length_neighborhood.prev_m1 <= INSIGNIFICANT;
			run_length_neighborhood.prev_p3 <= INSIGNIFICANT;
			run_length_neighborhood.prev_p7 <= INSIGNIFICANT;
		end if;
		
		if (row = COLS - 1) then
			run_length_neighborhood.next_m4 <= INSIGNIFICANT;
			run_length_neighborhood.next_c  <= INSIGNIFICANT;
			run_length_neighborhood.next_p4 <= INSIGNIFICANT;
		end if;
		
		if (first_cleanup_pass_flag = '1') then
			run_length_neighborhood.curr_c <= INSIGNIFICANT;
			run_length_neighborhood.curr_p1 <= INSIGNIFICANT;
			run_length_neighborhood.curr_p2 <= INSIGNIFICANT;
			run_length_neighborhood.curr_p3 <= INSIGNIFICANT;
			run_length_neighborhood.curr_p4 <= INSIGNIFICANT;
			run_length_neighborhood.curr_p5 <= INSIGNIFICANT;
			run_length_neighborhood.curr_p6 <= INSIGNIFICANT;												 
			run_length_neighborhood.curr_p7 <= INSIGNIFICANT;
			run_length_neighborhood.next_c  <= INSIGNIFICANT;
			run_length_neighborhood.next_m4 <= INSIGNIFICANT;
			run_length_neighborhood.next_p4 <= INSIGNIFICANT;
		end if;
		
	end process;
	

end Behavioral;
