----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.02.2019 16:14:04
-- Design Name: 
-- Module Name: SELECTOR_AXI_MP - Behavioral
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

entity SELECTOR_AXI_MP is
	generic (
		DATA_WIDTH: integer := 16
	);
	port (
		clk, rst:			in	std_logic;
		input_false_data:	in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_false_ready:	out std_logic;
		input_false_valid:	in 	std_logic;
		input_true_data:	in 	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_true_ready:	out	std_logic;
		input_true_valid:	in	std_logic;
		flag_data:			in	std_logic_vector(0 downto 0);
		flag_ready:			out	std_logic;
		flag_valid:			in	std_logic;
		output_data:		out std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_valid:		out std_logic;
		output_ready:		in	std_logic
	);
end SELECTOR_AXI_MP;

architecture Behavioral of SELECTOR_AXI_MP is

	--first joiner
	signal joint_inputs_valid, joint_inputs_ready: std_logic;
	signal joint_inputs_false, joint_inputs_true: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--second joiner
	signal joint_flag_input_data: std_logic_vector(DATA_WIDTH*2 - 1 downto 0);
	signal final_joint_valid, final_joint_ready: std_logic;
	signal final_joint_data: std_logic_vector(DATA_WIDTH*2 - 1 downto 0);
	signal final_joint_flag: std_logic_vector(0 downto 0);
	signal final_joint_data_false, final_joint_data_true: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
begin
	
	join_input_ports: entity work.JOINER_AXI_2
		Generic map (
			DATA_WIDTH_0 => DATA_WIDTH,
			DATA_WIDTH_1 => DATA_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			input_valid_0 => input_false_valid,
			input_valid_1 => input_true_valid,
			input_ready_0 => input_false_ready,
			input_ready_1 => input_true_ready,
			input_data_0  => input_false_data,
			input_data_1  => input_true_data,
			output_valid  => joint_inputs_valid,
			output_ready  => joint_inputs_ready,
			output_data_0 => joint_inputs_false,
			output_data_1 => joint_inputs_true
		);
		
	joint_flag_input_data <= joint_inputs_false & joint_inputs_true;
	join_flag: entity work.JOINER_AXI_2
		Generic map (
			DATA_WIDTH_0 => DATA_WIDTH*2,
			DATA_WIDTH_1 => 1
		)
		Port map (
			clk => clk, rst => rst,
			input_valid_0 => joint_inputs_valid,
			input_ready_0 => joint_inputs_ready,
			input_data_0  => joint_flag_input_data,
			input_valid_1 => flag_valid,
			input_ready_1 => flag_ready,
			input_data_1  => flag_data,
			output_valid  => final_joint_valid,
			output_ready  => final_joint_ready,
			output_data_0 => final_joint_data,
			output_data_1 => final_joint_flag
		);
		
	final_joint_data_false <= final_joint_data(DATA_WIDTH*2 - 1 downto DATA_WIDTH);
	final_joint_data_true <= final_joint_data(DATA_WIDTH - 1 downto 0);
	
	raw_selector: entity work.SELECTOR_AXI 
		generic map (
			DATA_WIDTH => DATA_WIDTH
		)
		port map (
			input_data_false=> final_joint_data_false,
			input_data_true => final_joint_data_true,
			input_flag		=> final_joint_flag(0),
			input_ready		=> final_joint_ready,
			input_valid		=> final_joint_valid,
			output_data		=> output_data,
			output_valid	=> output_valid,
			output_ready	=> output_ready
		);
		
	

end Behavioral;
