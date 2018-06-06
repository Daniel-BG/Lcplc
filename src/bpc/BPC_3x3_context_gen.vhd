----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:32:51 06/06/2018 
-- Design Name: 
-- Module Name:    BPC_3x3_context_gen - Behavioral 
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



-- Context generator entity
entity BPC_3x3_context_gen is
	port(
		--already filtered neighborhoods
		neighborhood: in neighborhood_3x3_t;
		--subband that this block is coding (LL, HL, LH, HH have 
		--different contexts for the same neighbor configurations
		subband: in subband_t;
		--true if this is the current sample's first refinement
		first_refinement_in: in std_logic;
		--contexts out
		magnitude_refinement_context, sign_bit_decoding_context, significance_propagation_context: out context_label_t;
		--flags out
		sign_bit_xor: out std_logic
	);
end BPC_3x3_context_gen;

architecture Behavioral of BPC_3x3_context_gen is
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
			neighborhood.top_left		/= INSIGNIFICANT or neighborhood.top	/= INSIGNIFICANT	or	neighborhood.top_right		/= INSIGNIFICANT or 
			neighborhood.left				/= INSIGNIFICANT or 														neighborhood.right			/= INSIGNIFICANT or 
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
	

end Behavioral;


