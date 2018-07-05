----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:25:46 06/13/2018 
-- Design Name: 
-- Module Name:    BPC_fast_significance_cleanup - Behavioral 
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
entity BPC_fast_significance_cleanup is
	port(
		--already filtered neighborhoods
		neighborhood: in significance_matrix;
		--bits in
		bits, sign: in bit_strip;
		--flags in
		first_nonzero: in natural range 0 to 3;
		all_bits_zero: in std_logic;
		iscoded_flag: in std_logic_vector(3 downto 0);
		--flags out
		becomes_significant: out bit_strip;
		--significance out
		significance: out significance_strip
	);
end BPC_fast_significance_cleanup;

architecture Behavioral of BPC_fast_significance_cleanup is	

	signal any_neigh_significant: bit_strip;

	signal i_becomes_significant: bit_strip;
	
	signal i_significance: significance_strip;

begin

	becomes_significant <= i_becomes_significant;
	significance <= i_significance;


	
	i_becomes_significant(0) <= '1' when all_bits_zero = '0' and first_nonzero = 0 and bits(0) = '1' else '0';
	i_significance(0) <= neighborhood(4) when i_becomes_significant(0) = '0' else
							SIGNIFICANT_POSITIVE when sign(0) = '0' else
							SIGNIFICANT_NEGATIVE;
															
	i_becomes_significant(1) <= '1' when all_bits_zero = '0' and first_nonzero <= 1 and bits(1) = '1' else '0';
	i_significance(1) <= neighborhood(7) when i_becomes_significant(1) = '0' else
							SIGNIFICANT_POSITIVE when sign(1) = '0' else
							SIGNIFICANT_NEGATIVE;
								
	i_becomes_significant(2) <= '1' when all_bits_zero = '0' and first_nonzero <= 2 and bits(2) = '1' else '0';
	i_significance(2) <= neighborhood(10) when i_becomes_significant(2) = '0' else
							SIGNIFICANT_POSITIVE when sign(2) = '0' else
							SIGNIFICANT_NEGATIVE;
	
	i_becomes_significant(3) <= '1' when all_bits_zero = '0' and first_nonzero <= 3 and bits(3) = '1' else '0';
	i_significance(3) <= neighborhood(13) when i_becomes_significant(3) = '0' else
							SIGNIFICANT_POSITIVE when sign(3) = '0' else
							SIGNIFICANT_NEGATIVE;
	

end Behavioral;





