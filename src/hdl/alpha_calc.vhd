----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.02.2019 16:19:13
-- Design Name: 
-- Module Name: alpha_calc - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Take the necessary values to calculate alpha and calculate it.
--		to control this unit, xhat comes accompanied with a 'last' flag, that 
--		indicates when to change xmean and xhatmean values
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
use work.data_types.all;

entity ALPHA_CALC is
	Generic (
		constant DATA_WIDTH: positive := 16;
		constant MAX_SLICE_SIZE_LOG : positive := 8;
		constant ALPHA_WIDTH: positive := 10
	);
	Port (
		clk, rst		: in  std_logic;
		x_valid			: in  std_logic;
		x_ready			: out std_logic;
		x_data			: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		xhat_valid		: in  std_logic;
		xhat_ready		: out std_logic;
		xhat_data		: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		xhat_last_s		: in  std_logic;
		xmean_valid		: in  std_logic;
		xmean_ready		: out std_logic;
		xmean_data		: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		xhatmean_valid	: in  std_logic;
		xhatmean_ready	: out std_logic;
		xhatmean_data	: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		alpha_ready     : in  std_logic;
		alpha_valid		: out std_logic;
		alpha_data		: out std_logic_vector(ALPHA_WIDTH - 1 downto 0)
	);
end ALPHA_CALC;

architecture Behavioral of ALPHA_CALC is
	--repeaters
	signal xhat_last_data, xhat_0_last_data, xhat_1_last_data, xhat_2_last_data: std_logic_vector(DATA_WIDTH downto 0);
	signal xhat_0_ready, xhat_0_valid, xhat_1_ready, xhat_1_valid, xhat_2_ready, xhat_2_valid: std_logic;
	signal xhat_0_last, xhat_1_last, xhat_2_last: std_logic;
	signal xhat_0_data, xhat_1_data, xhat_2_data: std_logic_vector(DATA_WIDTH-1 downto 0);
	
	--holders
	signal xmean_rep_ready, xmean_rep_valid: std_logic;
	signal xmean_rep_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xhatmean_rep_ready, xhatmean_rep_valid: std_logic;
	signal xhatmean_rep_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
			
	--previous substractor
	signal previous_sub_data: std_logic_vector(DATA_WIDTH downto 0);
	signal previous_sub_valid, previous_sub_ready, previous_sub_last: std_logic;
	
	--previous substraction splitter
	signal previous_sub_splitter_valid_0, previous_sub_splitter_ready_0, previous_sub_splitter_valid_1, previous_sub_splitter_ready_1: std_logic;
	signal previous_sub_last_data, previous_sub_splitter_last_data_0, previous_sub_splitter_last_data_1: std_logic_vector(DATA_WIDTH + 1 downto 0);
	signal previous_sub_splitter_data_0, previous_sub_splitter_data_1: std_logic_vector(DATA_WIDTH downto 0);
	signal previous_sub_splitter_last_0, previous_sub_splitter_last_1: std_logic;

	--current substractor
	signal current_sub_data: std_logic_vector(DATA_WIDTH downto 0);
	signal current_sub_valid, current_sub_ready: std_logic;
	
	--delay for current subs
	signal current_sub_data_buf: std_logic_vector(DATA_WIDTH downto 0);
	signal current_sub_valid_buf, current_sub_ready_buf: std_logic;
	
	--multiplication outputs
	signal alphad_mult_data, alphan_mult_data: std_logic_vector(DATA_WIDTH*2 + 1 downto 0);
	signal alphad_mult_valid, alphan_mult_valid, alphad_mult_ready, alphan_mult_ready, alphan_mult_last, alphad_mult_last: std_logic;
	
	--accumulator outputs 
	signal alphan_acc_data, alphad_acc_data: std_logic_vector(DATA_WIDTH*2 + 1 + MAX_SLICE_SIZE_LOG downto 0);
	signal alphan_acc_valid, alphan_acc_ready, alphad_acc_valid, alphad_acc_ready: std_logic;
	
