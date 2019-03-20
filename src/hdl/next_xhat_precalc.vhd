----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.02.2019 14:50:01
-- Design Name: 
-- Module Name: NEXT_XHAT_PRECALC - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Precalculate xhat mean via xtilde and xhatraw so that it is already
--		calculated when the flag comes in
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

entity NEXT_XHAT_PRECALC is
	Generic (
		DATA_WIDTH: integer := 16;
		BLOCK_SIZE_LOG: integer := 8
	);
	Port (
		rst, clk		: in 	std_logic;
		--inputs
		xhat_data		: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		xhat_ready		: out	std_logic;
		xhat_valid		: in	std_logic;
		xhat_last_s		: in 	std_logic;
		xhat_last_b		: in 	std_logic;
		xtilde_data		: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		xtilde_ready	: out	std_logic;
		xtilde_valid	: in	std_logic;
		xtilde_last_s	: in 	std_logic;
		d_flag_data		: in	std_logic;
		d_flag_ready	: out	std_logic;
		d_flag_valid	: in 	std_logic;
		xhatout_data	: out	std_logic_vector(DATA_WIDTH - 1 downto 0);
		xhatout_ready	: in	std_logic;
		xhatout_valid	: out	std_logic;
		xhatout_last_s	: out 	std_logic;
		xhatoutmean_data: out   std_logic_vector(DATA_WIDTH - 1 downto 0);
		xhatoutmean_ready:in  	std_logic;
		xhatoutmean_valid:out   std_logic
	);
end NEXT_XHAT_PRECALC;

architecture Behavioral of NEXT_XHAT_PRECALC is

	--xhat splitter
	signal xhat_flags_data: std_logic_vector(DATA_WIDTH + 2 - 1 downto 0);
	signal xhat_split_0_valid, xhat_split_0_ready, xhat_split_1_valid, xhat_split_1_ready, xhat_split_2_valid, xhat_split_2_ready: std_logic;
	signal xhat_split_0_flags_data, xhat_split_1_flags_data, xhat_split_2_flags_data: std_logic_vector(DATA_WIDTH + 2 - 1 downto 0);
	alias  xhat_split_0_data: std_logic_vector(DATA_WIDTH - 1 downto 0) is xhat_split_0_flags_data(DATA_WIDTH - 1 downto 0);
	alias  xhat_split_0_last_data: std_logic_vector(DATA_WIDTH downto 0) is xhat_split_0_flags_data(DATA_WIDTH downto 0);
	alias  xhat_split_0_last_b: std_logic is xhat_split_0_flags_data(DATA_WIDTH + 1);
	alias  xhat_split_0_last_s: std_logic is xhat_split_0_flags_data(DATA_WIDTH);
	alias  xhat_split_1_data: std_logic_vector(DATA_WIDTH - 1 downto 0) is xhat_split_1_flags_data(DATA_WIDTH - 1 downto 0);
	alias  xhat_split_1_last_b: std_logic is xhat_split_1_flags_data(DATA_WIDTH + 1);
	alias  xhat_split_1_last_s: std_logic is xhat_split_1_flags_data(DATA_WIDTH);
	alias  xhat_split_2_data: std_logic_vector(DATA_WIDTH - 1 downto 0) is xhat_split_2_flags_data(DATA_WIDTH - 1 downto 0);
	alias  xhat_split_2_last_b: std_logic_vector is xhat_split_2_flags_data(DATA_WIDTH + 1 downto DATA_WIDTH + 1);
	alias  xhat_split_2_last_s: std_logic_vector is xhat_split_2_flags_data(DATA_WIDTH downto DATA_WIDTH);

	--xtilde splitter
	signal xtilde_split_0_valid, xtilde_split_0_ready, xtilde_split_1_valid, xtilde_split_1_ready, xtilde_split_0_last, xtilde_split_1_last: std_logic;
	signal xtilde_split_0_data, xtilde_split_1_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--xhat and xtilde fifos
	signal xhat_fifo_ready, xhat_fifo_valid: std_logic;
	signal xhat_fifo_last_data: std_logic_vector(DATA_WIDTH downto 0);
	alias  xhat_fifo_data: std_logic_vector(DATA_WIDTH - 1 downto 0) is xhat_fifo_last_data(DATA_WIDTH - 1 downto 0);
	alias  xhat_fifo_last: std_logic is xhat_fifo_last_data(DATA_WIDTH);
	
	signal xtilde_split_0_last_data: std_logic_vector(DATA_WIDTH downto 0);
	signal xtilde_fifo_ready, xtilde_fifo_valid: std_logic;
	signal xtilde_fifo_last_data: std_logic_vector(DATA_WIDTH downto 0);
	alias  xtilde_fifo_data: std_logic_vector(DATA_WIDTH - 1 downto 0) is xtilde_fifo_last_data(DATA_WIDTH - 1 downto 0);
	alias  xtilde_fifo_last: std_logic is xtilde_fifo_last_data(DATA_WIDTH);
	
	
	--accumulators
	signal xhatmean_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xhatmean_valid, xhatmean_ready: std_logic;

	signal xtildemean_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xtildemean_valid, xtildemean_ready: std_logic;

	--flag gen
	signal d_flag_data_stdlv: std_logic_vector(0 downto 0);
	
	--flag splitter
	signal d_flag_0_valid, d_flag_0_ready, d_flag_1_valid, d_flag_1_ready: std_logic;
	signal d_flag_0_data, d_flag_1_data: std_logic_vector(0 downto 0);
	
	--xhatout filter
	signal xhatoutmean_unfiltered_valid, xhatoutmean_unfiltered_ready: std_logic;
	signal xhatoutmean_unfiltered_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--xhat filter
	signal xhatout_unfiltered_valid, xhatout_unfiltered_ready, xhatout_unfiltered_last: std_logic;
	signal xhatout_unfiltered_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--last round flag
	signal last_round_valid, last_round_ready: std_logic;
	signal last_round_flag: std_logic_vector(0 downto 0);
	
	--last round flag splitter
	signal last_round_0_valid, last_round_0_ready, last_round_1_valid, last_round_1_ready: std_logic;
	signal last_round_0_flag, last_round_1_flag: std_logic_vector(0 downto 0);

