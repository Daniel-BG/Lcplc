----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12.02.2019 09:18:01
-- Design Name: 
-- Module Name: binary_quantizer - Behavioral
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

entity BINARY_QUANTIZER is
	Generic (
		--up=1, down=0 leaves it the same
		UPSHIFT: integer := 1;
		DOWNSHIFT_MINUS_1: integer := 0;
		DATA_WIDTH: integer := 16
	);
	Port (
		clk, rst: std_logic;
		input_ready	: out std_logic;
		input_valid	: in  std_logic;
		input_data	: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_last	: in  std_logic;
		output_ready: in  std_logic;
		output_valid: out std_logic;
		output_data	: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_last : out std_logic
	);
end BINARY_QUANTIZER;

architecture Behavioral of BINARY_QUANTIZER is
	signal input_sign_extended: std_logic_vector(DATA_WIDTH downto 0);
	signal abs_val: std_logic_vector(DATA_WIDTH downto 0);
	
	signal shifted_up, added_downshift: std_logic_vector(DATA_WIDTH + UPSHIFT downto 0);
	signal downshifted, downshifted_inverse: std_logic_vector(DATA_WIDTH downto 0);
begin
	
	output_valid <= input_valid;
	input_ready  <= output_ready;
	output_last  <= input_last;

	input_sign_extended <= input_data(DATA_WIDTH - 1) & input_data;
	abs_val <= input_sign_extended when input_data(DATA_WIDTH - 1) = '0' else std_logic_vector(-signed(input_sign_extended));

	shifted_up <= abs_val & (UPSHIFT - 1 downto 0 => '0');
	added_downshift <= std_logic_vector(unsigned(shifted_up) + to_unsigned(2**DOWNSHIFT_MINUS_1, DATA_WIDTH + UPSHIFT + 1));
	
	gen_downshift_a: if DOWNSHIFT_MINUS_1 <= UPSHIFT - 1 generate
		downshifted <= added_downshift(DOWNSHIFT_MINUS_1 + 1 + DATA_WIDTH downto DOWNSHIFT_MINUS_1 + 1);
	end generate;
	gen_downshift_b: if DOWNSHIFT_MINUS_1 > UPSHIFT - 1 generate
		downshifted <= (DOWNSHIFT_MINUS_1 + 1 + DATA_WIDTH downto DATA_WIDTH + UPSHIFT + 1 => '0') & added_downshift(DATA_WIDTH + UPSHIFT downto DOWNSHIFT_MINUS_1 + 1);
	end generate;
	
	downshifted_inverse <= std_logic_vector(-signed(downshifted));
	output_data <= downshifted(DATA_WIDTH - 1 downto 0) when input_data(DATA_WIDTH - 1) = '0' else downshifted_inverse(DATA_WIDTH - 1 downto 0);
	
end Behavioral;
