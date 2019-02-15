----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.02.2019 16:59:23
-- Design Name: 
-- Module Name: op_axi_mp - Behavioral
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

entity MULT_AXI_MP is
	Generic (
		DATA_WIDTH: integer := 16;
		IS_ADD: boolean := true;
		IS_SIGNED: boolean := true
	);
	Port(
		clk, rst: in std_logic;
		input_a_data: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_a_valid: in std_logic;
		input_a_ready: out std_logic;
		input_b_data: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_b_valid: in std_logic;
		input_b_ready: out std_logic;
		output: out std_logic_vector(DATA_WIDTH*2 - 1 downto 0);
		output_valid: out std_logic;
		output_ready: in std_logic
	);
end MULT_AXI_MP;

architecture Behavioral of MULT_AXI_MP is
	signal joint_valid, joint_ready: std_logic;
	signal joint_data_a, joint_data_b: std_logic_vector(DATA_WIDTH - 1 downto 0);
begin

	data_joiner: entity work.JOINER_AXI_2
		generic map (
			DATA_WIDTH_0 => DATA_WIDTH,
			DATA_WIDTH_1 => DATA_WIDTH
		)
		port map (
			clk => clk, rst => rst,
			input_valid_0 => input_a_valid,
			input_ready_0 => input_a_ready,
			input_data_0  => input_a_data,
			input_valid_1 => input_b_valid,
			input_ready_1 => input_b_ready,
			input_data_1  => input_b_data,
			output_valid  => joint_valid,
			output_ready  => joint_ready,
			output_data_0 => joint_data_a,
			output_data_1 => joint_data_b
		);

	raw_op_calc: entity work.MULT_AXI
		Generic map (
			DATA_WIDTH => DATA_WIDTH
		)
		Port map(
			clk => clk, rst => rst,
			input_a => joint_data_a, 
			input_b => joint_data_b,
			input_valid => joint_valid,
			input_ready => joint_ready,
			output => output,
			output_valid => output_valid,
			output_ready => output_ready
		);
		
		
end Behavioral;
