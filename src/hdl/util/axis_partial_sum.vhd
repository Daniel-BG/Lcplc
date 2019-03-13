----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.02.2019 10:30:57
-- Design Name: 
-- Module Name: ACCUMULATED_SHIFTAMT_CALC - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

entity AXIS_PARTIAL_SUM is
	Generic (
		INPUT_WIDTH_LOG		: integer := 6;		    --max accepted input value
		COUNTER_WIDTH_LOG	: integer := 7;			--counter width
		RESET_VALUE			: integer := 2**7-1;	--reset value
		START_ON_RESET		: boolean := true;		--first value is reset or is already reset + first input
		IS_ADD				: boolean := false		--true if the counter adds the input_shift, false if it substracts it
	);
	Port (
		clk, rst		: in  std_logic;
		input_data		: in  std_logic_vector(INPUT_WIDTH_LOG - 1 downto 0);
		input_valid		: in  std_logic;
		input_ready		: out std_logic;
		input_last		: in  std_logic;
		output_data 	: out std_logic_vector(COUNTER_WIDTH_LOG - 1 downto 0);
		output_valid	: out std_logic;
		output_ready	: in  std_logic;
		output_last 	: out std_logic
	);
end AXIS_PARTIAL_SUM;

architecture Behavioral of AXIS_PARTIAL_SUM is
	signal inner_accumulator, inner_accumulator_next: std_logic_vector(COUNTER_WIDTH_LOG - 1 downto 0); 
	signal inner_accumulator_enable: std_logic;
	signal inner_accumulator_rst: std_logic;

	--start on first signals
	type state_part_sum_t is (AWAIT, READY);
	signal state_curr, state_next: state_part_sum_t;

	--buffered signals
	signal acc_last_buf, acc_last_buf_next: std_logic;
begin
	--SHARED STUFF--
	----------------
	gen_sub: if not IS_ADD generate
		inner_accumulator_next <= std_logic_vector(unsigned(inner_accumulator) - resize(unsigned(input_data), COUNTER_WIDTH_LOG));	
	end generate;

	gen_add: if IS_ADD generate
		inner_accumulator_next <= std_logic_vector(unsigned(inner_accumulator) + resize(unsigned(input_data), COUNTER_WIDTH_LOG));	
	end generate;

	output_data  <= inner_accumulator;

	acc_update: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' or inner_accumulator_rst = '1' then
				inner_accumulator <= std_logic_vector(to_unsigned(RESET_VALUE, COUNTER_WIDTH_LOG));
			elsif inner_accumulator_enable = '1' then
				inner_accumulator <= inner_accumulator_next;
			end if;	
		end if;
	end process;


	--START ON RESET--
	------------------
	gen_start_on_reset: if START_ON_RESET generate
		inner_accumulator_enable <= '1' when input_valid = '1' and output_ready = '1' else '0';
		inner_accumulator_rst <= '1' when input_last = '1' and output_ready = '1' and input_valid = '1' else '0';
		output_valid <= input_valid;
		output_last  <= input_last;
		input_ready  <= output_ready;
	end generate;


	--DON'T START ON RESET--
	------------------------
	gen_start_on_first: if not START_ON_RESET generate
		state_update: process(clk)
		begin
			if rising_edge(clk) then
				if rst = '1' then
					state_curr <= AWAIT;
					acc_last_buf <= '0';
				else
					state_curr <= state_next;
					acc_last_buf <= acc_last_buf_next;
				end if;
			end if;
		end process;

		comb: process(state_curr, input_valid, output_ready, acc_last_buf, input_last)
		begin
			input_ready <= '0';
			output_valid <= '0';
			inner_accumulator_enable <= '0';
			state_next <= state_curr;
			inner_accumulator_rst <= '0';
			acc_last_buf_next <= acc_last_buf;
			output_last <= '0';

			if state_curr = AWAIT then
				input_ready <= '1';
				if input_valid = '1' then
					inner_accumulator_enable <= '1';
					acc_last_buf_next <= input_last;
					state_next <= READY;
				end if;
			elsif state_curr = READY then
				output_valid <= '1';
				output_last  <= acc_last_buf;
				if output_ready = '1' then
					if acc_last_buf = '1' then
						inner_accumulator_rst <= '1';
						state_next <= AWAIT;
						acc_last_buf_next <= '0';
					else
						input_ready <= '1';
						if input_valid = '1' then
							acc_last_buf_next <= input_last;
							inner_accumulator_enable <= '1';
						else
							state_next <= AWAIT;
						end if;
					end if;
				end if;
			end if;
		end process;
	end generate;


end Behavioral;
