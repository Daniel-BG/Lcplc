----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:41:14 06/08/2018 
-- Design Name: 
-- Module Name:    BPC_output_concentrator - Behavioral 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity BPC_output_concentrator is
	port (
		in_contexts: in BPC_out_contexts_t;
		in_bits: in BPC_out_bits_t;
		in_valid: in BPC_out_valid_t;
		out_contexts: out BPC_out_contexts_t;
		out_bits: out BPC_out_bits_t;
		out_valid: out BPC_out_valid_t;
		num_out: out natural range 0 to 11
	);
end BPC_output_concentrator;

architecture Behavioral of BPC_output_concentrator is

	constant STAGES: integer := 11; --number of elements in I/O arrays
	
	type context_layers_t is array(0 to STAGES-1) of BPC_out_contexts_t;
	type bits_layers_t is array(0 to STAGES-1) of BPC_out_bits_t;
	type valid_layers_t is array(0 to STAGES-1) of BPC_out_valid_t;
	signal context_layers: context_layers_t;
	signal bits_layers: bits_layers_t;
	signal valid_layers: valid_layers_t;
	
	signal shift_stage_i: std_logic_vector(STAGES-2 downto 0);
	
begin

	context_layers(0) <= in_contexts;
	bits_layers(0) <= in_bits;
	valid_layers(0) <= in_valid;
	out_contexts <= context_layers(STAGES-1);
	out_bits <= bits_layers(STAGES-1);
	out_valid <= valid_layers(STAGES-1);
	
	gen_shift_enable: for i in 0 to STAGES-2 generate
		shift_stage_i(i) <= '1' when valid_layers(i)(STAGES-2-i) = '0' else '0';
	end generate;



	gen_network: for i in 0 to STAGES-2 generate
		gen_stage: for j in 0 to STAGES-2 generate
			context_layers(i+1)(j) <= context_layers(i)(j) when shift_stage_i(i) = '0' else context_layers(i)(j+1);
			bits_layers(i+1)(j) <= bits_layers(i)(j) when shift_stage_i(i) = '0' else bits_layers(i)(j+1);
			valid_layers(i+1)(j) <= valid_layers(i)(j) when shift_stage_i(i) = '0' else valid_layers(i)(j+1);
		end generate;
	end generate;
	
	
	gen_output_num: process(in_valid)
		variable temp: natural range 0 to 11;
	begin
		temp := 0;
		for i in 0 to STAGES-1 loop
			if (in_valid(i) = '1') then
				temp := temp + 1;
			end if;
		end loop;
	
		num_out <= temp;
	end process;




end Behavioral;

