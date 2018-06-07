----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:11:43 06/07/2018 
-- Design Name: 
-- Module Name:    BPC_fast_significance_change_prediction - Behavioral 
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
entity BPC_fast_significance_change_prediction is
	port(
		--already filtered neighborhoods
		neighborhood: in significance_matrix;
		--bits in
		bits, sign: in bit_strip;
		--flags out
		becomes_significant: out bit_strip;
		--significance out
		significance: out significance_strip
	);
end BPC_fast_significance_change_prediction;

architecture Behavioral of BPC_fast_significance_change_prediction is	

	signal any_neigh_significant: bit_strip;

	signal i_becomes_significant: bit_strip;

begin

	becomes_significant <= i_becomes_significant;

	any_neigh_significant(0) <= '1' when 	
									neighborhood(0) /= INSIGNIFICANT or 
									neighborhood(1) /= INSIGNIFICANT or 
									neighborhood(2) /= INSIGNIFICANT or 
									neighborhood(3) /= INSIGNIFICANT or
									neighborhood(5) /= INSIGNIFICANT or 
									neighborhood(6) /= INSIGNIFICANT or
									neighborhood(7) /= INSIGNIFICANT or
									neighborhood(8) /= INSIGNIFICANT
									else '0';
	
	i_becomes_significant(0) <= '1' when any_neigh_significant(0) = '1' and neighborhood(4) = INSIGNIFICANT and bits(0) = '1' else '0';
	significance(0) <= neighborhood(4) when i_becomes_significant(0) = '0' else
							SIGNIFICANT_POSITIVE when sign(0) = '0' else
							SIGNIFICANT_NEGATIVE;
	
	
	any_neigh_significant(1) <= '1' when 	
									neighborhood(3) /= INSIGNIFICANT or 
									i_becomes_significant(0) = '1' or 
									neighborhood(5) /= INSIGNIFICANT or 
									neighborhood(6) /= INSIGNIFICANT or
									neighborhood(8) /= INSIGNIFICANT or 
									neighborhood(9) /= INSIGNIFICANT or
									neighborhood(10) /= INSIGNIFICANT or
									neighborhood(11) /= INSIGNIFICANT
									else '0';
															
	i_becomes_significant(1) <= '1' when any_neigh_significant(1) = '1' and neighborhood(7) = INSIGNIFICANT and bits(1) = '1' else '0';
	significance(1) <= neighborhood(7) when i_becomes_significant(1) = '0' else
							SIGNIFICANT_POSITIVE when sign(1) = '0' else
							SIGNIFICANT_NEGATIVE;
	
	any_neigh_significant(2) <= '1' when 	
									neighborhood(6) /= INSIGNIFICANT or 
									i_becomes_significant(1) = '1' or 
									neighborhood(8) /= INSIGNIFICANT or 
									neighborhood(9) /= INSIGNIFICANT or
									neighborhood(10) /= INSIGNIFICANT or 
									neighborhood(11) /= INSIGNIFICANT or
									neighborhood(12) /= INSIGNIFICANT or
									neighborhood(13) /= INSIGNIFICANT
									else '0';
								
	i_becomes_significant(2) <= '1' when any_neigh_significant(2) = '1' and neighborhood(10) = INSIGNIFICANT and bits(2) = '1' else '0';
	significance(2) <= neighborhood(10) when i_becomes_significant(2) = '0' else
							SIGNIFICANT_POSITIVE when sign(2) = '0' else
							SIGNIFICANT_NEGATIVE;
	
	any_neigh_significant(3) <= '1' when 	
									neighborhood(9) /= INSIGNIFICANT or 
									i_becomes_significant(2) = '1' or 
									neighborhood(11) /= INSIGNIFICANT or 
									neighborhood(12) /= INSIGNIFICANT or
									neighborhood(14) /= INSIGNIFICANT or 
									neighborhood(15) /= INSIGNIFICANT or
									neighborhood(16) /= INSIGNIFICANT or
									neighborhood(17) /= INSIGNIFICANT
									else '0';
								
	i_becomes_significant(3) <= '1' when any_neigh_significant(3) = '1' and neighborhood(13) = INSIGNIFICANT and bits(3) = '1' else '0';
	significance(3) <= neighborhood(13) when i_becomes_significant(3) = '0' else
							SIGNIFICANT_POSITIVE when sign(3) = '0' else
							SIGNIFICANT_NEGATIVE;
	

end Behavioral;




