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
use IEEE.NUMERIC_STD.ALL;

entity ERROR_MAPPER is
	Generic (
		DATA_WIDTH: integer := 16;
		USER_WIDTH: integer := 1
	);
	Port (
		clk, rst: std_logic;
		input_ready	: out std_logic;
		input_valid	: in  std_logic;
		input_data	: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_last	: in  std_logic := '0';
		input_user  : in  std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		output_ready: in  std_logic;
		output_valid: out std_logic;
		output_data	: out std_logic_vector(DATA_WIDTH downto 0);
		output_last : out std_logic;
		output_user : out std_logic_vector(USER_WIDTH - 1 downto 0)
	);
end ERROR_MAPPER;

architecture Behavioral of ERROR_MAPPER is
	signal input_is_positive: boolean;

	signal input_sign_extended, input_neg: std_logic_vector(DATA_WIDTH downto 0);
	signal input_neg_shifted: std_logic_vector(DATA_WIDTH downto 0);
	signal input_shifted    : std_logic_vector(DATA_WIDTH downto 0);
	signal input_shifted_m1 : std_logic_vector(DATA_WIDTH downto 0);
	
begin

	output_last  <= input_last;
	input_ready  <= output_ready;
	output_valid <= input_valid;
	output_user  <= input_user;
	
	input_is_positive <= signed(input_data) > to_signed(0, input_data'length);
	
	input_sign_extended <= input_data(DATA_WIDTH - 1) & input_data;
	input_neg <= std_logic_vector(-signed(input_sign_extended));
	
	input_neg_shifted <= input_neg(DATA_WIDTH - 1 downto 0) & '0';
	input_shifted	  <= input_data(DATA_WIDTH - 1 downto 0) & '0';
	input_shifted_m1  <= std_logic_vector(unsigned(input_shifted) - to_unsigned(1, DATA_WIDTH + 1));
	
	output_data <= input_shifted_m1 when input_is_positive else input_neg_shifted;
	
end Behavioral;
