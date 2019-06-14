----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 15.02.2019 10:08:41
-- Design Name: 
-- Module Name: GOLOMB_CODING - Behavioral
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
use work.lcplc_functions.all;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.am_data_types.all;

entity GOLOMB_CODING is
	Generic (
		DATA_WIDTH: integer := 19;
		MAX_PARAM_VALUE: integer := 19;
		MAX_PARAM_VALUE_LOG: integer := 5;
		OUTPUT_WIDTH: integer := 39;
		--these two are just for performance reasons to operate over powers of two
		SLACK_LOG: integer := 4;
		MAX_1_OUT_LOG: integer := 5;
		LAST_POLICY: am_last_policy_t := AND_ALL
	);
	Port (
		clk, rst			: in	std_logic;
		input_param_data	: in	std_logic_vector(MAX_PARAM_VALUE_LOG - 1 downto 0);
		input_param_valid	: in	std_logic;
		input_param_ready	: out 	std_logic;
		input_param_last    : in 	std_logic;
		input_value_data	: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_value_valid	: in	std_logic;
		input_value_ready	: out 	std_logic;
		input_value_last	: in 	std_logic;
		output_code			: out	std_logic_vector(OUTPUT_WIDTH - 1 downto 0);
		output_length		: out	std_logic_vector(lcplc_bits(OUTPUT_WIDTH) - 1 downto 0);
		output_last 		: out 	std_logic;
		output_valid		: out	std_logic;
		output_ready		: in 	std_logic
	);
end GOLOMB_CODING;

architecture Behavioral of GOLOMB_CODING is
	--join signals first
	signal joint_valid, joint_ready, joint_last: std_logic;
	signal joint_param_data_raw: std_logic_vector(MAX_PARAM_VALUE_LOG - 1 downto 0);
	signal joint_param_data: natural range 0 to MAX_PARAM_VALUE;
	signal joint_value_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--calculate quotient and remainder
	signal quotient: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal remainder_base_mask, remainder_mask: std_logic_vector(MAX_PARAM_VALUE - 1 downto 0);
	signal remainder: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--fsm for control
	type golomb_coding_state_t is (IDLE, QUOTMEM_LAST, QUOTMEM_LONG);
	signal state_curr, state_next: golomb_coding_state_t;
	
	--buffers
	signal quotient_buff, quotient_buff_next, remainder_buff, remainder_buff_next: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal quotient_buff_extended: std_logic_vector(DATA_WIDTH downto 0);
	signal param_buff, param_buff_next: natural range 0 to MAX_PARAM_VALUE;
	signal last_buff, last_buff_next: std_logic;
	
	--checkers
	signal need_more_cycles: boolean;
	--last refer to when the quotient and remainder are both finally sent this cycle
	--temp refer to when need_more_cycles is up and more cycles are needed for this specific instance
		--only ones are output here
	signal output_code_last, output_code_temp: std_logic_vector(OUTPUT_WIDTH - 1 downto 0);
	signal output_length_last, output_length_temp: natural range 0 to OUTPUT_WIDTH;
	signal quotient_temp: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--output signals
	signal first_output_bits: natural range 0 to OUTPUT_WIDTH;
	constant base_out_zero	: std_logic_vector(OUTPUT_WIDTH - 1 downto 0) := (others => '0');
	constant base_out_one	: std_logic_vector(OUTPUT_WIDTH - 1 downto 0) := (others => '1');