begin

	--splitter for xhat control and such
	xhat_last_data <= xhat_last_s & xhat_data;
	xhat_splitter: entity work.AXIS_SPLITTER_3
		Generic map (
			DATA_WIDTH => DATA_WIDTH + 1
		)
		Port map (
			clk => clk, rst => rst,
			input_ready => xhat_ready,
			input_valid => xhat_valid,
			input_data  => xhat_last_data,
			output_0_data  => xhat_0_last_data,
			output_0_ready => xhat_0_ready,
			output_0_valid => xhat_0_valid,
			output_1_data  => xhat_1_last_data,
			output_1_ready => xhat_1_ready,
			output_1_valid => xhat_1_valid,
			output_2_data  => xhat_2_last_data,
			output_2_ready => xhat_2_ready,
			output_2_valid => xhat_2_valid
		);
	xhat_0_last <= xhat_0_last_data(DATA_WIDTH);
	xhat_0_data <= xhat_0_last_data(DATA_WIDTH - 1 downto 0);
	xhat_1_last <= xhat_1_last_data(DATA_WIDTH);
	xhat_1_data <= xhat_1_last_data(DATA_WIDTH - 1 downto 0);
	xhat_2_last <= xhat_2_last_data(DATA_WIDTH);
	xhat_2_data <= xhat_2_last_data(DATA_WIDTH - 1 downto 0);

	--need repeaters for xmean and xhatmean
	xmean_holder: entity work.AXIS_HOLDER
		Generic map (
			DATA_WIDTH => DATA_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			clear_ready		=> xhat_0_ready,
			clear_valid		=> xhat_0_valid,
			clear_data		=> xhat_0_last,
			input_ready		=> xmean_ready,
			input_valid		=> xmean_valid,
			input_data		=> xmean_data,
			output_ready	=> xmean_rep_ready,
			output_valid	=> xmean_rep_valid,
			output_data		=> xmean_rep_data
		);
		
	xhatmean_holder: entity work.AXIS_HOLDER 
		Generic map (
			DATA_WIDTH => DATA_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			clear_ready		=> xhat_1_ready,
			clear_valid		=> xhat_1_valid,
			clear_data		=> xhat_1_last,
			input_ready		=> xhatmean_ready,
			input_valid		=> xhatmean_valid,
			input_data		=> xhatmean_data,
			output_ready	=> xhatmean_rep_ready,
			output_valid	=> xhatmean_rep_valid,
			output_data		=> xhatmean_rep_data
		);
		
	--previous substraction
	previous_sub: entity work.AXIS_ARITHMETIC_OP 
		Generic map (
			DATA_WIDTH_0 => DATA_WIDTH,
			DATA_WIDTH_1 => DATA_WIDTH,
			OUTPUT_DATA_WIDTH => DATA_WIDTH + 1,
			IS_ADD => false,
			SIGN_EXTEND_0 => false,
			SIGN_EXTEND_1 => false,
			SIGNED_OP => true,
			LAST_POLICY	=> PASS_ZERO
		)
		Port map (
			clk => clk, rst => rst,
			input_0_data	=> xhat_2_data,
			input_0_valid	=> xhat_2_valid,
			input_0_ready	=> xhat_2_ready,
			input_0_last	=> xhat_2_last,
			input_1_data	=> xhatmean_rep_data,
			input_1_valid	=> xhatmean_rep_valid,
			input_1_ready	=> xhatmean_rep_ready,
			output_data		=> previous_sub_data,
			output_valid	=> previous_sub_valid,
			output_ready	=> previous_sub_ready,
			output_last     => previous_sub_last
		);
		
	--splitter to both multipliers
	previous_sub_last_data <= previous_sub_last & previous_sub_data;
	previous_sub_splitter: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH => DATA_WIDTH + 1 + 1
		)
		Port map (
			clk => clk, rst => rst,
			--to input axi port
			input_valid => previous_sub_valid,
			input_data  => previous_sub_last_data,
			input_ready => previous_sub_ready,
			--to output axi ports
			output_0_valid => previous_sub_splitter_valid_0,
			output_0_data  => previous_sub_splitter_last_data_0,
			output_0_ready => previous_sub_splitter_ready_0,
			output_1_valid => previous_sub_splitter_valid_1,
			output_1_data  => previous_sub_splitter_last_data_1,
			output_1_ready => previous_sub_splitter_ready_1
		);
	previous_sub_splitter_last_0 <= previous_sub_splitter_last_data_0(previous_sub_splitter_last_data_0'high);
	previous_sub_splitter_last_1 <= previous_sub_splitter_last_data_1(previous_sub_splitter_last_data_1'high);
	previous_sub_splitter_data_0 <= previous_sub_splitter_last_data_0(DATA_WIDTH downto 0);
	previous_sub_splitter_data_1 <= previous_sub_splitter_last_data_1(DATA_WIDTH downto 0);
		

	--currnet substraction
	current_sub: entity work.AXIS_ARITHMETIC_OP 
		Generic map (
			DATA_WIDTH_0 => DATA_WIDTH,
			DATA_WIDTH_1 => DATA_WIDTH,
			OUTPUT_DATA_WIDTH => DATA_WIDTH + 1,
			IS_ADD => false,
			SIGN_EXTEND_0 => false,
			SIGN_EXTEND_1 => false,
			SIGNED_OP => true
		)
		Port map (
			clk => clk, rst => rst,
			input_0_data	=> x_data,
			input_0_valid	=> x_valid,
			input_0_ready	=> x_ready,
			input_1_data	=> xmean_rep_data,
			input_1_valid	=> xmean_rep_valid,
			input_1_ready	=> xmean_rep_ready,
			output_data		=> current_sub_data,
			output_valid	=> current_sub_valid,
			output_ready	=> current_sub_ready
		);
		
	--current sub delay
	current_sub_delay: entity work.AXIS_DATA_LATCH
		Generic map (
			DATA_WIDTH => DATA_WIDTH + 1
		)
		Port map (
			clk => clk, rst => rst,
			input_ready => current_sub_ready,
			input_valid => current_sub_valid,
			input_data  => current_sub_data,
			output_ready=> current_sub_ready_buf,
			output_valid=> current_sub_valid_buf,
			output_data => current_sub_data_buf
		);
			
	--alphaN multiplier
	alphan_multiplier: entity work.AXIS_MULTIPLIER
		Generic map (
			DATA_WIDTH_0 => DATA_WIDTH + 1,
			DATA_WIDTH_1 => DATA_WIDTH + 1,
			OUTPUT_WIDTH => 2*DATA_WIDTH + 2,
			LAST_POLICY  => PASS_ZERO
		)
		Port map (
			clk => clk, rst => rst,
			input_0_data  => previous_sub_splitter_data_0,
			input_0_valid => previous_sub_splitter_valid_0,
			input_0_ready => previous_sub_splitter_ready_0,
			input_0_last  => previous_sub_splitter_last_0,
			input_1_data  => current_sub_data_buf,
			input_1_valid => current_sub_valid_buf,
			input_1_ready => current_sub_ready_buf,
			output_data   => alphan_mult_data,
			output_valid  => alphan_mult_valid,
			output_ready  => alphan_mult_ready,
			output_last   => alphan_mult_last
		);
		
	--alphaD multiplier
	alphad_multiplier: entity work.AXIS_MULTIPLIER
		Generic map (
			DATA_WIDTH_0 => DATA_WIDTH + 1,
			DATA_WIDTH_1 => DATA_WIDTH + 1,
			OUTPUT_WIDTH => 2*DATA_WIDTH + 2,
			LAST_POLICY  => PASS_ZERO
		)
		Port map (
			clk => clk, rst => rst,
			input_0_data  => previous_sub_splitter_data_1,
			input_0_valid => previous_sub_splitter_valid_1,
			input_0_ready => previous_sub_splitter_ready_1,
			input_0_last  => previous_sub_splitter_last_1,
			input_1_data  => previous_sub_splitter_data_1,
			input_1_valid => previous_sub_splitter_valid_1,
			output_data  => alphad_mult_data,
			output_valid => alphad_mult_valid,
			output_ready => alphad_mult_ready,
			output_last  => alphad_mult_last
		);

	--alphaN accumulator
	alphan_accumulator: entity work.AXIS_ACCUMULATOR
		Generic map (
			DATA_WIDTH => DATA_WIDTH*2 + 2,
			MAX_COUNT_LOG => MAX_SLICE_SIZE_LOG,
			IS_SIGNED => true
		)
		Port map (
			clk => clk, rst => rst,
			input_data   => alphan_mult_data,
			input_valid  => alphan_mult_valid,
			input_ready  => alphan_mult_ready,
			input_last   => alphan_mult_last,
			output_data  => alphan_acc_data,
			output_valid => alphan_acc_valid,
			output_ready => alphan_acc_ready
		);

	--alphaD accumulator
	alphad_accumulator: entity work.AXIS_ACCUMULATOR
		Generic map (
			DATA_WIDTH => DATA_WIDTH*2 + 2,
			MAX_COUNT_LOG => MAX_SLICE_SIZE_LOG,
			IS_SIGNED => true
		)
		Port map (
			clk => clk, rst => rst,
			input_data   => alphad_mult_data,
			input_valid  => alphad_mult_valid,
			input_ready  => alphad_mult_ready,
			input_last   => alphad_mult_last,
			output_data  => alphad_acc_data,
			output_valid => alphad_acc_valid,
			output_ready => alphad_acc_ready
		);
		
	--alpha calculator
	alpha_calculation: entity work.ALPHA_FINDER
		Generic map (
			INPUT_WIDTH => DATA_WIDTH*2 + 2 + MAX_SLICE_SIZE_LOG,
			ALPHA_WIDTH => ALPHA_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			alphan_data 	=> alphan_acc_data,
			alphan_ready 	=> alphan_acc_ready,
			alphan_valid 	=> alphan_acc_valid,
			alphad_data 	=> alphad_acc_data,
			alphad_ready 	=> alphad_acc_ready,
			alphad_valid 	=> alphad_acc_valid,
			output_data 	=> alpha_data,
			output_ready 	=> alpha_ready,
			output_valid 	=> alpha_valid
		);

end Behavioral;
