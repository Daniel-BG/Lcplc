----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 24.10.2017 17:58:18
-- Design Name: 
-- Module Name: ContextGenerator - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;
use work.JypecConstants.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ContextGenerator is
	generic(
		ROWS: integer := 64;
		COLS: integer := 64
	);
	port(
		raw_neighborhood: in sign_neighborhood_t;
		subband: in subband_t;
		row: in natural range 0 to ROWS - 1;
		col: in natural range 0 to COLS - 1;
		first_refinement_in: in std_logic;
		magnitude_refinement_context, sign_bit_decoding_context, significance_propagation_context: out context_label_t;
		sign_bit_xor: out std_logic;
		is_strip_zero_context: out std_logic
	);
end ContextGenerator;

architecture Behavioral of ContextGenerator is

	signal neighborhood: neighborhood_3x3_t;
	
	signal horizontal_contribution, vertical_contribution: integer range -2 to 2;
	
	signal sum_horizontal, sum_vertical: natural range 0 to 2;
	signal sum_diagonal, sum_horizontal_vertical: natural range 0 to 4;
	
begin

	--from the input neighborhood (which includes tons of useless data)
	--extract the exact 3x3 neighborhood of the current sample
	extract_neighborhood: process(raw_neighborhood, row, col) 
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
			neighborhood.top_right <= raw_neighborhood.curr_p3;
		end if;
		
		--assign right
		if (col = COLS - 1) then
			neighborhood.right <= INSIGNIFICANT;
		else
			neighborhood.right <= raw_neighborhood.curr_p4;
		end if;
		
		--assign bottom right
		if (col = COLS - 1 or row = ROWS - 1) then
			neighborhood.bottom_right <= INSIGNIFICANT;
		elsif (((row + 1) mod 4) = 0) then
			neighborhood.bottom_right <= raw_neighborhood.next_p1;
		else
			neighborhood.bottom_right <= raw_neighborhood.curr_p5;
		end if;
		
		--assign bottom
		if (row = ROWS - 1) then
			neighborhood.bottom <= INSIGNIFICANT;
		elsif (((row + 1) mod 4) = 0) then
			neighborhood.bottom <= raw_neighborhood.next_m3;
		else
			neighborhood.bottom <= raw_neighborhood.curr_p1;
		end if;
		
		--assign bottom left
		if (col = 0 or row = ROWS - 1) then
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
	
	--using the 3x3 neighborhood, generate the contributions and sums
	generate_contributions_and_sums: process(neighborhood) 
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
		variable exists_neighbor_one: boolean;
	begin
		--check if any of the neighbors is significant (either positive or negative work)
		exists_neighbor_one := (neighborhood.top_left /= INSIGNIFICANT or neighborhood.top /= INSIGNIFICANT or neighborhood.top_right /= INSIGNIFICANT or 
			neighborhood.right /= INSIGNIFICANT or neighborhood.bottom_right /= INSIGNIFICANT or neighborhood.bottom /= INSIGNIFICANT or
			neighborhood.bottom_left /= INSIGNIFICANT or neighborhood.left /= INSIGNIFICANT);

	
		if (first_refinement_in = '1') then
			if (not exists_neighbor_one) then
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
	
	
	strip_zero_context: process(raw_neighborhood, row)
		variable any_non_zero: boolean;
	begin
		any_non_zero := false;
	
		if (raw_neighborhood.curr_m4 /= INSIGNIFICANT or raw_neighborhood.curr_m3 /= INSIGNIFICANT or
				raw_neighborhood.curr_m2 /= INSIGNIFICANT or raw_neighborhood.curr_m1 /= INSIGNIFICANT or
				raw_neighborhood.curr_c  /= INSIGNIFICANT or raw_neighborhood.curr_p1 /= INSIGNIFICANT or
				raw_neighborhood.curr_p2 /= INSIGNIFICANT or raw_neighborhood.curr_p3 /= INSIGNIFICANT or
				raw_neighborhood.curr_p4 /= INSIGNIFICANT or raw_neighborhood.curr_p5/= INSIGNIFICANT or
				raw_neighborhood.curr_p6 /= INSIGNIFICANT or raw_neighborhood.curr_p7 /= INSIGNIFICANT or
				raw_neighborhood.prev_m1 /= INSIGNIFICANT or raw_neighborhood.prev_p3 /= INSIGNIFICANT or
				raw_neighborhood.prev_p7 /= INSIGNIFICANT or raw_neighborhood.next_m4 /= INSIGNIFICANT or
				raw_neighborhood.next_c  /= INSIGNIFICANT or raw_neighborhood.next_p4 /= INSIGNIFICANT) then
			any_non_zero := true;
		end if;
	
		if (row mod 4 /= 0) then
			is_strip_zero_context <= '0';
		else
			if (any_non_zero) then
				is_strip_zero_context <= '0';
			else
				is_strip_zero_context <= '1';
			end if;
		end if;	
	end process;
	
	

end Behavioral;