begin
	
	assert MAX_PARAM_VALUE + 2**SLACK_LOG < OUTPUT_WIDTH
		report "Slack is too much"
		severity failure;
		
	assert 2**MAX_1_OUT_LOG <= OUTPUT_WIDTH
		report "Output won't fit"
		severity failure;
	
	--join both input signals
	data_joiner: entity work.AXIS_SYNCHRONIZER_2
		generic map (
			DATA_WIDTH_0 => MAX_PARAM_VALUE_LOG,
			DATA_WIDTH_1 => DATA_WIDTH,
			LAST_POLICY  => LAST_POLICY
		)
		port map (
			clk => clk, rst => rst,
			input_0_valid => input_param_valid,
			input_0_ready => input_param_ready,
			input_0_data  => input_param_data,
			input_0_last  => input_param_last,
			input_1_valid => input_value_valid,
			input_1_ready => input_value_ready,
			input_1_data  => input_value_data,
			input_1_last  => input_value_last,
			output_valid  => joint_valid,
			output_ready  => joint_ready,
			output_data_0 => joint_param_data_raw,
			output_data_1 => joint_value_data,
			output_last   => joint_last
		);
	
	joint_param_data <= to_integer(unsigned(joint_param_data_raw));

	remainder_base_mask <= (others => '1');
	remainder_mask <= std_logic_vector(shift_right(unsigned(remainder_base_mask), MAX_PARAM_VALUE - joint_param_data));
	remainder <= remainder_mask(remainder'high downto 0) and joint_value_data;
	
	quotient <= std_logic_vector(shift_right(unsigned(joint_value_data), joint_param_data));
	
	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= IDLE;
				quotient_buff  <= (others => '0');
				remainder_buff <= (others => '0');
				param_buff <= 0;
				last_buff <= '0';
			else
				state_curr <= state_next;
				quotient_buff  <= quotient_buff_next;
				remainder_buff <= remainder_buff_next;
				param_buff <= param_buff_next;
				last_buff <= last_buff_next;
			end if;
		end if;
	end process;
	
	comb: process(
		state_curr, 
		joint_valid, 
		quotient, remainder, joint_param_data, 
		need_more_cycles,
		last_buff, joint_last,
		quotient_buff, remainder_buff, param_buff, 
		quotient_temp, output_code_last, output_length_last, output_ready, output_code_temp, output_length_temp)
	begin
		state_next <= state_curr;
		joint_ready <= '0';
		output_valid <= '0';
		--buffers
		quotient_buff_next <= quotient_buff;
		remainder_buff_next <= remainder_buff;
		param_buff_next <= param_buff;
		last_buff_next <= last_buff;
		--outputs
		output_code   <= (others => '0');
		output_length <= (others => '0');
		output_last   <= '0';
		
		if state_curr = IDLE then
			joint_ready <= '1';
			if joint_valid = '1' then
				quotient_buff_next <= quotient;
				remainder_buff_next <= remainder;
				param_buff_next <= joint_param_data;
				last_buff_next <= joint_last;
				if quotient(DATA_WIDTH - 1 downto SLACK_LOG) /= (DATA_WIDTH - 1 downto SLACK_LOG => '0') then
					state_next <= QUOTMEM_LONG;
				else
					state_next <= QUOTMEM_LAST;
				end if;
			end if;
		elsif state_curr = QUOTMEM_LAST then
			output_valid 	<= '1';
			output_code 	<= output_code_last;
			output_length 	<= std_logic_vector(to_unsigned(output_length_last, output_length'length));
			output_last 	<= last_buff;
			if output_ready = '1' then
				joint_ready <= '1';
				if joint_valid = '1' then
					quotient_buff_next <= quotient;
					remainder_buff_next <= remainder;
					param_buff_next <= joint_param_data;
					last_buff_next <= joint_last;
					if quotient(DATA_WIDTH - 1 downto SLACK_LOG) /= (DATA_WIDTH - 1 downto SLACK_LOG => '0') then
						state_next <= QUOTMEM_LONG;
					else
						state_next <= QUOTMEM_LAST;
					end if;
				else
					state_next <= IDLE;
				end if;
			end if;
		elsif state_curr = QUOTMEM_LONG then
			output_valid <= '1';
			output_code <= output_code_temp;
			output_length <= std_logic_vector(to_unsigned(output_length_temp, output_length'length));
			if output_ready = '1' then
				--only update quotient if we send data ofc
				quotient_buff_next <= quotient_temp;
				if quotient_temp(DATA_WIDTH - 1 downto SLACK_LOG) = (DATA_WIDTH - 1 downto SLACK_LOG => '0') then
					state_next <= QUOTMEM_LAST;
				end if;
			end if;
		end if;
	end process;
	
	quotient_buff_extended <= '0' & quotient_buff; --just in case of overflows add 1 extra bit (very rare but possible)
	--the -1 on output_width is important because we need one extra bit for the ZERO after all the QUOTIENT_BUFF ones
	--need_more_cycles <= true when unsigned(quotient_buff_extended) + to_unsigned(param_buff, DATA_WIDTH + 1) > to_unsigned(OUTPUT_WIDTH - 1, DATA_WIDTH + 1) else false;
	need_more_cycles <= quotient_buff(DATA_WIDTH - 1 downto SLACK_LOG) /= (DATA_WIDTH - 1 downto SLACK_LOG => '0');
	
	output_code_temp <= (others => '1');
	output_length_temp <= 2**MAX_1_OUT_LOG when quotient_buff(DATA_WIDTH - 1 downto MAX_1_OUT_LOG) /= (DATA_WIDTH - 1 downto MAX_1_OUT_LOG => '0') else to_integer(unsigned(quotient_buff));
		
	--quotient_temp <= std_logic_vector(unsigned(quotient_buff) - to_unsigned(output_length_temp, DATA_WIDTH));
	quotient_temp <= 
		std_logic_vector(unsigned(quotient_buff) - to_unsigned(2**MAX_1_OUT_LOG, DATA_WIDTH))
			when quotient_buff(DATA_WIDTH - 1 downto MAX_1_OUT_LOG) /= (DATA_WIDTH - 1 downto MAX_1_OUT_LOG => '0') 
		else (others => '0');
	
	output_code_last	<= std_logic_vector(shift_left(unsigned(base_out_one), param_buff + 1)) 
		or std_logic_vector(resize(unsigned(remainder_buff), output_code_last'length)); -- ((OUTPUT_WIDTH - 1 downto DATA_WIDTH => '0') & remainder_buff);
	output_length_last	<= param_buff + 1 + to_integer(unsigned(quotient_buff)); 	


end Behavioral;
