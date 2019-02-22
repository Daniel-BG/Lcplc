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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

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
		xtilde_data		: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		xtilde_ready	: out	std_logic;
		xtilde_valid	: in	std_logic;
		d_flag_data_raw	: in	std_logic;
		d_flag_ready	: out	std_logic;
		d_flag_valid	: in 	std_logic;
		xhatout_data	: out	std_logic_vector(DATA_WIDTH - 1 downto 0);
		xhatout_ready	: in	std_logic;
		xhatout_valid	: out	std_logic;
		xhatoutmean_data: out   std_logic_vector(DATA_WIDTH - 1 downto 0);
		xhatoutmean_ready:in  	std_logic;
		xhatoutmean_valid:out   std_logic
	);
end NEXT_XHAT_PRECALC;

architecture Behavioral of NEXT_XHAT_PRECALC is

	--xhat splitter
	signal xhat_split_0_valid, xhat_split_0_ready, xhat_split_1_valid, xhat_split_1_ready: std_logic;
	signal xhat_split_0_data, xhat_split_1_data: std_logic_vector(DATA_WIDTH - 1 downto 0);

	--xtilde splitter
	signal xtilde_split_0_valid, xtilde_split_0_ready, xtilde_split_1_valid, xtilde_split_1_ready: std_logic;
	signal xtilde_split_0_data, xtilde_split_1_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--xhat and xtilde fifos
	signal xhat_fifo_ready, xhat_fifo_valid: std_logic;
	signal xhat_fifo_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	signal xtilde_fifo_ready, xtilde_fifo_valid: std_logic;
	signal xtilde_fifo_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--accumulators
	signal xhatmean_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xhatmean_valid, xhatmean_ready: std_logic;

	signal xtildemean_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xtildemean_valid, xtildemean_ready: std_logic;

	--flag gen
	signal d_flag_data: std_logic_vector(0 downto 0);
	
	--flag splitter
	signal d_flag_0_valid, d_flag_0_ready, d_flag_1_valid, d_flag_1_ready: std_logic;
	signal d_flag_0_data, d_flag_1_data: std_logic_vector(0 downto 0);
	
	--flag repeater
	signal d_flag_0_rep_ready, d_flag_0_rep_valid: std_logic;
	signal d_flag_0_rep_data: std_logic_vector(0 downto 0); 

begin

	--split xhat and xtilde data
	--one goes to mean calculation
	--the other goes to queue of block_size_log depth
	--whenever D is found check threshold
	--and enable whatever queue is ok

	--SPLITTERS
	xhat_splitter: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH => DATA_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			--to input axi port
			input_valid => xhat_valid,
			input_data  => xhat_data,
			input_ready => xhat_ready,
			--to output axi ports
			output_0_valid => xhat_split_0_valid,
			output_0_data  => xhat_split_0_data,
			output_0_ready => xhat_split_0_ready,
			output_1_valid => xhat_split_1_valid,
			output_1_data  => xhat_split_1_data,
			output_1_ready => xhat_split_1_ready
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
				--to output axi ports
				output_0_valid => xtilde_split_0_valid,
				output_0_data  => xtilde_split_0_data,
				output_0_ready => xtilde_split_0_ready,
				output_1_valid => xtilde_split_1_valid,
				output_1_data  => xtilde_split_1_data,
				output_1_ready => xtilde_split_1_ready
			);
			
	--FIFOS
	xhat_fifo: entity work.AXIS_FIFO
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			FIFO_DEPTH => 2**BLOCK_SIZE_LOG
		)
		Port map ( 
			clk	=> clk, rst => rst,
			--input axi port
			input_valid => xhat_split_0_valid,
			input_ready => xhat_split_0_ready,
			input_data  => xhat_split_0_data,
			--out axi port
			output_ready => xhat_fifo_ready,
			output_data  => xhat_fifo_data,
			output_valid => xhat_fifo_valid
		);
	xtilde_fifo: entity work.AXIS_FIFO
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			FIFO_DEPTH => 2**BLOCK_SIZE_LOG
		)
		Port map ( 
			clk	=> clk, rst => rst,
			--input axi port
			input_valid => xtilde_split_0_valid,
			input_ready => xtilde_split_0_ready,
			input_data  => xtilde_split_0_data,
			--out axi port
			output_ready => xtilde_fifo_ready,
			output_data  => xtilde_fifo_data,
			output_valid => xtilde_fifo_valid
		);
		
	--mean calcs
	xhat_acc: entity work.AXIS_AVERAGER_POW2 
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			ELEMENT_COUNT_LOG => BLOCK_SIZE_LOG,
			IS_SIGNED => false
		)
		Port map (
			clk => clk, rst => rst,
			input_data	=> xhat_split_1_data,
			input_valid => xhat_split_1_valid,
			input_ready => xhat_split_1_ready,
			output_data => xhatmean_data,
			output_valid=> xhatmean_valid,
			output_ready=> xhatmean_ready
		);
		
	xtilde_acc: entity work.AXIS_AVERAGER_POW2 
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			ELEMENT_COUNT_LOG => BLOCK_SIZE_LOG,
			IS_SIGNED => false
		)
		Port map (
			clk => clk, rst => rst,
			input_data	=> xtilde_split_1_data,
			input_valid => xtilde_split_1_valid,
			input_ready => xtilde_split_1_ready,
			output_data => xtildemean_data,
			output_valid=> xtildemean_valid,
			output_ready=> xtildemean_ready
		);
		
	--threshold splitter
	d_flag_data <= "0" when d_flag_data_raw = '0' else "1";
	d_threshold_splitter: entity  work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH => 1
		)
		Port map (
			clk => clk, rst => rst,
			input_valid		=> d_flag_valid,
			input_data		=> d_flag_data,
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
			output_data		=> xhatoutmean_data,
			output_valid	=> xhatoutmean_valid,
			output_ready	=> xhatoutmean_ready
		);
		
	--replicate flag for sample selector
	flag_repeater: entity work.AXIS_DATA_REPEATER
		Generic map (
			DATA_WIDTH => 1,
			NUMBER_OF_REPETITIONS => 2**BLOCK_SIZE_LOG
		)
		Port map (
			clk => clk, rst => rst,
			input_ready => d_flag_0_ready,
			input_valid	=> d_flag_0_valid,
			input_data	=> d_flag_0_data,
			output_ready=> d_flag_0_rep_ready,
			output_valid=> d_flag_0_rep_valid,
			output_data	=> d_flag_0_rep_data
		);
		
	--select sample
	sample_selector: entity work.AXIS_SELECTOR 
		generic map (
			DATA_WIDTH => DATA_WIDTH
		)
		port map (
			clk => clk, rst => rst,
			input_0_data	=> xtilde_fifo_data,
			input_0_ready	=> xtilde_fifo_ready,
			input_0_valid	=> xtilde_fifo_valid,
			input_1_data	=> xhat_fifo_data,
			input_1_ready	=> xhat_fifo_ready,
			input_1_valid	=> xhat_fifo_valid,
			flag_data		=> d_flag_0_rep_data,
			flag_ready		=> d_flag_0_rep_ready,
			flag_valid		=> d_flag_0_rep_valid,
			output_data		=> xhatout_data,
			output_valid	=> xhatout_valid,
			output_ready	=> xhatout_ready
		);
		
end Behavioral;
