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
	
	function significance_state_to_vector(input: significance_state_t) return std_logic_vector;
	function vector_to_significance_state(input: std_logic_vector(1 downto 0)) return significance_state_t;
	function significance_strip_to_vector(input: significance_strip_t) return std_logic_vector;
	function vector_to_significance_strip(input: std_logic_vector(7 downto 0)) return significance_strip_t;
	
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
	
	
	--outputs for BPC (use 11 to reuse circuitry on outputs of different stages)
	type BPC_out_contexts_t is array(0 to 10) of context_label_t;
	type BPC_out_bits_t is array(0 to 10) of std_logic;
	type BPC_out_valid_t is array(0 to 10) of std_logic;
	
	--custom types for ease of use
	type neigh_strip is array (0 to 3) of neighborhood_3x3_t;
	type bit_strip is array(0 to 3) of std_logic;
	type context_strip is array(0 to 3) of context_label_t;
	type significance_strip is array(0 to 3) of significance_state_t;
	type significance_matrix is array(0 to 17) of significance_state_t;
	
	
	
		--19 different context
	subtype context_t is natural range 0 to 18;

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
	
	--	subtype probability_t is natural range 0 to 2**16-1;
	subtype probability_t_MIO is natural range 0 to 22017;
	--	type probability_estimate_t is array(0 to 46) of probability_t;
	type probability_estimate_t_MIO is array(0 to 46) of probability_t_MIO;
	--	constant P_ESTIMATE: probability_estimate_t :=
	constant P_ESTIMATE: probability_estimate_t_MIO :=
			(22017, 13313, 6145, 2753, 1313,  545,   22017, 21505, 18433, 14337, 
			 12289, 9217,  7169, 5633, 22017, 21505, 20737, 18433, 14337, 13313, 
			 12289, 10241, 9217, 8705, 7169,  6145,  5633,  5121,  4609,  4353, 
			 2753,  2497,  2209, 1313, 1089,  673,   545,   321,   273,   133, 
			 73,    37,    21,   9,    5,     1,     22017);

	subtype probability_t is natural range 0 to 2**16-1;
	type probability_estimate_t is array(0 to 46) of probability_t;		 
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
	
	
	type info_mem_contexto_t is record
		prediction: std_logic;
		P_ESTIMATE: probability_t;
		SIGMA_MPS: state_t;
		SIGMA_LPS: state_t;
		X_S: std_logic;
		SHIFTED_P_ESTIMATE: probability_t;
		P_ESTIMATE_SHIFT: probability_t;
	end record info_mem_contexto_t;
	
	
	type info_mem_estado_t is record
		P_ESTIMATE: probability_t;
		SIGMA_MPS: state_t;
		SIGMA_LPS: state_t;
		X_S: std_logic;
		SHIFTED_P_ESTIMATE: probability_t;
		P_ESTIMATE_SHIFT: probability_t;
	end record info_mem_estado_t;
	
end package;

package body JypecConstants is

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
	
end ;
