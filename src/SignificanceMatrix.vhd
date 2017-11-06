----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel
-- 
-- Create Date: 23.10.2017 15:28:39
-- Design Name: 
-- Module Name: SignificanceMatrix - Behavioral
-- Project Name: Vypec
-- Target Devices: 
-- Tool Versions: 
-- Description: Module that stores the significance state of a whole block
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
entity SignificanceMatrix is
	generic (
		--number of rows (must be multiple of four)
		ROWS: integer := 64;
		--number of columns
		COLS: integer := 64
	);
	port (
		--control signals
		clk, rst, clk_en: in std_logic;
		--significance state to save in current memory cell
		in_value: in significance_state_t;
		--current neighborhood 
		out_value: out sign_neighborhood_t
	);
end SignificanceMatrix;


architecture Behavioral of SignificanceMatrix is

	--derived constants
	constant STRIPE_SAMPLES: integer := COLS * 4;
	constant SIZE_MAIN_STORAGE: integer := COLS * (ROWS - 8) - 6; --7 or 6, check
	constant SIZE_NEXT_STORAGE: integer := STRIPE_SAMPLES - 15; --16 or 15, check
	constant SIZE_PREV_STORAGE: integer := STRIPE_SAMPLES - 13; --14 or 13, check
	--buffer sizes
	type storage_main_t is array(0 to SIZE_MAIN_STORAGE - 1) of significance_state_t;
	type storage_next_t is array(0 to SIZE_NEXT_STORAGE - 1) of significance_state_t;
	type storage_prev_t is array(0 to SIZE_PREV_STORAGE - 1) of significance_state_t;
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

	--local vars of previous, current and next stripe
	--all of these are needed at some point
	signal neigh: sign_neighborhood_full_t;
	
begin
	--always output inner state
	--previous strip values
	out_value.prev_m1 <= neigh.prev_m1;
	out_value.prev_p3 <= neigh.prev_p3;
	out_value.prev_p7 <= neigh.prev_p7;
	--current strip values
	out_value.curr_m5 <= neigh.curr_m5;
	out_value.curr_m4 <= neigh.curr_m4;
	out_value.curr_m3 <= neigh.curr_m3;
	out_value.curr_m2 <= neigh.curr_m2;
	out_value.curr_m1 <= neigh.curr_m1;
	out_value.curr_c  <= neigh.curr_c;
	out_value.curr_p1 <= neigh.curr_p1;
	out_value.curr_p2 <= neigh.curr_p2;
	out_value.curr_p3 <= neigh.curr_p3;
	out_value.curr_p4 <= neigh.curr_p4;
	out_value.curr_p5 <= neigh.curr_p5;
	out_value.curr_p6 <= neigh.curr_p6;
	out_value.curr_p7 <= neigh.curr_p7;
	--next strip values
	out_value.next_m7 <= neigh.next_m7;
	out_value.next_m4 <= neigh.next_m4;
	out_value.next_m3 <= neigh.next_m3;
	out_value.next_c  <= neigh.next_c;
	out_value.next_p1 <= neigh.next_p1;
	out_value.next_p4 <= neigh.next_p4;
	

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
			storage_main((index_main)) <= neigh.prev_m1;
			neigh.prev_m1 <= neigh.prev_c;
			neigh.prev_c  <= neigh.prev_p1;
			neigh.prev_p1 <= neigh.prev_p2;
			neigh.prev_p2 <= neigh.prev_p3;
			neigh.prev_p3 <= neigh.prev_p4;
			neigh.prev_p4 <= neigh.prev_p5;
			neigh.prev_p5 <= neigh.prev_p6;
			neigh.prev_p6 <= neigh.prev_p7;
			neigh.prev_p7 <= storage_prev((index_prev));
			storage_prev((index_prev)) <= neigh.curr_m5;
			neigh.curr_m5 <= neigh.curr_m4;
			neigh.curr_m4 <= neigh.curr_m3;
			neigh.curr_m3 <= neigh.curr_m2;
			neigh.curr_m2 <= neigh.curr_m1;
			neigh.curr_m1 <= in_value;		--take the input
			neigh.curr_c  <= neigh.curr_p1;
			neigh.curr_p1 <= neigh.curr_p2;
			neigh.curr_p2 <= neigh.curr_p3;
			neigh.curr_p3 <= neigh.curr_p4;
			neigh.curr_p4 <= neigh.curr_p5;
			neigh.curr_p5 <= neigh.curr_p6;
			neigh.curr_p6 <= neigh.curr_p7;
			neigh.curr_p7 <= storage_next((index_next));
			storage_next((index_next)) <= neigh.next_m7;
			neigh.next_m7 <= neigh.next_m6;
			neigh.next_m6 <= neigh.next_m5;
			neigh.next_m5 <= neigh.next_m4;
			neigh.next_m4 <= neigh.next_m3;
			neigh.next_m3 <= neigh.next_m2;
			neigh.next_m2 <= neigh.next_m1;
			neigh.next_m1 <= neigh.next_c;
			neigh.next_c  <= neigh.next_p1;
			neigh.next_p1 <= neigh.next_p2;
			neigh.next_p2 <= neigh.next_p3;
			neigh.next_p3 <= neigh.next_p4;
			neigh.next_p4 <= storage_main((index_main));
			
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
