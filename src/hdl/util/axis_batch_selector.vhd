----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 14.02.2019 16:14:04
-- Design Name: 
-- Module Name: AXIS_BATCH_SELECTOR - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Use a flag to select between two different inputs. Whichever one
--		is selected goes through to the output axis port until last is asserted
--		according to the join policy specified
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
use work.constants.all;

entity AXIS_BATCH_SELECTOR is
	generic (
		DATA_WIDTH: integer := 16;
		LAST_POLICY: last_policy_t := PASS_ZERO
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
end AXIS_BATCH_SELECTOR;

architecture Behavioral of AXIS_BATCH_SELECTOR is
	--first joiner
	signal joint_inputs_valid, joint_inputs_ready, joint_inputs_last: std_logic;
	signal joint_inputs_false, joint_inputs_true: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	type batch_selector_state_t is (WAIT_FLAG, SENDING);
	signal state_curr, state_next: batch_selector_state_t;
	
	signal flag_buf, flag_buf_next: std_logic;
	
begin
	
	join_input_ports: entity work.AXIS_SYNCHRONIZER_2
		Generic map (
			DATA_WIDTH_0 => DATA_WIDTH,
			DATA_WIDTH_1 => DATA_WIDTH,
			LAST_POLICY  => LAST_POLICY
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
		
	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= WAIT_FLAG;
				flag_buf <= '0';
			else
				state_curr <= state_next;
				flag_buf <= flag_buf_next;
			end if;
		end if;
	end process;
	
	comb: process(state_curr, flag_valid, flag_data, output_ready, joint_inputs_valid, joint_inputs_last, joint_inputs_false, joint_inputs_true, flag_buf)
	begin
		flag_ready <= '0';
		flag_buf_next <= flag_buf;
		output_data <= (others => '0');
		output_valid <= '0';
		joint_inputs_ready <= '0';
		state_next <= state_curr;
	
		if state_curr = WAIT_FLAG then
			flag_ready <= '1';
			if flag_valid = '1' then
				flag_buf_next <= flag_data(0);
				state_next <= SENDING;
			end if;
		elsif state_curr = SENDING then
			joint_inputs_ready <= output_ready;
			output_valid <= joint_inputs_valid;
			if flag_buf = '0' then
				output_data <= joint_inputs_false;
			else
				output_data <= joint_inputs_true;
			end if;
			if output_ready = '1' and joint_inputs_valid = '1' then
				if joint_inputs_last = '1' then
					state_next <= WAIT_FLAG;
				end if;
			end if;
		end if;
	end process;
		
	
	output_last  <= joint_inputs_last;
	
end Behavioral;
