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

entity FIRSTBAND_PREDICTOR_NEW is
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
		x_last_r		: in  std_logic;	--1 if the current sample is the last of its row
		x_last_s		: in  std_logic;	--1 if the current sample is the last of its block
		--output prediction
		xtilde_ready: in  std_logic;
		xtilde_valid: out std_logic;
		xtilde_data : out std_logic_vector(DATA_WIDTH - 1 downto 0);
		xtilde_last : out std_logic --last slice
	);
end FIRSTBAND_PREDICTOR_NEW;

architecture Behavioral of FIRSTBAND_PREDICTOR_NEW is
	--first stage: control signals and pass x_data, x_data_prev, x_data_up, x_last_r, x_last_s to next stage
	type first_stage_state_t is (FIRST_ROW, OTHER_ROWS);
	signal first_stage_state_curr, first_stage_state_next: first_stage_state_t; 

	signal fifo_rst, fifo_rst_force: std_logic;
	signal fifo_in_valid, fifo_out_ready: std_logic;
	signal fifo_in_data, fifo_out_data: std_logic_vector(DATA_WIDTH - 1 downto 0);

	signal data_prev_latch: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal data_prev_latch_enable: std_logic;
	signal data_up_latch: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal data_up_latch_enable: std_logic;
	signal data_latch: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal data_latch_last_s, data_latch_last_r, data_latch_first_row, data_latch_first_col, data_latch_first_row_next: std_logic;
	signal data_latch_enable: std_logic;

	signal first_latch_in_ready, first_latch_in_valid: std_logic;
	signal first_latch_out_ready, first_latch_out_valid: std_logic;
	signal first_latch_occupied: std_logic;
	signal first_latch_last_r, first_latch_last_s: std_logic;
	signal first_latch_data_c, first_latch_data_l, first_latch_data_u: std_logic_vector(DATA_WIDTH - 1 downto 0);

	--second stage
	signal upleft_addition: std_logic_vector(DATA_WIDTH downto 0);
	
	signal olatch_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal olatch_ready, olatch_valid, olatch_last: std_logic;
begin

	---------------------------------------
	--FIRST STAGE-> GENERATE NEIGHBORHOOD--
	---------------------------------------
	input_seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				first_stage_state_curr <= FIRST_ROW;
				data_latch_last_r <= '1'; --important to go to first col!!
			else
				first_stage_state_curr <= first_stage_state_next;
				if data_prev_latch_enable = '1' then
					data_prev_latch <= data_latch;
				end if;
				if data_latch_enable = '1' then
					data_latch 				<= x_data;
					data_latch_last_s 		<= x_last_s;
					data_latch_last_r 		<= x_last_r;
					data_latch_first_row 	<= data_latch_first_row_next;
					data_latch_first_col    <= data_latch_last_r;
				end if;
				if data_up_latch_enable = '1' then
					data_up_latch <= fifo_out_data;
				end if;
			end if;
		end if;
	end process;

	input_comb: process(first_stage_state_curr, first_latch_in_ready, x_valid, x_last_s, x_last_r)
	begin
		fifo_in_valid				<= '0';
		fifo_out_ready 				<= '0';
		x_ready						<= '0';
		first_latch_in_valid		<= '0';

		data_prev_latch_enable 		<= '0';
		data_latch_enable 			<= '0';
		data_up_latch_enable   		<= '0';
		data_latch_first_row_next 	<= '0';

		fifo_rst_force 				<= '0';
		
		first_stage_state_next      <= first_stage_state_curr;

		if first_stage_state_curr = FIRST_ROW then
			x_ready <= first_latch_in_ready;
			first_latch_in_valid <= x_valid;
			if first_latch_in_ready = '1' and x_valid = '1' then
				fifo_in_valid <= '1';

				data_prev_latch_enable		<= '1';
				data_latch_enable 			<= '1';
				data_latch_first_row_next 	<= '1';

				if x_last_s = '1' then
					fifo_rst_force <= '1';
				elsif x_last_r = '1' then
					first_stage_state_next <= OTHER_ROWS;
				end if;
			end if;
		elsif first_stage_state_curr = OTHER_ROWS then
			x_ready <= first_latch_in_ready;
			first_latch_in_valid <= x_valid;
			if first_latch_in_ready = '1' and x_valid = '1' then
				fifo_in_valid	<= '1';
				fifo_out_ready	<= '1';

				data_prev_latch_enable		<= '1';
				data_latch_enable 			<= '1';
				data_up_latch_enable    	<= '1';
				data_latch_first_row_next 	<= '0';

				if x_last_s = '1' then
					fifo_rst_force <= '1';
					first_stage_state_next <= FIRST_ROW;
				end if;
			end if;
		end if;

	end process;

	fifo_rst <= rst or fifo_rst_force;
	fifo_in_data <= x_data;
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

	---------------------
	--FIRST LATCH LOGIC--
	---------------------
	first_latch_seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				first_latch_occupied <= '0';
			else
				if first_latch_in_ready = '1' and first_latch_in_valid = '1' then
					first_latch_occupied <= '1';
				elsif first_latch_out_valid = '1' and first_latch_out_ready = '1' then
					first_latch_occupied <= '0';
				end if;
			end if;
		end if;
	end process;
	first_latch_in_ready  <= first_latch_out_ready or not first_latch_occupied;
	first_latch_out_valid <= first_latch_occupied;

	---------------------------------------
	--SECOND STAGE-> CALCULATE PREDICTION--
	---------------------------------------
	first_latch_out_ready <= olatch_ready;
	olatch_valid <= first_latch_out_valid;

	upleft_addition <= std_logic_vector(unsigned("0" & data_up_latch) + unsigned("0" & data_prev_latch));
	prediction_gen: process(data_latch_first_col, data_latch_first_row, data_up_latch, data_prev_latch, upleft_addition)
	begin
		if data_latch_first_col = '1' and data_latch_first_row = '1' then
			olatch_data <= (others => '0');
			--prediction <= (prediction'high downto current_sample'high+1 => '0') & current_sample;
		elsif data_latch_first_col = '1' then
			olatch_data <= data_up_latch;
		elsif data_latch_first_row = '1' then
			olatch_data <= data_prev_latch;
		else
			olatch_data <= upleft_addition(upleft_addition'high downto 1);
		end if;
	end process;

	olatch_last <= data_latch_last_s;
	
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
			output_last => xtilde_last
		);


end Behavioral;