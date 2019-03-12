----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
--
-- Create Date: 13.02.2019 09:26:22
-- Design Name: 
-- Module Name: AXIS_SPLITTER_3 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Instantiation of AXIS_SPLITTER_BASE with 3 output buses
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

entity AXIS_SPLITTER_3 is
	Generic (
		DATA_WIDTH: positive := 32
	);
	Port (
		clk, rst		: in 	std_logic;
		--to input axi port
		input_valid		: in	STD_LOGIC;
		input_data		: in	STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		input_ready		: out	STD_LOGIC;
		input_last		: in 	std_logic;
		--to output axi ports
		output_0_valid	: out 	std_logic;
		output_0_data	: out 	STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
		output_0_ready	: in 	std_logic;
		output_0_last 	: out 	std_logic;
		output_1_valid	: out 	std_logic;
		output_1_data	: out 	STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
		output_1_ready	: in 	std_logic;
		output_1_last 	: out 	std_logic;
		output_2_valid	: out 	std_logic;
		output_2_data	: out 	STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
		output_2_ready	: in 	std_logic;
		output_2_last 	: out 	std_logic
	);
end AXIS_SPLITTER_3;

architecture Behavioral of AXIS_SPLITTER_3 is
	signal output_valid_inner: std_logic_vector(2 downto 0);
	signal output_ready_inner: std_logic_vector(2 downto 0);
	signal output_data_inner: std_logic_vector(DATA_WIDTH-1 downto 0);
	signal output_last_inner: std_logic;
begin

	output_0_valid <= output_valid_inner(0);
	output_1_valid <= output_valid_inner(1);										 
	output_2_valid <= output_valid_inner(2);
	output_ready_inner <= output_2_ready & output_1_ready & output_0_ready;
	output_0_data      <= output_data_inner;
	output_1_data      <= output_data_inner;
	output_2_data      <= output_data_inner;
	output_0_last 	   <= output_last_inner;
	output_1_last      <= output_last_inner;
	output_2_last      <= output_last_inner;

	generic_axi_splitter: entity work.AXIS_SPLITTER_BASE
		Generic map ( DATA_WIDTH => DATA_WIDTH, OUTPUT_PORTS => 3)
		Port map (
			clk => clk, rst => rst,
			input_valid => input_valid,
			input_data => input_data,
			input_ready => input_ready,
			input_last  => input_last,
			output_valid => output_valid_inner,
			output_ready => output_ready_inner,
			output_data => output_data_inner,
			output_last => output_last_inner
		);

end Behavioral;