begin

	--split xhat and xtilde data
	--one goes to mean calculation
	--the other goes to queue of block_size_log depth
	--whenever D is found check threshold
	--and enable whatever queue is ok

	--SPLITTERS
	xhat_flags_data <= xhat_last_b & xhat_last_s & xhat_data;
	xhat_splitter: entity work.AXIS_SPLITTER_3
		Generic map (
			DATA_WIDTH => DATA_WIDTH + 2
		)
		Port map (
			clk => clk, rst => rst, 
			--to input axi port
			input_valid => xhat_valid,
			input_data  => xhat_flags_data,
			input_ready => xhat_ready,
			--to output axi ports
			output_0_valid => xhat_split_0_valid,
			output_0_data  => xhat_split_0_flags_data,
			output_0_ready => xhat_split_0_ready,
			output_1_data  => xhat_split_1_flags_data,
			output_1_ready => xhat_split_1_ready,
			output_1_valid => xhat_split_1_valid,
			output_2_ready => xhat_split_2_ready,
			output_2_data  => xhat_split_2_flags_data,
			output_2_valid => xhat_split_2_valid
		);
		
	xtilde_splitter: entity work.AXIS_SPLITTER_2
			Generic map (
				DATA_WIDTH => DATA_WIDTH
			)
			Port map (
				clk => clk, rst => rst,
				--to input axi port
				input_valid => xtilde_valid,
				input_data  => xtilde_data,
				input_ready => xtilde_ready,
				input_last  => xtilde_last_s,
				--to output axi ports
				output_0_valid => xtilde_split_0_valid,
				output_0_data  => xtilde_split_0_data,
				output_0_ready => xtilde_split_0_ready,
				output_0_last  => xtilde_split_0_last,
				output_1_valid => xtilde_split_1_valid,
				output_1_data  => xtilde_split_1_data,
				output_1_ready => xtilde_split_1_ready,
				output_1_last  => xtilde_split_1_last
			);
			
	--FIFOS
	xhat_fifo: entity work.AXIS_FIFO
		Generic map (
			DATA_WIDTH => DATA_WIDTH + 1,
			FIFO_DEPTH => 2**BLOCK_SIZE_LOG
		)
		Port map ( 
			clk	=> clk, rst => rst,
			--input axi port
			input_valid => xhat_split_0_valid,
			input_ready => xhat_split_0_ready,
			input_data  => xhat_split_0_last_data,
			--out axi port
			output_ready => xhat_fifo_ready,
			output_data  => xhat_fifo_last_data,
			output_valid => xhat_fifo_valid
		);
	xtilde_split_0_last_data <= xtilde_split_0_last & xtilde_split_0_data;
	xtilde_fifo: entity work.AXIS_FIFO
		Generic map (
			DATA_WIDTH => xtilde_split_0_last_data'length,
			FIFO_DEPTH => 2**BLOCK_SIZE_LOG
		)
		Port map ( 
			clk	=> clk, rst => rst,
			--input axi port
			input_valid => xtilde_split_0_valid,
			input_ready => xtilde_split_0_ready,
			input_data  => xtilde_split_0_last_data,
			--out axi port
			output_ready => xtilde_fifo_ready,
			output_data  => xtilde_fifo_last_data,
			output_valid => xtilde_fifo_valid
		);
		
	--mean calcs
	xhat_acc: entity work.AXIS_AVERAGER
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			COUNT_LOG => BLOCK_SIZE_LOG,
			IS_SIGNED => false
		)
		Port map (
			clk => clk, rst => rst,
			input_data	=> xhat_split_1_data,
			input_valid => xhat_split_1_valid,
			input_ready => xhat_split_1_ready,
			input_last  => xhat_split_1_last_s,
			output_data => xhatmean_data,
			output_valid=> xhatmean_valid,
			output_ready=> xhatmean_ready
		);
		
	xtilde_acc: entity work.AXIS_AVERAGER
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			COUNT_LOG => BLOCK_SIZE_LOG,
			IS_SIGNED => false
		)
		Port map (
			clk => clk, rst => rst,
			input_data	=> xtilde_split_1_data,
			input_valid => xtilde_split_1_valid,
			input_ready => xtilde_split_1_ready,
			input_last  => xtilde_split_1_last,
			output_data => xtildemean_data,
			output_valid=> xtildemean_valid,
			output_ready=> xtildemean_ready
		);
		
	--threshold splitter
	d_flag_data_stdlv <= "0" when d_flag_data = '0' else "1";
	d_threshold_splitter: entity  work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH => 1
		)
		Port map (
			clk => clk, rst => rst,
			input_valid		=> d_flag_valid,
			input_data		=> d_flag_data_stdlv,
			input_ready		=> d_flag_ready,
			output_0_valid	=> d_flag_0_valid,
			output_0_data	=> d_flag_0_data,
			output_0_ready	=> d_flag_0_ready,
			output_1_valid	=> d_flag_1_valid,
			output_1_data	=> d_flag_1_data,
			output_1_ready	=> d_flag_1_ready
		);
		
	--select mean
	mean_selector: entity work.AXIS_SELECTOR 
		generic map (
			DATA_WIDTH => DATA_WIDTH
		)
		port map (
			clk => clk, rst => rst,
			input_0_data	=> xtildemean_data,
			input_0_ready	=> xtildemean_ready,
			input_0_valid	=> xtildemean_valid,
			input_1_data	=> xhatmean_data,
			input_1_ready	=> xhatmean_ready,
			input_1_valid	=> xhatmean_valid,
			flag_data		=> d_flag_1_data,
			flag_ready		=> d_flag_1_ready,
			flag_valid		=> d_flag_1_valid,
			output_data		=> xhatoutmean_unfiltered_data,
			output_valid	=> xhatoutmean_unfiltered_valid,
			output_ready	=> xhatoutmean_unfiltered_ready
		);
		
	--last round valid calculator
	last_round_flag_filter: entity work.AXIS_FILTER
		generic map (
			DATA_WIDTH => 1,
			ELIMINATE_ON_UP => false
		)
		port map (
			clk => clk, rst => rst,
			input_valid => xhat_split_2_valid,
			input_ready => xhat_split_2_ready,
			input_data  => xhat_split_2_last_b,
			flag_valid  => xhat_split_2_valid,
			flag_ready  => open,
			flag_data   => xhat_split_2_last_s,
			output_valid=> last_round_valid,
			output_ready=> last_round_ready,
			output_data => last_round_flag
		);
		
	--last round flag splitter
	last_round_flag_splitter: entity work.AXIS_SPLITTER_2
		generic map (
			DATA_WIDTH => 1
		)
		port map (
			clk => clk, rst => rst,
			input_valid => last_round_valid,
			input_data  => last_round_flag,
			input_ready => last_round_ready,
			output_0_valid => last_round_0_valid,
			output_0_ready => last_round_0_ready,
			output_0_data  => last_round_0_flag,
			output_1_valid => last_round_1_valid,
			output_1_ready => last_round_1_ready,
			output_1_data  => last_round_1_flag
		);
		
	--eliminate last mean (unused) (has to be done here, can't be done from the outside since this is calculating ahead of time to save time,
	--and if filtering is done outside, we have to wait until the flag is ready).
	xhatoutmean_last_filter: entity work.AXIS_FILTER 
		generic map (
			DATA_WIDTH => DATA_WIDTH,
			ELIMINATE_ON_UP => true
		)
		port map (
			clk => clk, rst => rst,
			input_valid => xhatoutmean_unfiltered_valid,
			input_ready => xhatoutmean_unfiltered_ready,
			input_data  => xhatoutmean_unfiltered_data,
			flag_valid  => last_round_1_valid,
			flag_ready  => last_round_1_ready,
			flag_data   => last_round_1_flag,
			output_valid=> xhatoutmean_valid,
			output_ready=> xhatoutmean_ready,
			output_data => xhatoutmean_data
		);
		
	--select sample
	sample_selector: entity work.AXIS_BATCH_SELECTOR 
		generic map (
			DATA_WIDTH => DATA_WIDTH,
			LAST_POLICY => AND_ALL
		)
		port map (
			clk => clk, rst => rst,
			input_0_data	=> xtilde_fifo_data,
			input_0_ready	=> xtilde_fifo_ready,
			input_0_valid	=> xtilde_fifo_valid,
			input_0_last    => xtilde_fifo_last,
			input_1_data	=> xhat_fifo_data,
			input_1_ready	=> xhat_fifo_ready,
			input_1_valid	=> xhat_fifo_valid,
			input_1_last    => xhat_fifo_last,
			flag_data		=> d_flag_0_data,
			flag_ready		=> d_flag_0_ready,
			flag_valid		=> d_flag_0_valid,
			output_data		=> xhatout_unfiltered_data,
			output_valid	=> xhatout_unfiltered_valid,
			output_ready	=> xhatout_unfiltered_ready,
			output_last     => xhatout_unfiltered_last
		);
		
	xhatout_filter: entity work.AXIS_BATCH_FILTER
		generic map (
			DATA_WIDTH => DATA_WIDTH,
			ELIMINATE_ON_UP => true
		)
		port map (
			clk => clk, rst => rst,
			input_valid => xhatout_unfiltered_valid,
			input_ready => xhatout_unfiltered_ready,
			input_data  => xhatout_unfiltered_data,
			input_last  => xhatout_unfiltered_last,
			flag_valid  => last_round_0_valid,
			flag_ready  => last_round_0_ready,
			flag_data   => last_round_0_flag,
			output_valid=> xhatout_valid,
			output_ready=> xhatout_ready,
			output_data => xhatout_data,
			output_last => xhatout_last_s
		);
		
end Behavioral;
