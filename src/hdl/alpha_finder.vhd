----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08.02.2019 15:17:28
-- Design Name: 
-- Module Name: alpha_finder - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Take the alpha N and D values and divide them outputting the alpha
--		value (clamped to the [0, 2) interval in ALPHA_WIDTH bits, all zeroes is 0,
--		while all 1s is almost 2)
--			ALPHA = clamp(ALPHAN / ALPHAD, low=0, high=2)
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
use work.am_data_types.all;

entity ALPHA_FINDER is
	generic (
		INPUT_WIDTH: integer := 16*2+2+8;
		ALPHA_WIDTH: integer := 10
	);
	port (
		clk, rst: in std_logic;
		alphan_data:	in 	std_logic_vector(INPUT_WIDTH - 1 downto 0);
		alphan_ready:	out	std_logic;
		alphan_valid:	in 	std_logic;
		alphad_data:	in 	std_logic_vector(INPUT_WIDTH - 1 downto 0);
		alphad_ready:	out	std_logic;
		alphad_valid:	in 	std_logic;
		output_data: 	out std_logic_vector(ALPHA_WIDTH - 1 downto 0);
		output_ready: 	in  std_logic;
		output_valid: 	out std_logic
	);
end ALPHA_FINDER;


architecture Behavioral of ALPHA_FINDER is
	--initial synchronizer
	signal input_data_alphan: std_logic_vector(INPUT_WIDTH - 1 downto 0);
	signal input_data_alphad: std_logic_vector(INPUT_WIDTH - 1 downto 0);
	signal input_ready: std_logic;
	signal input_valid: std_logic;

	--others
	type alpha_finder_state_t is (IDLE, DIVIDING, FINISHED);
	signal state_curr, state_next: alpha_finder_state_t;
	
	signal alphan_reg_curr, alphan_reg_next, alphad_reg_curr, alphad_reg_next: 
		std_logic_vector (INPUT_WIDTH - 1 + ALPHA_WIDTH downto 0);
		--give alpha_width slack for divisions
	
	signal alpha_reg_curr, alpha_reg_next: std_logic_vector(ALPHA_WIDTH - 1 downto 0);
	
	signal counter_curr, counter_next: natural range 0 to ALPHA_WIDTH;
begin

	input_sync: entity work.AXIS_SYNCHRONIZER_2 
		generic map (
			DATA_WIDTH_0 => INPUT_WIDTH,
			DATA_WIDTH_1 => INPUT_WIDTH,
			LATCH => true,
			LAST_POLICY => PASS_ZERO
		)
		port map (
			clk => clk, rst => rst,
			input_0_valid => alphan_valid,
			input_0_ready => alphan_ready,
			input_0_data  => alphan_data,
			input_0_last  => '0',
			input_1_valid => alphad_valid,
			input_1_ready => alphad_ready,
			input_1_data  => alphad_data,
			input_1_last  => '0',
			output_valid  => input_valid,
			output_ready  => input_ready,
			output_data_0 => input_data_alphan,
			output_data_1 => input_data_alphad,
			output_last   => open
		);

	seq: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= IDLE;
				alphan_reg_curr <= (others => '0');
				alphad_reg_curr <= (others => '0');
				alpha_reg_curr <= (others => '0');
				counter_curr <= 0;
			else
				state_curr <= state_next;
				alphan_reg_curr <= alphan_reg_next;
				alphad_reg_curr <= alphad_reg_next;
				alpha_reg_curr <= alpha_reg_next;
				counter_curr <= counter_next;
			end if;
		end if;
	end process;
	
	comb: process(state_curr, input_valid, output_ready, counter_curr, input_data_alphad, input_data_alphan, alphad_reg_curr, alphan_reg_curr, alpha_reg_curr)
	begin
		input_ready <= '0';
		output_valid <= '0';
	
		state_next <= state_curr;
		alphad_reg_next <= alphad_reg_curr;
		alphan_reg_next <= alphan_reg_curr;
		counter_next <= counter_curr;
		alpha_reg_next <= alpha_reg_curr;
	
		if state_curr = IDLE then
			input_ready <= '1';
			if input_valid = '1' then
				state_next <= DIVIDING;
				alphad_reg_next <= input_data_alphad & (ALPHA_WIDTH - 1 downto 0 => '0');
				alphan_reg_next <= input_data_alphan & (ALPHA_WIDTH - 1 downto 0 => '0');
				alpha_reg_next <= (others => '0');
				counter_next <= 1;
			end if;
		elsif state_curr = DIVIDING then
			if counter_curr = ALPHA_WIDTH then
				state_next <= FINISHED;
			else
				counter_next <= counter_curr + 1;
			end if;
			
			if signed(alphan_reg_curr) >= signed(alphad_reg_curr) then
				alphan_reg_next <= std_logic_vector(signed(alphan_reg_curr) - signed(alphad_reg_curr));
				alpha_reg_next  <= alpha_reg_curr(ALPHA_WIDTH - 2 downto 0) & '1';
			else
				alpha_reg_next  <= alpha_reg_curr(ALPHA_WIDTH - 2 downto 0) & '0';
			end if;
			--right logical shift (value is positive so we can shift zeroes in)
			alphad_reg_next <= '0' & alphad_reg_curr(alphad_reg_curr'length-1 downto 1);
		elsif state_curr = FINISHED then
			output_valid <= '1';
			if output_ready = '1' then
				state_next <= IDLE;
			end if;
		end if;
	end process;

	output_data <= alpha_reg_curr;
	
	
end Behavioral;
