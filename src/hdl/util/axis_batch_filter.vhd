----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 20.02.2019 11:07:14
-- Design Name: 
-- Module Name: FILTER_AXI - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: AXIS batch filter that takes an input and a flag, and for each
--		flag either outputs or filters out the input until last is asserted
-- 
-- Dependencies: AXIS_SYNCHRONIZER_2 to sync the input data and flag
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity AXIS_BATCH_FILTER is
	Generic (
		DATA_WIDTH: integer := 16;
		ELIMINATE_ON_UP: boolean := true
	);
	Port (
		clk, rst		: in 	std_logic;
		input_valid		: in	std_logic;
		input_ready		: out	std_logic;
		input_data		: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_last		: in 	std_logic;
		flag_valid		: in	std_logic;
		flag_ready		: out	std_logic;
		flag_data		: in	std_logic_vector(0 downto 0);
		--to output axi ports
		output_valid	: out 	std_logic;
		output_ready	: in 	std_logic;
		output_data		: out	std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_last		: out 	std_logic
	);
end AXIS_BATCH_FILTER;


architecture Behavioral of AXIS_BATCH_FILTER is
	type batch_filter_state_t is (IDLE, FILTERING);
	signal state_curr, state_next: batch_filter_state_t;

	signal flag_buf, flag_buf_next: std_logic;
	signal filter: boolean;
begin

	gen_filter_on_up: if ELIMINATE_ON_UP generate
		filter <= flag_buf = '1';
	end generate;
	gen_filter_on_down: if not ELIMINATE_ON_UP generate
		filter <= flag_buf = '0';
	end generate;


	seq : process (rst, clk)
	begin
		if (rising_edge(clk)) then
			if rst = '1' then
				state_curr <= IDLE;
				flag_buf <= '0';
			else
				state_curr <= state_next;
				flag_buf <= flag_buf_next;
			end if;
		end if;
	end process seq;

	comb: process(state_curr, flag_valid, filter, input_valid, output_ready, input_last)
	begin
		flag_ready <= '0';
		input_ready <= '0';
		state_next <= state_curr;
		flag_buf_next <= flag_buf;
		output_valid <= '0';
		input_ready <= '0';
		output_last <= '0';

		if state_curr = IDLE then
			flag_ready <= '1';
			if flag_valid = '1' then
				flag_buf_next <= flag_data;
				state_next <= FILTERING;
			end if;
		elsif (state_curr = FILTERING) then
			if filter then
				input_ready <= '1';
				if input_valid = '1' then
					if input_last = '1' then
						state_next <= IDLE;
					end if;
				end if;
			else
				output_valid <= input_valid;
				input_ready <= output_ready;
				output_last <= input_last;
				if input_valid = '1' and output_ready = '1' then
					if input_last = '1' then
						state_next <= IDLE;
					end if;
				end if;
			end if;
		end if;
	end process;


end Behavioral;
