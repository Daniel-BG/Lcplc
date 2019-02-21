----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 13.02.2019 09:26:22
-- Design Name: 
-- Module Name: splitter_axi_2 - Behavioral
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

entity SPLITTER_AXI_4 is
	Generic (
		DATA_WIDTH: positive := 32
	);
	Port (
		clk, rst		: in 	std_logic;
		--to input axi port
		input_valid		: in	STD_LOGIC;
		input_data		: in	STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		input_ready		: out	STD_LOGIC;
		--to output axi ports
		output_0_valid	: out 	std_logic;
		output_0_data	: out 	STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
		output_0_ready	: in 	std_logic;
		output_1_valid	: out 	std_logic;
		output_1_data	: out 	STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
		output_1_ready	: in 	std_logic;
		output_2_valid	: out 	std_logic;
		output_2_data	: out 	STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
		output_2_ready	: in 	std_logic;
		output_3_valid	: out 	std_logic;
		output_3_data	: out 	STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
		output_3_ready	: in 	std_logic
	);
end SPLITTER_AXI_4;

architecture Behavioral of SPLITTER_AXI_4 is
	signal output_valid_inner: std_logic_vector(3 downto 0);
	signal output_ready_inner: std_logic_vector(3 downto 0);
	signal output_data_inner: std_logic_vector(DATA_WIDTH-1 downto 0);
begin

	output_0_valid <= output_valid_inner(0);
	output_1_valid <= output_valid_inner(1);										 
	output_2_valid <= output_valid_inner(2);
	output_3_valid <= output_valid_inner(3);
	output_ready_inner <= output_3_ready & output_2_ready & output_1_ready & output_0_ready;
	output_0_data      <= output_data_inner;
	output_1_data      <= output_data_inner;
	output_2_data      <= output_data_inner;
	output_3_data      <= output_data_inner;

	generic_axi_splitter: entity work.splitter_axi
		Generic map ( DATA_WIDTH => DATA_WIDTH, OUTPUT_PORTS => 4)
		Port map (
			clk => clk, rst => rst,
			input_valid => input_valid,
			input_data => input_data,
			input_ready => input_ready,
			output_valid => output_valid_inner,
			output_ready => output_ready_inner,
			output_data => output_data_inner
		);

end Behavioral;
