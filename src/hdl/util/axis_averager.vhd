----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.02.2019 16:45:31
-- Design Name: 
-- Module Name: AXIS_AVERAGER - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Calculate the mean of a bunch of numbers (only need to specify the
--		max count log). If the count equals the max count log, output will be
--		instant. Otherwise, division is performed to get the desired result.
-- 
-- Dependencies: AXIS_ACCUMULATOR to calculate the addition of all elements
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments: 
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.NUMERIC_STD.all;
use work.data_types.all;

entity AXIS_AVERAGER is
	Generic (
		DATA_WIDTH: integer := 36;
		MAX_COUNT_LOG: integer := 8;
		IS_SIGNED: boolean := true
	);
	Port (
		clk, rst 		: in  std_logic;
		input_data		: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_valid		: in  std_logic;
		input_ready		: out std_logic;
		input_last		: in  std_logic;
		input_last_pt 	: in  std_logic;
		output_data		: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_valid 	: out std_logic;
		output_ready 	: in  std_logic;
		output_last_pt	: out std_logic
	);
end AXIS_AVERAGER;

architecture Behavioral of AXIS_AVERAGER is
	--splitter
	signal input_last_pt_stdlv, input_0_last_pt_stdlv, input_1_last_pt_stdlv: std_logic_vector(0 downto 0);
	alias  input_0_last_pt: std_logic is input_0_last_pt_stdlv(0);
	signal input_0_valid, input_0_ready, input_0_last: std_logic;
	signal input_1_valid, input_1_ready, input_1_last: std_logic;
	signal input_0_data, input_1_data: std_logic_vector(DATA_WIDTH - 1 downto 0);

	--data acc
	signal acc_data: std_logic_vector(DATA_WIDTH + MAX_COUNT_LOG - 1 downto 0);
	signal acc_valid, acc_ready: std_logic;
	signal acc_last_pt: std_logic;

	--count acc
	signal count_valid, count_ready: std_logic;
	signal count_data: std_logic_vector(MAX_COUNT_LOG downto 0);

	--synced
	signal synced_valid, synced_ready: std_logic;
	signal synced_dividend: std_logic_vector(DATA_WIDTH + MAX_COUNT_LOG - 1 downto 0);
	signal synced_divisor: std_logic_vector(MAX_COUNT_LOG downto 0);
	signal synced_last: std_logic;
	
	--synced buffers
	signal synced_divisor_buf, synced_divisor_buf_next: std_logic_vector(MAX_COUNT_LOG downto 0);
	signal synced_dividend_buf, synced_dividend_buf_next: std_logic_vector(DATA_WIDTH + MAX_COUNT_LOG - 1 downto 0);
	signal synced_last_buf, synced_last_buf_next: std_logic;
	
	--control
	type averager_state_t is (IDLE, OUTPUT_SHIFT, FEED_DIVIDER, AWAIT_DIVIDER);
	signal state_curr, state_next: averager_state_t;
	
	--divider
	signal divider_input_valid, divider_input_ready: std_logic;
	signal divider_output_ready, divider_output_valid: std_logic;
	signal divider_data: std_logic_vector(DATA_WIDTH + MAX_COUNT_LOG - 1 downto 0);
	signal divider_last: std_logic;
