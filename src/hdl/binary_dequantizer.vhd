----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12.02.2019 09:19:13
-- Design Name: 
-- Module Name: binary_dequantizer - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

entity BINARY_DEQUANTIZER is
	Generic (
		--0 leaves it the same
		SHIFT_WIDTH : integer := 4;
		DATA_WIDTH	: integer := 16;
		USER_WIDTH	: integer := 1
	);
	Port (
		clk, rst: std_logic;
		input_ready	: out std_logic;
		input_valid	: in  std_logic;
		input_data	: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_last  : in  std_logic := '0';
		input_user	: in  std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		output_ready: in  std_logic;
		output_valid: out std_logic;
		output_data	: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_last : out std_logic;
		output_user : out std_logic_vector(USER_WIDTH - 1 downto 0);
		--configuration ports
		input_shift	: in  std_logic_vector(SHIFT_WIDTH - 1 downto 0)
	);
end BINARY_DEQUANTIZER;

architecture Behavioral of BINARY_DEQUANTIZER is
	
begin

	output_data <= std_logic_vector(shift_left(signed(input_data), to_integer(unsigned(input_shift))));
	output_valid <= input_valid;
	input_ready <= output_ready;
	output_last <= input_last;
	output_user <= input_user;

end Behavioral;
