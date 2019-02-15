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
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity GOLOMB_CODING is
	Generic (
		DATA_WIDTH: integer := 19;
		MAX_PARAM_VALUE: integer := 19;
		MAX_PARAM_VALUE_LOG: integer := 5;
		OUTPUT_WIDTH: integer := 39;
		--these two are just for performance reasons to operate over powers of two
		SLACK_LOG: integer := 4;
		MAX_1_OUT_LOG: integer := 5
	);
	Port (
		clk, rst			: in	std_logic;
		input_param_data	: in	std_logic_vector(MAX_PARAM_VALUE_LOG - 1 downto 0);
		input_param_valid	: in	std_logic;
		input_param_ready	: out 	std_logic;
		input_value_data	: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_value_valid	: in	std_logic;
		input_value_ready	: out 	std_logic;
		output_code			: out	std_logic_vector(OUTPUT_WIDTH - 1 downto 0);
		output_length		: out	natural range 0 to OUTPUT_WIDTH;
		output_valid		: out	std_logic;
		output_ready		: in 	std_logic
	);
end GOLOMB_CODING;

architecture Behavioral of GOLOMB_CODING is
	--join signals first
	signal joint_valid, joint_ready: std_logic;
	signal joint_param_data_raw: std_logic_vector(MAX_PARAM_VALUE_LOG - 1 downto 0);
	signal joint_param_data: natural range 0 to MAX_PARAM_VALUE;
	signal joint_value_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--calculate quotient and remainder
	signal quotient: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal remainder_base_mask, remainder_mask, remainder: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--fsm for control
	type golomb_coding_state_t is (IDLE, QUOTREM_READ);
	signal state_curr, state_next: golomb_coding_state_t;
	
	--buffers
	signal quotient_buff, quotient_buff_next, remainder_buff, remainder_buff_next: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal quotient_buff_extended: std_logic_vector(DATA_WIDTH downto 0);
	signal param_buff, param_buff_next: natural range 0 to MAX_PARAM_VALUE;
	
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
	data_joiner: entity work.JOINER_AXI_2
		generic map (
			DATA_WIDTH_0 => MAX_PARAM_VALUE_LOG,
			DATA_WIDTH_1 => DATA_WIDTH
		)
		port map (
			clk => clk, rst => rst,
			input_valid_0 => input_param_valid,
			input_ready_0 => input_param_ready,
			input_data_0  => input_param_data,
			input_valid_1 => input_value_valid,
			input_ready_1 => input_value_ready,
			input_data_1  => input_value_data,
			output_valid  => joint_valid,
			output_ready  => joint_ready,
			output_data_0 => joint_param_data_raw,
			output_data_1 => joint_value_data
		);
	
	joint_param_data <= to_integer(unsigned(joint_param_data_raw));

	remainder_base_mask <= (others => '1');
	remainder_mask <= std_logic_vector(shift_right(unsigned(remainder_base_mask), MAX_PARAM_VALUE - joint_param_data));
	remainder <= remainder_mask and joint_value_data;
	
	quotient <= std_logic_vector(shift_right(unsigned(joint_value_data), joint_param_data));
	
	--insert minififo here if clk period goes out of the window
	
	
	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= IDLE;
				quotient_buff  <= (others => '0');
				remainder_buff <= (others => '0');
			else
				state_curr <= state_next;
				quotient_buff  <= quotient_buff_next;
				remainder_buff <= remainder_buff;
				param_buff <= param_buff_next;
			end if;
		end if;
	end process;
	
	comb: process(
		state_curr, 
		joint_valid, 
		quotient, remainder, joint_param_data, 
		need_more_cycles,
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
		--outputs
		output_code <= (others => '0');
		output_length <= 0;
		
		if state_curr = IDLE then
			joint_ready <= '1';
			if joint_valid = '1' then
				quotient_buff_next <= quotient;
				remainder_buff_next <= remainder;
				param_buff_next <= joint_param_data;
				state_next <= QUOTREM_READ;
			end if;
		elsif state_curr = QUOTREM_READ then
			output_valid <= '1';
			if not need_more_cycles then
				output_code <= output_code_last;
				output_length <= output_length_last;
				
				joint_ready <= output_ready;
				if joint_valid = '1' then
					--read next already
					quotient_buff_next <= quotient;
					remainder_buff_next <= remainder;
					param_buff_next <= joint_param_data;
				elsif output_ready = '1' then
					--go back to IDLE cause our value was read and we have no more values
					state_next <= IDLE;
				end if;	
			else
				output_code <= output_code_temp;
				output_length <= output_length_temp;
				if output_ready = '1' then
					--only update quotient if we send data ofc
					quotient_buff_next <= quotient_temp;
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
	
	output_code_last	<= std_logic_vector(shift_left(unsigned(base_out_one), param_buff + 1)) or ((OUTPUT_WIDTH - 1 downto DATA_WIDTH => '0') & quotient_buff);
	output_length_last	<= param_buff + 1 + to_integer(unsigned(quotient_buff)); 	


end Behavioral;