begin

	--need a splitter first
	input_last_pt_stdlv <= input_last_pt & "";
	split_input: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			USER_WIDTH => 1
		)
		Port map (
			clk => clk, rst => rst,
			input_valid		=> input_valid,
			input_data		=> input_data,
			input_ready		=> input_ready,
			input_last		=> input_last,
			input_user		=> input_last_pt_stdlv,
			--to output axi ports
			output_0_valid	=> input_0_valid,
			output_0_data	=> input_0_data,
			output_0_ready	=> input_0_ready,
			output_0_last 	=> input_0_last,
			output_0_user	=> input_0_last_pt_stdlv,
			output_1_valid	=> input_1_valid,
			output_1_data	=> input_1_data,
			output_1_ready	=> input_1_ready,
			output_1_last	=> input_1_last,
			output_1_user	=> input_1_last_pt_stdlv
		);

	accumulator_values: entity work.AXIS_ACCUMULATOR
		Generic map (
			DATA_WIDTH  => DATA_WIDTH,
			MAX_COUNT_LOG   => MAX_COUNT_LOG,
			IS_SIGNED	=> IS_SIGNED
		)
		Port map (
			clk => clk, rst => rst,
			input_data => input_0_data,
			input_valid => input_0_valid,
			input_ready	=> input_0_ready,
			input_last  => input_0_last,
			input_last_pt => input_0_last_pt,
			output_data => acc_data,
			output_valid => acc_valid,
			output_ready => acc_ready,
			output_last_pt => acc_last_pt
		);

	accumulator_quantity: entity work.AXIS_ACCUMULATOR
		Generic map (
			DATA_WIDTH => 1,
			MAX_COUNT_LOG  => MAX_COUNT_LOG,
			IS_SIGNED  => false
		)
		Port map (
			clk => clk, rst => rst,
			input_data  => "1",
			input_valid => input_1_valid,
			input_ready	=> input_1_ready,
			input_last  => input_1_last,
			output_data => count_data,
			output_valid => count_valid,
			output_ready => count_ready
		);

	accumulator_sync: entity work.AXIS_SYNCHRONIZER_2
		Generic map (
			DATA_WIDTH_0 => DATA_WIDTH + MAX_COUNT_LOG,
			DATA_WIDTH_1 => MAX_COUNT_LOG + 1,
			LATCH => false,
			LAST_POLICY => PASS_ZERO
		)
		Port map (
			clk => clk, rst => rst,
			--to input axi port
			input_0_valid => acc_valid,
			input_0_ready => acc_ready,
			input_0_data  => acc_data,
			input_0_last  => acc_last_pt,
			input_1_valid => count_valid,
			input_1_ready => count_ready, 
			input_1_data  => count_data,
			--to output axi ports
			output_valid	=> synced_valid,
			output_ready	=> synced_ready,
			output_data_0	=> synced_dividend,
			output_data_1	=> synced_divisor,
			output_last 	=> synced_last
		);

	seq : process (clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= IDLE;
				synced_divisor_buf <= (others => '0');
				synced_dividend_buf<= (others => '0');
				synced_last_buf <= '0';
			else
				state_curr <= state_next;
				synced_divisor_buf <= synced_divisor_buf_next;
				synced_dividend_buf<= synced_dividend_buf_next;
				synced_last_buf <= synced_last_buf_next;
			end if;
		end if;
	end process seq;

	comb: process(state_curr, output_ready, 
		synced_valid, synced_divisor, synced_dividend_buf, synced_divisor_buf, synced_dividend, synced_last_buf, synced_last,
		divider_input_ready, divider_output_valid, divider_data) 
	begin
		synced_ready <= '0';
		synced_dividend_buf_next <= synced_dividend_buf;
		synced_divisor_buf_next  <= synced_divisor_buf;
		synced_last_buf_next <= synced_last_buf;
		output_data <= (others => '0');
		output_valid <= '0';
		divider_input_valid <= '0';
		divider_output_ready <= '0';
		state_next <= state_curr;

		if state_curr = IDLE then
			synced_ready <= '1';
			if synced_valid = '1' then
				synced_last_buf_next <= synced_last;
				synced_dividend_buf_next <= synced_dividend;
				synced_divisor_buf_next <= synced_divisor;
				if synced_divisor = std_logic_vector(to_unsigned(2**MAX_COUNT_LOG, MAX_COUNT_LOG + 1)) then
					state_next <= OUTPUT_SHIFT;
				else
					state_next <= FEED_DIVIDER;
				end if;
			end if;
		elsif state_curr = OUTPUT_SHIFT then
			output_data <= synced_dividend_buf(DATA_WIDTH + MAX_COUNT_LOG - 1 downto MAX_COUNT_LOG);
			output_valid<= '1';
			if output_ready = '1' then
				state_next <= IDLE;
			end if;
		elsif state_curr = FEED_DIVIDER then
			divider_input_valid <= '1';
			if divider_input_ready = '1' then
				state_next <= AWAIT_DIVIDER;
			end if;
		elsif state_curr = AWAIT_DIVIDER then
			output_data <= divider_data(DATA_WIDTH + MAX_COUNT_LOG - 1 downto MAX_COUNT_LOG);
			output_valid<= divider_output_valid;
			divider_output_ready<= output_ready;
			if divider_output_valid = '1' and output_ready = '1' then
				state_next <= IDLE;
			end if;
		end if;
	end process;
	
	output_last_pt <= divider_last;

	divider: entity work.AXIS_DIVIDER
		Generic map (
			DIVIDEND_WIDTH => DATA_WIDTH + MAX_COUNT_LOG,
			DIVIDEND_SIGNED => IS_SIGNED,
			DIVISOR_WIDTH => MAX_COUNT_LOG + 1,
			DIVISOR_SIGNED => false,
			LAST_POLICY => PASS_ZERO
		)
		Port map (
			clk => clk, rst => rst,
			dividend_data	=> synced_dividend_buf,
			dividend_ready	=> divider_input_ready,
			dividend_valid	=> divider_input_valid,
			dividend_last	=> synced_last_buf,
			divisor_data	=> synced_divisor_buf,
			divisor_ready	=> open,
			divisor_valid	=> divider_input_valid,
			output_data		=> divider_data,
			output_err		=> open,
			output_valid	=> divider_output_valid,
			output_ready	=> divider_output_ready,
			output_last 	=> divider_last
		);

end Behavioral;





