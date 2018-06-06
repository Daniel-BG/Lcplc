----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:11:14 06/06/2018 
-- Design Name: 
-- Module Name:    BPC_sign_filter - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
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

entity BPC_sign_filter is
	generic (
		STRIPS: integer := 16;
		COLS: integer := 64
	);
	port (
		raw_neighborhood: in run_length_neighborhood_t;
		strip: in natural range 0 to STRIPS - 1;
		col: in natural range 0 to COLS - 1;
		first_cleanup_pass_flag: in std_logic; 
		run_length_neighborhood: out run_length_neighborhood_t
	);
--  Port ( );
end BPC_sign_filter;

architecture Behavioral of BPC_sign_filter is

begin
	
	extract_run_length_neighborhood: process(raw_neighborhood, strip, col, first_cleanup_pass_flag) 
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
		
		if (col = COLS - 1) then
			run_length_neighborhood.prev_p7 <= INSIGNIFICANT;
			run_length_neighborhood.curr_p4 <= INSIGNIFICANT;
			run_length_neighborhood.curr_p5 <= INSIGNIFICANT;
			run_length_neighborhood.curr_p6 <= INSIGNIFICANT;
			run_length_neighborhood.curr_p7 <= INSIGNIFICANT;
			run_length_neighborhood.next_p4 <= INSIGNIFICANT;
		end if;
		
		if (strip = 0) then
			run_length_neighborhood.prev_m1 <= INSIGNIFICANT;
			run_length_neighborhood.prev_p3 <= INSIGNIFICANT;
			run_length_neighborhood.prev_p7 <= INSIGNIFICANT;
		end if;
		
		if (strip = STRIPS - 1) then
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

