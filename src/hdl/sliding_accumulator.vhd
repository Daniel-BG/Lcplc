----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12.02.2019 15:39:07
-- Design Name: 
-- Module Name: sliding_accumulator - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Create an accumulator that registers the last 2**ACC_LOG window
--		of input samples. 
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
use work.functions.all;

entity SLIDING_ACCUMULATOR is
	Generic (
		DATA_WIDTH: integer := 16;
		ACCUMULATOR_WINDOW: integer := 32
	);
	Port (
		clk, rst 	: in  std_logic;
		input_data	: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_valid	: in  std_logic;
		input_ready	: out std_logic;
		input_last	: in  std_logic;
		output_cnt	: out std_logic_vector(bits(ACCUMULATOR_WINDOW) - 1 downto 0);
		output_data	: out std_logic_vector(DATA_WIDTH + bits(ACCUMULATOR_WINDOW-1) - 1 downto 0);
		output_valid: out std_logic;
		output_ready: in  std_logic
	);
end SLIDING_ACCUMULATOR;

architecture Behavioral of SLIDING_ACCUMULATOR  is
	constant ACC_WINDOW_BITS: integer := bits(ACCUMULATOR_WINDOW);
	constant ACC_WINDOW_M1_BITS: integer := bits(ACCUMULATOR_WINDOW-1);

	type sliding_acc_state_t is (IDLE, PRIMED, EMPTYING);
	signal state_curr, state_next: sliding_acc_state_t;

	signal accumulator, accumulator_next: std_logic_vector(DATA_WIDTH + ACC_WINDOW_M1_BITS - 1 downto 0);
	signal accumulator_next_substract, accumulator_next_pass: std_logic_vector(DATA_WIDTH + ACC_WINDOW_M1_BITS - 1 downto 0);

	signal counter, counter_next: natural range 0 to ACCUMULATOR_WINDOW;

	--input queue signals
	signal write_en, read_en: std_logic;
	signal input_queued: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	signal rst_sample_queue, force_rst_sample_queue: std_logic;

	--memory latch
	signal interconn_data: std_logic_vector(DATA_WIDTH-1 downto 0);
	signal interconn_ready, interconn_valid: std_logic;

begin

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= EMPTYING;
				counter <= 0;
				accumulator <= (others => '0');
			else
				state_curr <= state_next;
				counter <= counter_next;
				accumulator <= accumulator_next;
			end if;
		end if;
	end process;
	
	accumulator_next_substract <= std_logic_vector(unsigned(accumulator) + unsigned((ACC_WINDOW_M1_BITS - 1 downto 0 => '0') & input_data) - unsigned((ACC_WINDOW_M1_BITS - 1 downto 0 => '0') & input_queued));
	accumulator_next_pass      <= std_logic_vector(unsigned(accumulator) + unsigned((ACC_WINDOW_M1_BITS - 1 downto 0 => '0') & input_data));

	comb: process(state_curr, counter, input_valid, accumulator, input_data, input_queued, output_ready, input_last, accumulator_next_substract, accumulator_next_pass)
	begin
		force_rst_sample_queue <= '0';
		state_next <= state_curr;
		input_ready <= '0';
		output_valid <= '0';
		read_en <= '0';
		write_en <= '0';
		counter_next <= counter;
		accumulator_next <= accumulator;

		if state_curr = IDLE then
			input_ready <= '1';
			if input_valid = '1' then
				if input_last = '1' then
					state_next <= EMPTYING;
				else
					write_en <= '1';
					state_next <= PRIMED;
				end if;
				if counter = ACCUMULATOR_WINDOW then
					read_en <= '1';
					accumulator_next <= accumulator_next_substract;
				else
					counter_next <= counter + 1;
					accumulator_next <= accumulator_next_pass;
				end if;
			end if;
		elsif state_curr = PRIMED then
			output_valid <= '1';
			if output_ready = '1' then
				input_ready <= '1';
				if input_valid = '1' then
					if input_last = '1' then
						state_next <= EMPTYING;
					end if;
					write_en <= '1';
					if counter = ACCUMULATOR_WINDOW then
						read_en <= '1';
						accumulator_next <= accumulator_next_substract;
					else
						counter_next <= counter + 1;
						accumulator_next <= accumulator_next_pass;
					end if;
				else
					state_next <= IDLE;
				end if;
			end if;
		elsif state_curr = EMPTYING then
			force_rst_sample_queue <= '1';
			accumulator_next <= (others => '0');
			counter_next <= 0;
			state_next <= IDLE;
		end if;
	end process;

	rst_sample_queue <= rst or force_rst_sample_queue;
	sample_queue: entity work.AXIS_FIFO
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			FIFO_DEPTH => ACCUMULATOR_WINDOW 
		)
		Port map (
			clk => clk, rst => rst_sample_queue,
			input_valid => write_en,
			input_ready => open, --assume always 1 by construction
			input_data  => input_data,
			output_ready => interconn_ready,
			output_data  => interconn_data,
			output_valid => interconn_valid --assume always valid by construction
		);

	fifo_out_latch: entity work.AXIS_LATCHED_CONNECTION
		Generic map (
			DATA_WIDTH => DATA_WIDTH
		)
		Port map ( 
			clk => clk, rst => rst_sample_queue,
			input_data  => interconn_data,
			input_ready => interconn_ready,
			input_valid => interconn_valid,
			output_data	=> input_queued,
			output_ready=> read_en,
			output_valid=> open
		);
	
	output_cnt	<= std_logic_vector(to_unsigned(counter, ACC_WINDOW_BITS));
	output_data	<= accumulator;
	
	
end Behavioral;
