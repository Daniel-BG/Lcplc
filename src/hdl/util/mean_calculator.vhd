----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.02.2019 16:45:31
-- Design Name: 
-- Module Name: mean_calculator - Behavioral
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

entity MEAN_CALCULATOR is
	Generic (
		DATA_WIDTH: integer := 36;
		ACC_LOG: integer := 8;
		IS_SIGNED: boolean := true
	);
	Port (
		clk, rst: in std_logic;
		input: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_valid: in std_logic;
		input_ready: out std_logic;
		output_data: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_valid: out std_logic;
		output_ready: in std_logic
	);
end MEAN_CALCULATOR;

architecture Behavioral of MEAN_CALCULATOR is
	signal output_tmp: std_logic_vector(DATA_WIDTH + ACC_LOG - 1 downto 0);
begin

	accumulator: entity work.ACCUMULATOR
		Generic map (
			DATA_WIDTH  => DATA_WIDTH,
			ACC_LOG		=> ACC_LOG,
			IS_SIGNED	=> IS_SIGNED
		)
		Port map (
			clk => clk, rst => rst,
			input => input,
			input_valid => input_valid,
			input_ready	=> input_ready,
			output_data => output_tmp,
			output_valid => output_valid,
			output_ready => output_ready
		);
		
	output_data <= output_tmp(DATA_WIDTH + ACC_LOG - 1 downto ACC_LOG);


end Behavioral;
