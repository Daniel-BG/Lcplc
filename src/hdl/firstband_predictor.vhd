----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 21.02.2019 09:22:48
-- Design Name: 
-- Module Name: FIRSTBAND_PREDICTOR - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Module that makes the prediction for the first band in a given 
--			image block. Takes raw values and outputs prediction data
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

entity FIRSTBAND_PREDICTOR is
	Generic (
		DATA_WIDTH: positive := 16;
		MAX_SLICE_SIZE_LOG: positive := 8
	);
	Port (
		clk, rst		: in  std_logic;
		--input values
		x_valid			: in  std_logic;
		x_ready			: out std_logic;
		x_data			: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		x_last_row		: in  std_logic;	--1 if the current sample is the last of its row
		x_last_slice	: in  std_logic;	--1 if the current sample is the last of its block
		--output prediction
		xtilde_ready: in std_logic;
		xtilde_valid: out std_logic;
		xtilde_data : out std_logic_vector(DATA_WIDTH - 1 downto 0);
		xtilde_last : out std_logic --last slice
	);
end FIRSTBAND_PREDICTOR;

architecture Behavioral of FIRSTBAND_PREDICTOR is
	type firstband_state_t is (IDLE, PREDICTING);
	signal state_curr, state_next: firstband_state_t;
	signal first_row, first_row_next: boolean;
	signal first_col, first_col_next: boolean;

	--queue system for previous samples
	signal current_sample, current_sample_next, left_sample, left_sample_next, upper_sample: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal shift_enable: std_logic;
	signal fifo_rst, fifo_rst_force: std_logic;
	signal fifo_output_ready: std_logic;

	--prediction
	signal upleft_addition: std_logic_vector(DATA_WIDTH downto 0);

	--last buffer
	signal x_last_row_buf, x_last_row_buf_next: std_logic;
	signal x_last_slice_buf, x_last_slice_buf_next: std_logic;
begin

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= IDLE;
				first_row  <= true;
				first_col  <= true;
				x_last_row_buf <= '0';
				x_last_slice_buf <= '0';
				current_sample <= (others => '0');
				left_sample <= (others => '0');
			else				
				state_curr <= state_next;
				x_last_row_buf <= x_last_row_buf_next;
				x_last_slice_buf <= x_last_slice_buf_next;
				current_sample <= current_sample_next;
				left_sample <= left_sample_next;
				first_row <= first_row_next;
				first_col <= first_col_next;
			end if;
		end if;
	end process;
	
	comb: process(state_curr, xtilde_ready, x_valid, x_last_row_buf, x_last_slice_buf, x_last_slice, x_last_row,
		x_data, left_sample, current_sample, first_row, first_col)
	begin
		x_ready <= '0';
		shift_enable <= '0';
		xtilde_valid <= '0';
		state_next <= state_curr;
		x_last_row_buf_next <= x_last_row_buf;
		x_last_slice_buf_next <= x_last_slice_buf;
		fifo_rst_force <= '0';
		current_sample_next <= current_sample;
		left_sample_next <= left_sample;
		
		first_row_next <= first_row;
		first_col_next <= first_col;
		
		if state_curr = IDLE then
			x_ready <= '1';
			if x_valid = '1' then
				current_sample_next <= x_data;
				left_sample_next <= current_sample;
				x_last_row_buf_next <= x_last_row;
				x_last_slice_buf_next <= x_last_slice;
				shift_enable <= '1';
				state_next <= PREDICTING;
			end if;
		elsif state_curr = PREDICTING then
			xtilde_valid <= '1';
			if xtilde_ready = '1' then
				if x_last_row_buf = '1' and x_last_slice_buf = '1' then
					first_row_next <= true;
					first_col_next <= true;
					fifo_rst_force <= '1';
					state_next <= IDLE;
				else
					x_ready <= '1';
					if x_valid = '1' then
						current_sample_next <= x_data;
						left_sample_next <= current_sample;
						x_last_row_buf_next <= x_last_row;
						x_last_slice_buf_next <= x_last_slice;
						shift_enable <= '1';
						state_next <= PREDICTING;
						if x_last_row_buf = '1' then
							first_row_next <= false;
							first_col_next <= true;
						else
							first_col_next <= false;
						end if;
					else
						state_next <= IDLE;
					end if;
				end if;
			end if;
		end if;
	end process;	

					
	fifo_rst <= rst or fifo_rst_force;
	fifo_output_ready <= '1' when shift_enable = '1' and not first_row else '0';
	shift_reg_prev_line: entity work.AXIS_FIFO
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			FIFO_DEPTH => 2**MAX_SLICE_SIZE_LOG + 2 --leave 2 extra to avoid jamming the queue up
		)
		Port map (
			clk => clk, rst => fifo_rst,
			input_valid => shift_enable,
			input_ready => open, --assume always ready
			input_data  => x_data,
			output_ready=> fifo_output_ready,
			output_valid=> open, --assume always valid
			output_data => upper_sample
		);
		
	upleft_addition <= std_logic_vector(unsigned("0" & upper_sample) + unsigned("0" & left_sample));
	prediction_gen: process(first_col, first_row, upper_Sample, left_sample, upleft_addition)
	begin
		if first_col and first_row then
			xtilde_data <= (others => '0');
			--prediction <= (prediction'high downto current_sample'high+1 => '0') & current_sample;
		elsif first_col then
			xtilde_data <= std_logic_vector(resize(unsigned(upper_sample), xtilde_data'length));
		elsif first_row then
			xtilde_data <= std_logic_vector(resize(unsigned(left_sample), xtilde_data'length));
		else
			xtilde_data <= std_logic_vector(resize(unsigned(upleft_addition(upleft_addition'high downto 1)), xtilde_data'length));
		end if;
	end process;

	xtilde_last <= x_last_slice_buf;

	

end Behavioral;
