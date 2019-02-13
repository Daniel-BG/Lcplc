----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08.02.2019 10:28:15
-- Design Name: 
-- Module Name: queued_multiplier - Behavioral
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

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity MULT_AXI is
	Generic (
		DATA_WIDTH: integer := 19
	);
	Port(
		clk, rst: in std_logic;
		input_a, input_b: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_valid: in std_logic;
		input_ready: out std_logic;
		output: out std_logic_vector(DATA_WIDTH*2-1 downto 0);
		output_valid: out std_logic;
		output_ready: in std_logic
	);
end MULT_AXI;

architecture Behavioral of MULT_AXI is
	function to_closest_mult_size(X : integer)
              return integer is
	begin
	  if X <= 18 then
		return 18;
	  elsif X <= 25 then
		return 25;
	  else
	  	report "Size out of max bounds" severity error;
	  	return 0;
	  end if;
	end to_closest_mult_size;

	constant INNER_DATA_WIDTH: integer := to_closest_mult_size(DATA_WIDTH);
	signal final_input_a, final_input_b: std_logic_vector(INNER_DATA_WIDTH - 1 downto 0);
	
	signal final_output: std_logic_vector(INNER_DATA_WIDTH*2 - 1 downto 0);
begin

	gen_sign_extend: if DATA_WIDTH < INNER_DATA_WIDTH generate
		gen_sign_bits: for i in INNER_DATA_WIDTH - 1 downto DATA_WIDTH generate
			final_input_a(i) <= input_a(DATA_WIDTH - 1);
			final_input_b(i) <= input_b(DATA_WIDTH - 1);
		end generate;
	end generate;
	
	final_input_a(DATA_WIDTH - 1 downto 0) <= input_a;
	final_input_b(DATA_WIDTH - 1 downto 0) <= input_b;

	--use only 1 dsp block
	gen_lesseq_18x18: if DATA_WIDTH <= 18 generate
		mult_18x18: entity work.MULT_18_x_18_AXI
			port map (
				clk => clk, rst => rst,
				input_a => final_input_a,
				input_b => final_input_b,
				input_valid => input_valid,
				input_ready => input_ready,
				output => final_output,
				output_valid => output_valid,
				output_ready => output_ready
			);
	end generate;
	
	--use only 2 dsp blocks
	gen_lesseq_25x25: if DATA_WIDTH > 18 and DATA_WIDTH <= 25 generate
		mult_25x25: entity work.MULT_25_x_25_AXI
			port map (
				clk => clk, rst => rst,
				input_a => final_input_a,
				input_b => final_input_b,
				input_valid => input_valid,
				input_ready => input_ready,
				output => final_output,
				output_valid => output_valid,
				output_ready => output_ready
			);
	end generate;
	
	output <= final_output(DATA_WIDTH*2-1 downto 0);


end Behavioral;
