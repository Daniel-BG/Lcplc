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
		BLOCK_SIZE_LOG: integer := 8;
		THRESHOLD: std_logic_vector := "100000000000000" --has to be std_logic_vector because its value might be greater than 2^32-1: the max of positive
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
		d_data			: in	std_logic_vector((DATA_WIDTH + 3)*2 + BLOCK_SIZE_LOG - 1 downto 0);
		d_ready			: out	std_logic;
		d_valid			: in 	std_logic;
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
	signal d_flag_thres: std_logic_vector((DATA_WIDTH + 3)*2 + BLOCK_SIZE_LOG - 1 downto 0); 
	signal d_flag_data_raw: std_logic;
	signal d_flag_data: std_logic_vector(0 downto 0);
	signal d_flag_valid, d_flag_ready: std_logic;
	
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
	xhat_splitter: entity work.SPLITTER_AXI_2
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
	xtilde_splitter: entity work.SPLITTER_AXI_2
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
	xhat_fifo: entity work.FIFO_AXI
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			FIFO_DEPTH => 2**BLOCK_SIZE_LOG
		)
		Port map ( 
			clk	=> clk, rst => rst,
			--input axi port
			in_valid => xhat_split_0_valid,
			in_ready => xhat_split_0_ready,
			in_data  => xhat_split_0_data,
			--out axi port
			out_ready => xhat_fifo_ready,
			out_data  => xhat_fifo_data,
			out_valid => xhat_fifo_valid
		);
	xtilde_fifo: entity work.FIFO_AXI
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			FIFO_DEPTH => 2**BLOCK_SIZE_LOG
		)
		Port map ( 
			clk	=> clk, rst => rst,
			--input axi port
			in_valid => xtilde_split_0_valid,
			in_ready => xtilde_split_0_ready,
			in_data  => xtilde_split_0_data,
			--out axi port
			out_ready => xtilde_fifo_ready,
			out_data  => xtilde_fifo_data,
			out_valid => xtilde_fifo_valid
		);
		
	--mean calcs
	xhat_acc: entity work.MEAN_CALCULATOR 
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			ACC_LOG => BLOCK_SIZE_LOG,
			IS_SIGNED => false
		)
		Port map (
			clk => clk, rst => rst,
			input		=> xhat_split_1_data,
			input_valid => xhat_split_1_valid,
			input_ready => xhat_split_1_ready,
			output_data => xhatmean_data,
			output_valid=> xhatmean_valid,
			output_ready=> xhatmean_ready
		);
		
	xtilde_acc: entity work.MEAN_CALCULATOR 
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			ACC_LOG => BLOCK_SIZE_LOG,
			IS_SIGNED => false
		)
		Port map (
			clk => clk, rst => rst,
			input		=> xtilde_split_1_data,
			input_valid => xtilde_split_1_valid,
			input_ready => xtilde_split_1_ready,
			output_data => xtildemean_data,
			output_valid=> xtildemean_valid,
			output_ready=> xtildemean_ready
		);
		
	--threshold calculations	
	d_flag_thres <= std_logic_vector(resize(unsigned(THRESHOLD),(DATA_WIDTH + 3)*2 + BLOCK_SIZE_LOG));
	d_threshold_comparator: entity work.COMPARATOR_AXI
		Generic map (
			DATA_WIDTH => (DATA_WIDTH + 3)*2 + BLOCK_SIZE_LOG,
			IS_SIGNED => false,
			IS_EQUAL => false,
			IS_GREATER => true
		)
		Port map (
			clk => clk, rst => rst,
			input_a => d_data,
			input_b => d_flag_thres,
			input_valid => d_valid,
			input_ready => d_ready,
			output => d_flag_data_raw,
			output_valid => d_flag_valid,
			output_ready => d_flag_ready
		);
	d_flag_data <= "0" when d_flag_data_raw = '0' else "1";
	
	d_threshold_splitter: entity  work.SPLITTER_AXI_2
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
	mean_selector: entity work.SELECTOR_AXI_MP 
		generic map (
			DATA_WIDTH => DATA_WIDTH
		)
		port map (
			clk => clk, rst => rst,
			input_false_data	=> xtildemean_data,
			input_false_ready	=> xtildemean_ready,
			input_false_valid	=> xtildemean_valid,
			input_true_data		=> xhatmean_data,
			input_true_ready	=> xhatmean_ready,
			input_true_valid	=> xhatmean_valid,
			flag_data			=> d_flag_1_data,
			flag_ready			=> d_flag_1_ready,
			flag_valid			=> d_flag_1_valid,
			output_data			=> xhatoutmean_data,
			output_valid		=> xhatoutmean_valid,
			output_ready		=> xhatoutmean_ready
		);
		
	--replicate flag for sample selector
	flag_repeater: entity work.DATA_REPEATER_AXI
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
	sample_selector: entity work.SELECTOR_AXI_MP 
		generic map (
			DATA_WIDTH => DATA_WIDTH
		)
		port map (
			clk => clk, rst => rst,
			input_false_data	=> xtilde_fifo_data,
			input_false_ready	=> xtilde_fifo_ready,
			input_false_valid	=> xtilde_fifo_valid,
			input_true_data		=> xhat_fifo_data,
			input_true_ready	=> xhat_fifo_ready,
			input_true_valid	=> xhat_fifo_valid,
			flag_data			=> d_flag_0_rep_data,
			flag_ready			=> d_flag_0_rep_ready,
			flag_valid			=> d_flag_0_rep_valid,
			output_data			=> xhatout_data,
			output_valid		=> xhatout_valid,
			output_ready		=> xhatout_ready
		);
		
end Behavioral;