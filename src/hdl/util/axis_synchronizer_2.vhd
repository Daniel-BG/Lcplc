----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 12.02.2019 19:01:39
-- Design Name: 
-- Module Name: AXIS_SYNCHRONIZER_2 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Synchronize two axis streams into only one. 
--		Data outputs are kept separate for ease of use
--		Can select if the control flow is latched (critical path is lower but
--		resource usage is higher) or not (higher critical path but less resources)
-- 
-- Dependencies: None
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity AXIS_SYNCHRONIZER_2 is
	Generic (
		DATA_WIDTH_0: integer := 32;
		DATA_WIDTH_1: integer := 32;
		LATCH: boolean := true
	);
	Port (
		clk, rst: in std_logic;
		--to input axi port
		input_0_valid: in  std_logic;
		input_0_ready: out std_logic;
		input_0_data : in  std_logic_vector(DATA_WIDTH_0 - 1 downto 0);
		input_1_valid: in  std_logic;
		input_1_ready: out std_logic; 
		input_1_data : in  std_logic_vector(DATA_WIDTH_1 - 1 downto 0);
		--to output axi ports
		output_valid	: out 	STD_LOGIC;
		output_ready	: in 	STD_LOGIC;
		output_data_0	: out std_logic_vector(DATA_WIDTH_0 - 1 downto 0);
		output_data_1	: out std_logic_vector(DATA_WIDTH_1 - 1 downto 0)
	);
end AXIS_SYNCHRONIZER_2;

architecture Behavioral of AXIS_SYNCHRONIZER_2 is
begin

	gen_latched_version: if LATCH generate
		latched_version: entity work.AXIS_SYNCHRONIZER_LATCHED_2
		generic map (
				DATA_WIDTH_0 => DATA_WIDTH_0,
				DATA_WIDTH_1 => DATA_WIDTH_1
			)
		port map (
				clk => clk, rst => rst,
				input_0_valid => input_0_valid,
				input_0_ready => input_0_ready,
				input_0_data  => input_0_data,
				input_1_valid => input_1_valid,
				input_1_ready => input_1_ready,
				input_1_data  => input_1_data,
				output_valid  => output_valid,
				output_ready  => output_ready,
				output_data_0 => output_data_0,
				output_data_1 => output_data_1
			);
	end generate;

	gen_passthrough_version: if not LATCH generate
		passthrough_version: entity work.AXIS_SYNCHRONIZER_PASSTHROUGH_2
		generic map (
				DATA_WIDTH_0 => DATA_WIDTH_0,
				DATA_WIDTH_1 => DATA_WIDTH_1
			)
		port map (
				clk => clk, rst => rst,
				input_0_valid => input_0_valid,
				input_0_ready => input_0_ready,
				input_0_data  => input_0_data,
				input_1_valid => input_1_valid,
				input_1_ready => input_1_ready,
				input_1_data  => input_1_data,
				output_valid  => output_valid,
				output_ready  => output_ready,
				output_data_0 => output_data_0,
				output_data_1 => output_data_1
			);
	end generate;
	
end Behavioral;
