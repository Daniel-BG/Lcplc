----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:27:47 06/06/2018 
-- Design Name: 
-- Module Name:    BPC_significance_storage - Behavioral 
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
use IEEE.NUMERIC_STD.ALL;
use work.JypecConstants.all;


--Generic and port definition
entity BPC_significance_storage is
	generic (
		--number of strips
		STRIPS: integer := 16;
		--number of stripes
		COLS: integer := 64
	);
	port (
		--control signals
		clk, rst, clk_en: in std_logic;
		--significance state to save in current memory cell
		in_value_0: in significance_state_t;
		in_value_1: in significance_state_t;
		in_value_2: in significance_state_t;
		in_value_3: in significance_state_t;
		--current neighborhood 
		--it might contain invalid values. Be sure to filter it afterwards
		out_value: out run_length_neighborhood_t
	);
end BPC_significance_storage;


architecture Behavioral of BPC_significance_storage is

	--derived constants
	constant SIZE_MAIN_STORAGE: integer := COLS * (STRIPS - 2) - 3; --7 or 6, check
	constant SIZE_NEXT_STORAGE: integer := COLS - 3; --16 or 15, check
	constant SIZE_PREV_STORAGE: integer := COLS - 3; --14 or 13, check
	--buffer sizes
	type storage_main_t is array(0 to SIZE_MAIN_STORAGE - 1) of std_logic_vector(7 downto 0);
	type storage_next_t is array(0 to SIZE_NEXT_STORAGE - 1) of std_logic_vector(7 downto 0);
	type storage_prev_t is array(0 to SIZE_PREV_STORAGE - 1) of std_logic_vector(7 downto 0);
	--buffers
	signal storage_main: storage_main_t;
	signal storage_next: storage_next_t;
	signal storage_prev: storage_prev_t;
	--indices for retrieving memory
	subtype index_main_t is natural range 0 to SIZE_MAIN_STORAGE - 1;
	subtype index_next_t is natural range 0 to SIZE_NEXT_STORAGE - 1;
	subtype index_prev_t is natural range 0 to SIZE_PREV_STORAGE - 1;
	signal index_main: index_main_t;
	signal index_next: index_next_t;
	signal index_prev: index_prev_t;
	
	
	signal strip_prev_m1, strip_prev_c, strip_prev_p1,
			 strip_curr_m1, strip_curr_c, strip_curr_p1,
			 strip_next_m1, strip_next_c, strip_next_p1: significance_strip_t;
			 
begin

	--always output inner state
	--previous strip values
	out_value.prev_m1 <= strip_prev_m1.ss_3;
	out_value.prev_p3 <= strip_prev_c.ss_3;
	out_value.prev_p7 <= strip_prev_p1.ss_3;
	--current strip values
	--out_value.curr_m5 <= 
	out_value.curr_m4 <= strip_curr_m1.ss_0;
	out_value.curr_m3 <= strip_curr_m1.ss_1;
	out_value.curr_m2 <= strip_curr_m1.ss_2;
	out_value.curr_m1 <= strip_curr_m1.ss_3;
	out_value.curr_c  <= strip_curr_c.ss_0;
	out_value.curr_p1 <= strip_curr_c.ss_1;
	out_value.curr_p2 <= strip_curr_c.ss_2;
	out_value.curr_p3 <= strip_curr_c.ss_3;
	out_value.curr_p4 <= strip_curr_p1.ss_0;
	out_value.curr_p5 <= strip_curr_p1.ss_1;
	out_value.curr_p6 <= strip_curr_p1.ss_2;
	out_value.curr_p7 <= strip_curr_p1.ss_3;
	--next strip values
	--out_value.next_m7 <=
	out_value.next_m4 <= strip_next_m1.ss_0;
	--out_value.next_m3 <= 
	out_value.next_c  <= strip_next_c.ss_0;
	--out_value.next_p1 <= 
	out_value.next_p4 <= strip_next_p1.ss_0;
	
	
	

	update: process(clk, rst, clk_en) 
	begin
		if (rst = '1') then
			--sync indices, nothing more needed
			index_main <= 0;
			index_next <= 0;
			index_prev <= 0;
		elsif (rising_edge(clk) and clk_en = '1') then
			--shift all values, saving and reading from memory
			--modules when needed
			storage_main(index_main) <= significance_strip_to_vector(strip_prev_m1);
			strip_prev_m1	<= strip_prev_c;
			strip_prev_c	<= strip_prev_p1;
			strip_prev_p1	<= vector_to_significance_strip(storage_prev(index_prev));
			storage_prev(index_prev) <= significance_strip_to_vector(strip_curr_m1);
			strip_curr_m1.ss_0 <= in_value_0;
			strip_curr_m1.ss_1 <= in_value_1;
			strip_curr_m1.ss_2 <= in_value_2;
			strip_curr_m1.ss_3 <= in_value_3;
			strip_curr_c	<= strip_curr_p1;
			strip_curr_p1	<= vector_to_significance_strip(storage_next(index_next));
			storage_next(index_next) <= significance_strip_to_vector(strip_next_m1);
			strip_next_m1	<= strip_next_c;
			strip_next_c	<= strip_next_p1;
			strip_next_p1	<= vector_to_significance_strip(storage_main(index_main));
			
			--update indices from all 3 memory modules 
			--(make them circular FIFOs) 
			if (index_main = SIZE_MAIN_STORAGE - 1) then 
				index_main <= 0;
			else
				index_main <= index_main + 1;
			end if;
			if (index_prev = SIZE_PREV_STORAGE - 1) then
				index_prev <= 0;
			else
				index_prev <= index_prev + 1;
			end if;
			if (index_next = SIZE_NEXT_STORAGE - 1) then
				index_next <= 0;
			else
				index_next <= index_next + 1;
			end if;
		end if;
	end process;


end Behavioral;

