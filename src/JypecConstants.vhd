----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.10.2017 15:29:27
-- Design Name: 
-- Module Name: JypecConstants - Behavioral
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
use IEEE.STD_LOGIC_1164.all;


package JypecConstants is
	type significance_state_t is (INSIGNIFICANT, SIGNIFICANT_POSITIVE, SIGNIFICANT_NEGATIVE);
	
	type significance_strip_t is record
		ss_0: significance_state_t;
		ss_1: significance_state_t;
		ss_2: significance_state_t;
		ss_3: significance_state_t;
	end record;
	
	--constant lookup: array(significance_state_t) of std_logic_vector(1 downto 0) := (
	--	INSIGNIFICANT  => "00",
	--	SIGNIFICANT_POSITIVE => "01",
	--	SIGNIFICANT_NEGATIVE => "10"
	--);
	
	function significance_state_to_vector(input: significance_state_t) return std_logic_vector is
	begin
		if (input = INSIGNIFICANT) then
			return "00";
		elsif (input = SIGNIFICANT_POSITIVE) then
			return "01";
		else
			return "10";
		end if;
	end significance_state_to_vector;
	
	function vector_to_significance_state(input: std_logic_vector(1 downto 0)) return significance_state_t is
	begin
		if (input = "00") then
			return INSIGNIFICANT;
		elsif (input = "01") then
			return SIGNIFICANT_POSITIVE;
		else
			return SIGNIFICANT_NEGATIVE;
		end if;
	end vector_to_significance_state;
	
	function significance_strip_to_vector(input: significance_strip_t) return std_logic_vector is
	begin
		return 	significance_state_to_vector(input.ss_0) &
					significance_state_to_vector(input.ss_1) &
					significance_state_to_vector(input.ss_2) &
					significance_state_to_vector(input.ss_3);
	end significance_strip_to_vector;
	
	function vector_to_significance_strip(input: std_logic_vector(7 downto 0)) return significance_strip_t is
		variable result: significance_strip_t;
	begin
		result.ss_0 := vector_to_significance_state(input(7 downto 6));
		result.ss_1 := vector_to_significance_state(input(5 downto 4));
		result.ss_2 := vector_to_significance_state(input(3 downto 2));
		result.ss_3 := vector_to_significance_state(input(1 downto 0));
		return result;
	end vector_to_significance_strip;
	
	type subband_t is (LL, LH, HL, HH);
	type encoder_pass_t is (CLEANUP, SIGNIFICANCE, REFINEMENT);
	
	type sign_neighborhood_full_t is record
		prev_m1, prev_c, prev_p1, prev_p2, prev_p3, prev_p4, prev_p5, prev_p6, prev_p7: significance_state_t;
		curr_m5, curr_m4, curr_m3, curr_m2, curr_m1, curr_c, curr_p1, curr_p2, curr_p3, curr_p4, curr_p5, curr_p6, curr_p7: significance_state_t;
		next_m7, next_m6, next_m5, next_m4, next_m3, next_m2, next_m1, next_c, next_p1, next_p2, next_p3, next_p4: significance_state_t;
	end record sign_neighborhood_full_t; 
	
	type sign_neighborhood_t is record
		prev_m1, prev_p3, prev_p7: significance_state_t;
		curr_m5, curr_m4, curr_m3, curr_m2, curr_m1, curr_c, curr_p1, curr_p2, curr_p3, curr_p4, curr_p5, curr_p6, curr_p7: significance_state_t;
		next_m7, next_m4, next_m3, next_c, next_p1, next_p4: significance_state_t;
	end record sign_neighborhood_t;
	
	type run_length_neighborhood_t is record
		prev_m1, prev_p3, prev_p7: significance_state_t;
		curr_m4, curr_m3, curr_m2, curr_m1, curr_c, curr_p1, curr_p2, curr_p3, curr_p4, curr_p5, curr_p6, curr_p7: significance_state_t;
		next_m4, next_c, next_p4: significance_state_t;
	end record run_length_neighborhood_t;
	
	type neighborhood_3x3_t is record
		top_left, top, top_right, right, bottom_right, bottom, bottom_left, left: significance_state_t;
	end record neighborhood_3x3_t;

	--0:	cleanup spetial label
	--1-8:	significance propagation
	--9-13:	sign encoding
	--14-16:refinement
	--RUN_LENGTH
	--UNIFORM
	subtype context_label_t is natural range 0 to 18;
	constant CONTEXT_ZERO: context_label_t := 0;
	constant CONTEXT_ONE: context_label_t := 1;
	constant CONTEXT_TWO: context_label_t := 2;
	constant CONTEXT_THREE: context_label_t := 3;
	constant CONTEXT_FOUR: context_label_t := 4;
	constant CONTEXT_FIVE: context_label_t := 5;											 
	constant CONTEXT_SIX: context_label_t := 6;
	constant CONTEXT_SEVEN: context_label_t := 7;
	constant CONTEXT_EIGHT: context_label_t := 8;
	constant CONTEXT_NINE: context_label_t := 9;
	constant CONTEXT_TEN: context_label_t := 10;
	constant CONTEXT_ELEVEN: context_label_t := 11;
	constant CONTEXT_TWELVE: context_label_t := 12;
	constant CONTEXT_THIRTEEN: context_label_t := 13;
	constant CONTEXT_FOURTEEN: context_label_t := 14;
	constant CONTEXT_FIFTEEN: context_label_t := 15;
	constant CONTEXT_SIXTEEN: context_label_t := 16;
	constant CONTEXT_RUN_LENGTH: context_label_t := 17;
	constant CONTEXT_UNIFORM: context_label_t := 18;
	
end package;

