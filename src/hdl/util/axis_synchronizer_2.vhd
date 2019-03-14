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
use work.data_types.all;

entity AXIS_SYNCHRONIZER_2 is
	Generic (
		DATA_WIDTH_0: integer := 32;
		DATA_WIDTH_1: integer := 32;
		LATCH: boolean := true;
		LAST_POLICY: last_policy_t := PASS_ZERO;
		USER_WIDTH: integer := 1;
		USER_POLICY: last_policy_t := PASS_ZERO
	);
	Port (
		clk, rst: in std_logic;
		--to input axi port
		input_0_valid: in  std_logic;
		input_0_ready: out std_logic;
		input_0_data : in  std_logic_vector(DATA_WIDTH_0 - 1 downto 0);
		input_0_last : in  std_logic := '0';
		input_0_user : in  std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		input_1_valid: in  std_logic;
		input_1_ready: out std_logic; 
		input_1_data : in  std_logic_vector(DATA_WIDTH_1 - 1 downto 0);
		input_1_last : in  std_logic := '0';
		input_1_user : in  std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		--to output axi ports
		output_valid	: out std_logic;
		output_ready	: in  std_logic;
		output_data_0	: out std_logic_vector(DATA_WIDTH_0 - 1 downto 0);
		output_data_1	: out std_logic_vector(DATA_WIDTH_1 - 1 downto 0);
		output_last		: out std_logic;
		output_user		: out std_logic_vector(USER_WIDTH - 1 downto 0)
	);
end AXIS_SYNCHRONIZER_2;

architecture Behavioral of AXIS_SYNCHRONIZER_2 is
	signal output_last_0, output_last_1: std_logic;
	signal output_user_0, output_user_1: std_logic_vector(USER_WIDTH - 1 downto 0);
begin

	gen_latched_version: if LATCH generate
		latched_version: entity work.AXIS_SYNCHRONIZER_LATCHED_2
		generic map (
				DATA_WIDTH_0 => DATA_WIDTH_0,
				DATA_WIDTH_1 => DATA_WIDTH_1,
				LAST_POLICY  => LAST_POLICY,
				USER_WIDTH   => USER_WIDTH,
				USER_POLICY  => USER_POLICY
			)
		port map (
				clk => clk, rst => rst,
				input_0_valid => input_0_valid,
				input_0_ready => input_0_ready,
				input_0_data  => input_0_data,
				input_0_last  => input_0_last,
				input_0_user  => input_0_user,
				input_1_valid => input_1_valid,
				input_1_ready => input_1_ready,
				input_1_data  => input_1_data,
				input_1_last  => input_1_last,
				input_1_user  => input_1_user,
				output_valid  => output_valid,
				output_ready  => output_ready,
				output_data_0 => output_data_0,
				output_data_1 => output_data_1,
				output_last_0 => output_last_0,
				output_last_1 => output_last_1,
				output_user_0 => output_user_0,
				output_user_1 => output_user_1
			);
	end generate;

	gen_passthrough_version: if not LATCH generate
		passthrough_version: entity work.AXIS_SYNCHRONIZER_PASSTHROUGH_2
		generic map (
				DATA_WIDTH_0 => DATA_WIDTH_0,
				DATA_WIDTH_1 => DATA_WIDTH_1,
				LAST_POLICY  => LAST_POLICY
			)
		port map (
				clk => clk, rst => rst,
				input_0_valid => input_0_valid,
				input_0_ready => input_0_ready,
				input_0_data  => input_0_data,
				input_0_last  => input_0_last,
				input_0_user  => input_0_user,
				input_1_valid => input_1_valid,
				input_1_ready => input_1_ready,
				input_1_data  => input_1_data,
				input_1_last  => input_1_last,
				input_1_user  => input_1_user,
				output_valid  => output_valid,
				output_ready  => output_ready,
				output_data_0 => output_data_0,
				output_data_1 => output_data_1,
				output_last_0 => output_last_0,
				output_last_1 => output_last_1,
				output_user_0 => output_user_0,
				output_user_1 => output_user_1
			);
	end generate;
	
	
	gen_pass_0  : if LAST_POLICY = PASS_ZERO generate	
		output_last <= output_last_0; 
		output_user <= output_user_0;
	end generate;
	gen_pass_1  : if LAST_POLICY = PASS_ONE  generate	
		output_last <= output_last_1;
		output_user <= output_user_1; 
	end generate;
	gen_pass_or : if LAST_POLICY = OR_ALL    generate	
		output_last <= output_last_0 or  output_last_1; 
		output_user <= output_user_0 or  output_user_1;
	end generate;
	gen_pass_and: if LAST_POLICY = AND_ALL   generate	
		output_last <= output_last_0 and output_last_1;
		output_user <= output_user_0 and output_user_1; 
	end generate;
		
	
end Behavioral;
