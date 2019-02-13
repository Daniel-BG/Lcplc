----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12.02.2019 15:25:16
-- Design Name: 
-- Module Name: error_mapper - Behavioral
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

entity ERROR_MAPPER is
	Generic (
		DATA_WIDTH: integer := 16
	);
	Port (
		clk, rst: std_logic;
		input_ready: out std_logic;
		input_valid: in std_logic;
		input: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_ready: in std_logic;
		output_valid: out std_logic;
		output: out std_logic_vector(DATA_WIDTH downto 0)
	);
end ERROR_MAPPER;

architecture Behavioral of ERROR_MAPPER is
	signal input_is_positive: std_logic;

	signal input_sign_extended, input_neg: std_logic_vector(DATA_WIDTH downto 0);
	signal input_neg_shifted: std_logic_vector(DATA_WIDTH downto 0);
	signal input_shifted    : std_logic_vector(DATA_WIDTH downto 0);
	signal input_shifted_m1 : std_logic_vector(DATA_WIDTH downto 0);
	
begin

	input_ready <= output_ready;
	output_valid <= input_valid;
	
	input_is_positive <= not input(DATA_WIDTH - 1);
	
	input_sign_extended <= input(DATA_WIDTH - 1) & input;
	input_neg <= std_logic_vector(-signed(input_sign_extended));
	
	input_neg_shifted <= input_neg(DATA_WIDTH - 1 downto 0) & '0';
	input_shifted	  <= input    (DATA_WIDTH - 1 downto 0) & '0';
	input_shifted_m1  <= std_logic_vector(unsigned(input_shifted) - to_unsigned(1, DATA_WIDTH + 1));
	
	output <= input_shifted_m1 when input_is_positive = '1' else input_neg_shifted;
	
end Behavioral;
