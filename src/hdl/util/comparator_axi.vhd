----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11.02.2019 16:28:19
-- Design Name: 
-- Module Name: COMPARATOR_AXI - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity COMPARATOR_AXI is
	--for lower than just invert the inputs
	Generic (
		DATA_WIDTH: integer := 32;
		IS_SIGNED: 	boolean := true;
		IS_EQUAL: 	boolean := true;
		IS_GREATER: boolean := true
	);
	Port(
		clk, rst: in std_logic;
		input_a, input_b: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_valid: in std_logic;
		input_ready: out std_logic;
		output: out std_logic;
		output_valid: out std_logic;
		output_ready: in std_logic
	);
end COMPARATOR_AXI;

architecture Behavioral of COMPARATOR_AXI is
	signal output_reg: std_logic;
	signal output_valid_reg: std_logic;
	
	signal op_enable: std_logic;
	
	signal result: std_logic;
begin

	op_enable <= '1' when output_valid_reg = '0' or output_ready = '1' else '0';

	gen_equal: if IS_EQUAL and not IS_GREATER generate
		result <= '1' when input_a = input_b else '0';
	end generate;
	gen_not_equal: if not IS_EQUAL and not IS_GREATER generate
		result <= '1' when input_a /= input_b else '0';
	end generate;
	gen_signed_geq: if IS_SIGNED and IS_EQUAL and IS_GREATER generate
		result <= '1' when signed(input_a) >= signed(input_b) else '0';
	end generate;
	gen_signed_gt: if IS_SIGNED and not IS_EQUAL and IS_GREATER generate
		result <= '1' when signed(input_a) > signed(input_b) else '0';
	end generate;  
	gen_unsigned_geq: if not IS_SIGNED and IS_EQUAL and IS_GREATER generate
		result <= '1' when unsigned(input_a) >= unsigned(input_b) else '0';
	end generate;
	gen_unsigned_gt: if not IS_SIGNED and not IS_EQUAL and IS_GREATER generate
		result <= '1' when unsigned(input_a) > unsigned(input_b) else '0';
	end generate;  
	
	seq_update: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				output_valid_reg <= '0';
				output_reg <= '0';
			elsif op_enable = '1' then
				output_reg <= result;
				output_valid_reg <= input_valid;
			end if;
		end if;
	end process;
				 
	output_valid <= output_valid_reg;
	input_ready  <= op_enable;
	output		 <= output_reg;
	

end Behavioral;
