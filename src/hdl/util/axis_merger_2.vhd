----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 14.02.2019 12:54:33
-- Design Name: 
-- Module Name: AXIS_MERGER_2 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Sucessively connect the inputs to the output until the corresponding
--		last is asserted
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

entity AXIS_MERGER_2 is
	Generic (
		DATA_WIDTH: integer := 16;
		START_ON_PORT: integer := 0
	);
	Port ( 
		clk, rst: in std_logic;
		--to input axi port
		input_0_valid	: in	std_logic;
		input_0_ready	: out	std_logic;
		input_0_data	: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_0_last	: in	std_logic;
		input_1_valid	: in	std_logic;
		input_1_ready	: out	std_logic;
		input_1_data	: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_1_last	: in 	std_logic;
		--to output axi ports
		output_valid	: out 	std_logic;
		output_ready	: in 	std_logic;
		output_data		: out	std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_last		: out 	std_logic
	);
end AXIS_MERGER_2;

architecture Behavioral of AXIS_MERGER_2 is
	constant NUMBER_OF_PORTS: integer := 2;

	signal joint_valid, joint_ready, joint_last: std_logic_vector(NUMBER_OF_PORTS-1 downto 0);
	signal joint_data: std_logic_vector(NUMBER_OF_PORTS*DATA_WIDTH - 1 downto 0);
	
begin

	joint_valid	<= input_1_valid & input_0_valid;
	input_1_ready <= joint_ready(1);
	input_0_ready <= joint_ready(0);
	joint_data	<= input_1_data  & input_0_data;
	joint_last	<= input_1_last  & input_0_last;

	merger_base: entity work.AXIS_MERGER_BASE	
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			NUMBER_OF_PORTS => NUMBER_OF_PORTS,
			START_ON_PORT => 0
		)
		Port map ( 
			clk => clk, rst => rst,
			input_valid 	=> joint_valid,
			input_ready 	=> joint_ready,
			input_data 		=> joint_data,
			input_last 		=> joint_last,
			output_valid	=> output_valid,
			output_ready	=> output_ready,
			output_data		=> output_data,
			output_last 	=> output_last
		);
		
end Behavioral;
