----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 14.02.2019 16:14:04
-- Design Name: 
-- Module Name: AXIS_SELECTOR - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Use a flag to select between two different inputs. Whichever one
--		is selected goes through to the output axis port. All three input AXIS
--		are synchronized before.
-- 
-- Dependencies: AXIS_SYNCHRONIZER_2
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.data_types.all;

entity AXIS_SELECTOR is
	generic (
		DATA_WIDTH: integer := 16
	);
	port (
		clk, rst		: in  std_logic;
		input_0_data	: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_0_ready	: out std_logic;
		input_0_valid	: in  std_logic;
		input_0_last	: in  std_logic := '0';
		input_1_data	: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_1_ready	: out std_logic;
		input_1_valid	: in  std_logic;
		input_1_last	: in  std_logic := '0';
		flag_data		: in  std_logic_vector(0 downto 0);
		flag_ready		: out std_logic;
		flag_valid		: in  std_logic;
		output_data		: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_valid	: out std_logic;
		output_ready	: in  std_logic;
		output_last		: out std_logic
	);
end AXIS_SELECTOR;

architecture Behavioral of AXIS_SELECTOR is

	--first joiner
	signal joint_inputs_valid, joint_inputs_ready, joint_inputs_last: std_logic;
	signal joint_inputs_false, joint_inputs_true: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--second joiner
	signal joint_flag_input_data: std_logic_vector(DATA_WIDTH*2 - 1 downto 0);
	signal final_joint_valid, final_joint_ready, final_joint_last: std_logic;
	signal final_joint_data: std_logic_vector(DATA_WIDTH*2 - 1 downto 0);
	signal final_joint_flag: std_logic_vector(0 downto 0);
	signal final_joint_data_false, final_joint_data_true: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
begin
	
	join_input_ports: entity work.AXIS_SYNCHRONIZER_2
		Generic map (
			DATA_WIDTH_0 => DATA_WIDTH,
			DATA_WIDTH_1 => DATA_WIDTH,
			LAST_POLICY  => AND_ALL
		)
		Port map (
			clk => clk, rst => rst,
			input_0_valid => input_0_valid,
			input_0_ready => input_0_ready,
			input_0_data  => input_0_data,
			input_0_last  => input_0_last,
			input_1_valid => input_1_valid,
			input_1_ready => input_1_ready,
			input_1_data  => input_1_data,
			input_1_last  => input_1_last,
			output_valid  => joint_inputs_valid,
			output_ready  => joint_inputs_ready,
			output_data_0 => joint_inputs_false,
			output_data_1 => joint_inputs_true,
			output_last   => joint_inputs_last
		);
		
	joint_flag_input_data <= joint_inputs_false & joint_inputs_true;
	join_flag: entity work.AXIS_SYNCHRONIZER_2
		Generic map (
			DATA_WIDTH_0 => DATA_WIDTH*2,
			DATA_WIDTH_1 => 1,
			LAST_POLICY  => PASS_ZERO
		)
		Port map (
			clk => clk, rst => rst,
			input_0_valid => joint_inputs_valid,
			input_0_ready => joint_inputs_ready,
			input_0_data  => joint_flag_input_data,
			input_0_last  => joint_inputs_last,
			input_1_valid => flag_valid,
			input_1_ready => flag_ready,
			input_1_data  => flag_data,
			output_valid  => final_joint_valid,
			output_ready  => final_joint_ready,
			output_data_0 => final_joint_data,
			output_data_1 => final_joint_flag,
			output_last   => final_joint_last
		);
		
	final_joint_data_false <= final_joint_data(DATA_WIDTH*2 - 1 downto DATA_WIDTH);
	final_joint_data_true <= final_joint_data(DATA_WIDTH - 1 downto 0);
	
	final_joint_ready <= output_ready;
	output_valid <= final_joint_valid;
	output_last  <= final_joint_last;
	
	output_data <= final_joint_data_false when final_joint_flag = "0" else final_joint_data_true;

end Behavioral;
