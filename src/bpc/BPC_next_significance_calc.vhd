----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:34:10 06/06/2018 
-- Design Name: 
-- Module Name:    BPC_next_significance_calc - Behavioral 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity BPC_next_significance_calc is
	port (
		curr_pass: in encoder_pass_t;
		curr_significance: in significance_state_t;
		curr_context: in context_label_t;
		curr_sign_bit: in std_logic;
		next_significance: out significance_state_t
	);
end BPC_next_significance_calc;

architecture Behavioral of BPC_next_significance_calc is

begin

	calculate_next_significance: process(curr_pass, curr_significance, curr_context, curr_sign_bit)
	begin
		if (curr_pass /= SIGNIFICANCE or curr_significance /= INSIGNIFICANT or curr_context = CONTEXT_ZERO) then
			--keep the same
			next_significance <= curr_significance;
		else
			--is gonna change, just check sign
			if (curr_sign_bit <= '0') then
				next_significance <= SIGNIFICANT_POSITIVE;
			else
				next_significance <= SIGNIFICANT_NEGATIVE;
			end if;
		end if;
		
	end process;


end Behavioral;

