----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.02.2019 12:20:04
-- Design Name: 
-- Module Name: two_d_predictor - Behavioral
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
use work.functions.all;
use work.data_types.all;
use IEEE.NUMERIC_STD.ALL;

entity TWO_D_PREDICTOR is
	generic (
		DATA_WIDTH: integer := 16;
		MAX_SLICE_SIZE_LOG: positive := 8
	);
	port (
		clk, rst		: in std_logic;
		xhat_data 		: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		xhat_ready 		: out std_logic;
		xhat_valid 		: in std_logic;
		xhat_last_r 	: in std_logic;
		xhat_last_s 	: in std_logic;
		xtilde_data 	: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		xtilde_ready 	: in std_logic;
		xtilde_valid 	: out std_logic;
		xtilde_last_s 	: out std_logic
	);

end TWO_D_PREDICTOR;

architecture Behavioral of TWO_D_PREDICTOR is
	type two_d_predictor_state_t is (RESET, FIRST_SAMPLE, FIRST_ROW, REST_OF_SLICE);
	signal state_curr, state_next: two_d_predictor_state_t;

	--fifo
	signal fifo_rst_force, fifo_rst: std_logic;
	signal fifo_in_valid, fifo_out_ready: std_logic;
	signal fifo_in_data, fifo_out_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--others
	signal upleft_addition: std_logic_vector(DATA_WIDTH downto 0);
	
	--output latch
	signal olatch_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal olatch_ready, olatch_valid: std_logic;
	signal olatch_last: std_logic;

begin

	seq: process(clk) 
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= RESET;
			else
				state_curr <= state_next;
			end if;
		end if;
	end process;

	upleft_addition <= std_logic_vector(unsigned('0' & fifo_out_data) + unsigned('0' & xhat_data));

	comb: process(state_curr, xhat_valid, olatch_ready, xhat_last_s, xhat_last_r, xhat_data, fifo_out_data, upleft_addition)
	begin
		state_next <= state_curr;

		fifo_rst_force	<= '0';
		fifo_in_valid 	<= '0';
		fifo_out_ready	<= '0';

		xhat_ready		<= '0';
		olatch_valid	<= '0';
		olatch_last 	<= '0';
		olatch_data 	<= (others => '0');

		if state_curr = RESET then
			state_next <= FIRST_SAMPLE;
		elsif state_curr = FIRST_SAMPLE then
			if xhat_valid = '1' and olatch_ready = '1' then
				xhat_ready		<= '1';
				fifo_in_valid 	<= '1';

				olatch_last <= xhat_last_s;
				olatch_valid<= '1';
				--slice is 1x1, have to send something to burn @ the filter
				if xhat_last_r = '1' and xhat_last_s = '1' then 
					fifo_rst_force <= '1';
					state_next <= FIRST_SAMPLE;
				--slice is a column
				elsif xhat_last_r = '1' then
					olatch_data <= xhat_data;
					state_next  <= REST_OF_SLICE;	
				--normal block, output this as prediction for the next
				else
					olatch_data <= xhat_data;
					state_next 	<= FIRST_ROW;
				end if;
			end if;
		elsif state_curr = FIRST_ROW then
			if xhat_valid = '1' and olatch_ready = '1' then
				xhat_ready		<= '1';
				fifo_in_valid 	<= '1';

				olatch_last <= xhat_last_s;
				olatch_valid<= '1';
				--slice is a row, end here with a burn
				if xhat_last_r = '1' and xhat_last_s = '1' then 
					fifo_rst_force <= '1';
					state_next <= FIRST_SAMPLE;
				--row ends here, send data out as usual and go to next
				elsif xhat_last_r = '1' then
					fifo_out_ready <= '1';
					olatch_data <= fifo_out_data;
					state_next  <= REST_OF_SLICE;	
				--normal block, output this as prediction for the next
				else
					olatch_data <= xhat_data;
				end if;
			end if;
		elsif state_curr = REST_OF_SLICE then
			if xhat_valid = '1' and olatch_ready = '1' then
				xhat_ready <= '1';
				fifo_in_valid <= '1';
				fifo_out_ready <= '1';
				--output the upper sample
				olatch_valid <= '1';
				olatch_last	 <= xhat_last_s;
				--slice was a column, end it
				if xhat_last_r = '1' and xhat_last_s = '1' then
					fifo_rst_force <= '1';
					state_next <= FIRST_SAMPLE;
				--unended column
				elsif xhat_last_r = '1' then
					olatch_data <= fifo_out_data;
				--otherwise this is just a normal (square) slice, go on
				else
					olatch_data <= upleft_addition(DATA_WIDTH downto 1);
				end if;
			end if;
		end if;
	end process;



	fifo_in_data <= xhat_data;
	fifo_rst <= fifo_rst_force or rst;
	shift_reg_prev_line: entity work.AXIS_FIFO
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			FIFO_DEPTH => 2**MAX_SLICE_SIZE_LOG + 2 --leave 2 extra to avoid jamming the queue up
		)
		Port map (
			clk => clk, rst => fifo_rst,
			input_valid => fifo_in_valid,
			input_ready => open, --assume always ready
			input_data  => fifo_in_data,
			output_ready=> fifo_out_ready,
			output_valid=> open, --assume always valid
			output_data => fifo_out_data
		);


	--output
	output_latch: entity work.AXIS_LATCHED_CONNECTION 
		Generic map (
			DATA_WIDTH => DATA_WIDTH
		)
		Port map ( 
			clk => clk, rst => rst,
			input_data	=> olatch_data,
			input_ready => olatch_ready,
			input_valid => olatch_valid,
			input_last  => olatch_last,
			output_data	=> xtilde_data,
			output_ready=> xtilde_ready,
			output_valid=> xtilde_valid,
			output_last => xtilde_last_s
		);


end Behavioral;
