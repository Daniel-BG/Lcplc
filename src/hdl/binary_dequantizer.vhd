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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity BINARY_DEQUANTIZER is
	Generic (
		--up=1, down=0 leaves it the same
		UPSHIFT: integer := 1;
		DOWNSHIFT_MINUS_1: integer := 0;
		DATA_WIDTH: integer := 16
	);
	Port (
		clk, rst: std_logic;
		input_ready: out std_logic;
		input_valid: in std_logic;
		input: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_ready: in std_logic;
		output_valid: out std_logic;
		output: out std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end BINARY_DEQUANTIZER;

architecture Behavioral of BINARY_DEQUANTIZER is

	signal input_sign_extended: std_logic_vector(DATA_WIDTH downto 0);
	signal abs_val: std_logic_vector(DATA_WIDTH downto 0);
	
	signal shifted_down: std_logic_vector(DATA_WIDTH downto 0);

	signal pre_out: std_logic_vector(DATA_WIDTH downto 0);
	
begin

	
	--no segmentation done yet
	output_valid <= input_valid;
	input_ready  <= output_ready;

	input_sign_extended <= input(DATA_WIDTH - 1) & input;
	abs_val <= input_sign_extended when input(DATA_WIDTH - 1) = '0' else std_logic_vector(-signed(input_sign_extended));
	
	shifted_down <= abs_val(DATA_WIDTH downto UPSHIFT - DOWNSHIFT_MINUS_1 - 1) & (UPSHIFT - DOWNSHIFT_MINUS_1 - 2 downto 0 => '0');

	pre_out <= shifted_down when input(DATA_WIDTH - 1) = '0' else std_logic_vector(-signed(shifted_down));
	output <= pre_out(DATA_WIDTH - 1 downto 0);

end Behavioral;
