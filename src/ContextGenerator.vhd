----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 24.10.2017 17:58:18
-- Design Name: 
-- Module Name: ContextGenerator - Behavioral
-- Project Name: Vypec
-- Target Devices: 
-- Tool Versions: 
-- Description: Generate contexts based on the significance state and other
--		flags of neighboring samples
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



-- Context generator entity
entity ContextGenerator is
	generic(
		--rows of the block, must be multiple of four
		ROWS: integer := 64;
		--cols of the block, must be greater than four
		COLS: integer := 64
	);
	port(
		--already filtered neighborhoods
		neighborhood: in neighborhood_3x3_t;
		run_length_neighborhood: in sign_neighborhood_t;
		--subband that this block is coding (LL, HL, LH, HH have 
		--different contexts for the same neighbor configurations
		subband: in subband_t;
		--true if this is the current sample's first refinement
		first_refinement_in: in std_logic;
		--contexts out
		magnitude_refinement_context, sign_bit_decoding_context, significance_propagation_context: out context_label_t;
		--flags out
		sign_bit_xor: out std_logic;
		--this might be up even if we are in the middle of a strip! use only when on the begining
		is_strip_zero_context: out std_logic
	);
end ContextGenerator;

architecture Behavioral of ContextGenerator is
	--precalculated values for easier context calculation
	signal horizontal_contribution, vertical_contribution: integer range -2 to 2;
	signal sum_horizontal, sum_vertical: natural range 0 to 2;
	signal sum_diagonal, sum_horizontal_vertical: natural range 0 to 4;
	
begin


	
	--using the 3x3 neighborhood, generate the contributions and sums
	generate_contributions_and_sums: process(neighborhood) 
		--use variables which are then assigned to the signals
		variable tmp_h_c, tmp_v_c: integer range -2 to 2;
		variable tmp_h_s, tmp_v_s: natural range 0 to 2;
		variable tmp_d_s: natural range 0 to 4;
	begin
		tmp_h_c := 0;
		tmp_v_c := 0;
		tmp_h_s := 0;
		tmp_v_s := 0;
		tmp_d_s := 0;
		
		if (neighborhood.left = SIGNIFICANT_POSITIVE) then
			tmp_h_c := tmp_h_c + 1;
			tmp_h_s := tmp_h_s + 1;
		elsif (neighborhood.left = SIGNIFICANT_NEGATIVE) then
			tmp_h_c := tmp_h_c - 1;
			tmp_h_s := tmp_h_s + 1;
		end if;
		
		if (neighborhood.right = SIGNIFICANT_POSITIVE) then
			tmp_h_c := tmp_h_c + 1;
			tmp_h_s := tmp_h_s + 1;
		elsif (neighborhood.right = SIGNIFICANT_NEGATIVE) then
			tmp_h_c := tmp_h_c - 1;
			tmp_h_s := tmp_h_s + 1;
		end if;
		
		if (neighborhood.top = SIGNIFICANT_POSITIVE) then
			tmp_v_c := tmp_v_c + 1;
			tmp_v_s := tmp_v_s + 1;
		elsif (neighborhood.top = SIGNIFICANT_NEGATIVE) then
			tmp_v_c := tmp_v_c - 1;
			tmp_v_s := tmp_v_s + 1;
		end if;
		
		if (neighborhood.bottom = SIGNIFICANT_POSITIVE) then
			tmp_v_c := tmp_v_c + 1;
			tmp_v_s := tmp_v_s + 1;
		elsif (neighborhood.bottom = SIGNIFICANT_NEGATIVE) then
			tmp_v_c := tmp_v_c - 1;
			tmp_v_s := tmp_v_s + 1;
		end if;
		
		if (neighborhood.bottom_right /= INSIGNIFICANT) then
			tmp_d_s := tmp_d_s + 1;
		end if;
		if (neighborhood.bottom_left /= INSIGNIFICANT) then
			tmp_d_s := tmp_d_s + 1;
		end if;
		if (neighborhood.top_right /= INSIGNIFICANT) then
			tmp_d_s := tmp_d_s + 1;
		end if;
		if (neighborhood.top_left /= INSIGNIFICANT) then
			tmp_d_s := tmp_d_s + 1;
		end if;
	
		horizontal_contribution <= tmp_h_c;
		vertical_contribution <= tmp_v_c;
		sum_horizontal <= tmp_h_s;
		sum_vertical <= tmp_v_s;
		sum_diagonal <= tmp_d_s;
		sum_horizontal_vertical <= tmp_h_s + tmp_v_s;
	end process;
	
	
	
	--output magnitude refinement context	
	magnitude_refinement_gen: process(neighborhood, first_refinement_in) 
		variable exists_significant_neighbor: boolean;
	begin
		--check for significant neighbors
		exists_significant_neighbor := (
			neighborhood.top_left		/= INSIGNIFICANT or neighborhood.top	/= INSIGNIFICANT or neighborhood.top_right		/= INSIGNIFICANT or 
			neighborhood.left			/= INSIGNIFICANT or 										neighborhood.right			/= INSIGNIFICANT or 
			neighborhood.bottom_left	/= INSIGNIFICANT or neighborhood.bottom /= INSIGNIFICANT or neighborhood.bottom_right	/= INSIGNIFICANT
		);

		--select appropiate context	
		if (first_refinement_in = '1') then
			if (not exists_significant_neighbor) then
				magnitude_refinement_context <= CONTEXT_FOURTEEN;
			else
				magnitude_refinement_context <= CONTEXT_FIFTEEN;
			end if;
		else
			magnitude_refinement_context <=  CONTEXT_SIXTEEN;
		end if;
	end process;
	
	
	--output sign bit decoding context
	sign_bit_context_gen: process(horizontal_contribution, vertical_contribution) 
	begin
		
		if (horizontal_contribution > 0) then
			sign_bit_xor <= '0';
			if (vertical_contribution > 0) then
				sign_bit_decoding_context <= CONTEXT_THIRTEEN;
			elsif (vertical_contribution = 0) then
				sign_bit_decoding_context <= CONTEXT_TWELVE;
			else
				sign_bit_decoding_context <= CONTEXT_ELEVEN;
			end if;
		elsif (horizontal_contribution = 0) then
			if (vertical_contribution > 0) then
				sign_bit_xor <= '0';
				sign_bit_decoding_context <= CONTEXT_TEN;
			elsif (vertical_contribution = 0) then
				sign_bit_xor <= '0';
				sign_bit_decoding_context <= CONTEXT_NINE;
			else
				sign_bit_xor <= '1';
				sign_bit_decoding_context <= CONTEXT_TEN;
			end if;
		else
			sign_bit_xor <= '1';
			if (vertical_contribution > 0) then
				sign_bit_decoding_context <= CONTEXT_ELEVEN;
			elsif (vertical_contribution = 0) then
				sign_bit_decoding_context <= CONTEXT_TWELVE;
			else
				sign_bit_decoding_context <= CONTEXT_THIRTEEN;
			end if;
		end if;	
	end process;
	
	
	output_significance_propagation_context: process(sum_vertical, sum_horizontal, sum_diagonal, sum_horizontal_vertical, subband)
	begin
		case (subband) is
			when HL =>
				if (sum_vertical = 0) then
					if (sum_horizontal = 0) then
						if (sum_diagonal = 0) then
							significance_propagation_context <= CONTEXT_ZERO;
						elsif (sum_diagonal = 1) then
							significance_propagation_context <= CONTEXT_ONE;
						else --sumD >= 2
							significance_propagation_context <= CONTEXT_TWO;
						end if;
					elsif (sum_horizontal = 1) then
						significance_propagation_context <= CONTEXT_THREE;
					else --sumh = 2
						significance_propagation_context <= CONTEXT_FOUR;
					end if;
				elsif (sum_vertical = 1) then
					if (sum_horizontal = 0) then
						if (sum_diagonal = 0) then
							significance_propagation_context <= CONTEXT_FIVE;
						else --sumd >= 1
							significance_propagation_context <= CONTEXT_SIX;
						end if;
					else --sumh >= 1
						significance_propagation_context <= CONTEXT_SEVEN;
					end if;
				else --sumv = 2
					significance_propagation_context <= CONTEXT_EIGHT;
				end if;
				
			when LL | LH =>  --same as HL but with horizontal and vertical changed
				if (sum_horizontal = 0) then
					if (sum_vertical = 0) then
						if (sum_diagonal = 0) then
							significance_propagation_context <= CONTEXT_ZERO;
						elsif (sum_diagonal = 1) then
							significance_propagation_context <= CONTEXT_ONE;
						else --sumD >= 2
							significance_propagation_context <= CONTEXT_TWO;
						end if;
					elsif (sum_vertical = 1) then
						significance_propagation_context <= CONTEXT_THREE;
					else --sumv = 2
						significance_propagation_context <= CONTEXT_FOUR;
					end if;
				elsif (sum_horizontal = 1) then
					if (sum_vertical = 0) then
						if (sum_diagonal = 0) then
							significance_propagation_context <= CONTEXT_FIVE;
						else --sumd >= 1
							significance_propagation_context <= CONTEXT_SIX;
						end if;
					else --sumv >= 1
						significance_propagation_context <= CONTEXT_SEVEN;
					end if;
				else --sumh = 2
					significance_propagation_context <= CONTEXT_EIGHT;
				end if;
				
			when HH =>
				if (sum_diagonal = 0) then
					if (sum_horizontal_vertical = 0) then
						significance_propagation_context <= CONTEXT_ZERO;
					elsif (sum_horizontal_vertical = 1) then
						significance_propagation_context <= CONTEXT_ONE;
					else --sumhv >= 2
						significance_propagation_context <= CONTEXT_TWO;
					end if;
				elsif (sum_diagonal = 1) then
					if (sum_horizontal_vertical = 0) then
						significance_propagation_context <= CONTEXT_THREE;
					elsif (sum_horizontal_vertical = 1) then
						significance_propagation_context <= CONTEXT_FOUR;
					else --sumhv >= 2
						significance_propagation_context <= CONTEXT_FIVE;
					end if;
				elsif (sum_diagonal = 2) then
					if (sum_horizontal_vertical = 0) then
						significance_propagation_context <= CONTEXT_SIX;
					else --sumhv >= 1
						significance_propagation_context <= CONTEXT_SEVEN;
					end if;
				else --sumd >= 3
					significance_propagation_context <= CONTEXT_EIGHT;
				end if;
		end case;
	end process;
	
	--this will assume a strip even if we are in the middle of one
	strip_zero_context: process(run_length_neighborhood)
		variable any_non_zero: boolean;
	begin
		any_non_zero := false;
	
		--this is basically a 6x3 rectangle in which all samples are checked for significance
		--if all are insignificant, then the whole strip is
		if (	run_length_neighborhood.curr_m4 /= INSIGNIFICANT or run_length_neighborhood.curr_m3 /= INSIGNIFICANT or
				run_length_neighborhood.curr_m2 /= INSIGNIFICANT or run_length_neighborhood.curr_m1 /= INSIGNIFICANT or
				run_length_neighborhood.curr_c  /= INSIGNIFICANT or run_length_neighborhood.curr_p1 /= INSIGNIFICANT or
				run_length_neighborhood.curr_p2 /= INSIGNIFICANT or run_length_neighborhood.curr_p3 /= INSIGNIFICANT or
				run_length_neighborhood.curr_p4 /= INSIGNIFICANT or run_length_neighborhood.curr_p5 /= INSIGNIFICANT or
				run_length_neighborhood.curr_p6 /= INSIGNIFICANT or run_length_neighborhood.curr_p7 /= INSIGNIFICANT or
				run_length_neighborhood.prev_m1 /= INSIGNIFICANT or run_length_neighborhood.prev_p3 /= INSIGNIFICANT or
				run_length_neighborhood.prev_p7 /= INSIGNIFICANT or run_length_neighborhood.next_m4 /= INSIGNIFICANT or
				run_length_neighborhood.next_c  /= INSIGNIFICANT or run_length_neighborhood.next_p4 /= INSIGNIFICANT) then
			any_non_zero := true;
		end if;
	
		if (any_non_zero) then
			is_strip_zero_context <= '0';
		else
			is_strip_zero_context <= '1';
		end if;
	end process;
	
	

end Behavioral;
