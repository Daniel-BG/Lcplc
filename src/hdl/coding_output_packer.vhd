----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.02.2019 11:45:48
-- Design Name: 
-- Module Name: CODING_OUTPUT_PACKER - Behavioral
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
use IEEE.NUMERIC_STD.ALL;
use work.functions.all;

entity CODING_OUTPUT_PACKER is
	Generic (
		CODE_WIDTH: integer := 39;
		BIT_AMT_WIDTH: integer := 6;
		OUTPUT_WIDTH_LOG: integer := 5;
		FIFO_SLACK: integer := 2
	);
	Port (
		clk, rst			: in	std_logic;
		flush				: in 	std_logic;
		flushed				: out 	std_logic;
		input_code_data		: in	std_logic_vector(CODE_WIDTH - 1 downto 0);
		input_length_data	: in 	std_logic_vector(BIT_AMT_WIDTH - 1 downto 0);
		input_valid			: in 	std_logic;
		input_ready			: out 	std_logic;
		output_data			: out	std_logic_vector(2**OUTPUT_WIDTH_LOG - 1 downto 0);
		output_valid		: out	std_logic;
		output_ready		: in 	std_logic
	);
end CODING_OUTPUT_PACKER;

architecture Behavioral of CODING_OUTPUT_PACKER is
	function calc_slack (input_width, target_width_log: integer) return integer is
	begin
		return bits(input_width-1)-target_width_log + 1;
	end function;
	
	constant OUTPUT_WIDTH_SLACK: integer := calc_slack(CODE_WIDTH, OUTPUT_WIDTH_LOG);
	--constant BIT_AMT_WIDTH: integer := bits(CODE_WIDTH);
	constant COUNTER_WIDTH: integer := OUTPUT_WIDTH_LOG + OUTPUT_WIDTH_SLACK;
	constant SHIFTED_WIDTH: integer := CODE_WIDTH + 2**OUTPUT_WIDTH_LOG - 1;
	

	--splitter
	signal shifter_segmenter_splitter_input: std_logic_vector(CODE_WIDTH + BIT_AMT_WIDTH - 1 downto 0);
	signal sss_0_valid, sss_0_ready: std_logic;
	signal sss_1_ready, sss_1_valid: std_logic;
	signal sss_0_data: std_logic_vector(CODE_WIDTH + BIT_AMT_WIDTH - 1 downto 0);
	signal sss_1_data: std_logic_vector(CODE_WIDTH + BIT_AMT_WIDTH - 1 downto 0);
	signal sss_0_data_code: std_logic_vector(CODE_WIDTH - 1 downto 0);
	signal sss_1_data_code: std_logic_vector(CODE_WIDTH - 1 downto 0);
	signal sss_0_data_shift: std_logic_vector(BIT_AMT_WIDTH - 1 downto 0);
	signal sss_1_data_shift: std_logic_vector(BIT_AMT_WIDTH - 1 downto 0);
	
	--length splitter
	signal length_0_valid, length_0_ready: std_logic;
	signal length_1_valid, length_1_ready: std_logic;
	signal length_2_valid, length_2_ready: std_logic;
	signal length_0_data: std_logic_vector(BIT_AMT_WIDTH - 1 downto 0);
	signal length_1_data: std_logic_vector(BIT_AMT_WIDTH - 1 downto 0);
	signal length_2_data: std_logic_vector(BIT_AMT_WIDTH - 1 downto 0);
	
	--partial sums
	signal len_cnt_data: std_logic_vector(COUNTER_WIDTH-1 downto 0);
	signal len_cnt_rst_data: std_logic_vector(COUNTER_WIDTH-1 downto 0);
	signal len_cnt_valid, len_cnt_ready: std_logic;
	signal len_cnt_rst_valid, len_cnt_rst_ready: std_logic;
	
	--delay for shift adjustment
	signal len_cnt_rst_ready_buf, len_cnt_rst_valid_buf: std_logic;
	signal len_cnt_rst_data_buf: std_logic_vector(COUNTER_WIDTH-1 downto 0);
	
	--shift adjustments
	signal adjust_data: std_logic_vector(BIT_AMT_WIDTH - 1 downto 0);
	signal adjust_valid, adjust_ready: std_logic;
	signal final_shift_data: std_logic_vector(COUNTER_WIDTH - 1 downto 0);
	signal final_shift_valid, final_shift_ready: std_logic;
	
	--delayed data input to shifter
	signal sss_1_ready_buf, sss_1_valid_buf: std_logic;
	signal sss_1_data_code_buf: std_logic_vector(CODE_WIDTH - 1 downto 0);
	
	--shifted results /presults
	signal shifted_data, data_code_extended: std_logic_vector(SHIFTED_WIDTH - 1 downto 0);
	signal shifted_ready, shifted_valid: std_logic;
	
	--delay before segmenter
	signal len_cnt_ready_buf, len_cnt_valid_buf: std_logic;
	signal len_cnt_data_buf: std_logic_vector(COUNTER_WIDTH-1 downto 0);
	
	--segmenter things
	signal segmenter_data: std_logic_vector(2**OUTPUT_WIDTH_LOG - 1 downto 0);
	--signal segmenter_buffered: std_logic;
	signal segmenter_ends_word, segmenter_ready, segmenter_valid: std_logic;

	--delayer inbetween segmenter and merger
	signal segmenter_data_ends_buf: std_logic_vector(2**OUTPUT_WIDTH_LOG downto 0);
	signal segmenter_data_buf: std_logic_vector(2**OUTPUT_WIDTH_LOG - 1 downto 0);
	signal segmenter_ends_word_buf: std_logic;
	signal segmenter_valid_buf, segmenter_ready_buf: std_logic;
	
	--merger
	signal merger_data: std_logic_vector(2**OUTPUT_WIDTH_LOG - 1 downto 0);
	signal merger_valid, merger_ready: std_logic;
	--signal merger_flush: std_logic;
begin
								  
								  
	--splitter (one for shifter, one for c2w_segmenter)
	shifter_segmenter_splitter_input <= input_code_data & input_length_data;
	shifter_segmenter_splitter: entity work.AXIS_SPLITTER_2 
		Generic map(
			DATA_WIDTH => CODE_WIDTH + BIT_AMT_WIDTH
		)
		Port map (
			clk => clk, rst	=> rst,
			--to input axi port
			input_valid => input_valid,
			input_data	=> shifter_segmenter_splitter_input,
			input_ready => input_ready,
			--to output axi ports
			output_0_valid => sss_0_valid,
			output_0_data  => sss_0_data,
			output_0_ready => sss_0_ready,
			output_1_valid => sss_1_valid,
			output_1_data  => sss_1_data,
			output_1_ready => sss_1_ready
		);
	sss_0_data_code <= sss_0_data(sss_0_data'high downto sss_0_data'high - CODE_WIDTH + 1);
	sss_1_data_code <= sss_1_data(sss_1_data'high downto sss_1_data'high - CODE_WIDTH + 1);
	sss_0_data_shift <= sss_0_data(BIT_AMT_WIDTH - 1 downto 0);
	sss_1_data_shift <= sss_1_data(BIT_AMT_WIDTH - 1 downto 0);
	
	--split length into two partial sums 
	length_splitter: entity work.AXIS_SPLITTER_3
		Generic map(
			DATA_WIDTH => BIT_AMT_WIDTH
		)
		Port map (
			clk => clk, rst	=> rst,
			--to input axi port
			input_valid => sss_0_valid,
			input_data	=> sss_0_data_shift,
			input_ready => sss_0_ready,
			--to output axi ports
			output_0_valid => length_0_valid,
			output_0_data  => length_0_data,
			output_0_ready => length_0_ready,
			output_1_valid => length_1_valid,
			output_1_data  => length_1_data,
			output_1_ready => length_1_ready,
			output_2_valid => length_2_valid,
			output_2_data  => length_2_data,
			output_2_ready => length_2_ready
		);
		
	--partial sums (one starting @reset value, the other @reset plus first)
	partial_sum_reset: entity work.AXIS_PARTIAL_SUM
		Generic map(
			INPUT_WIDTH_LOG		=> BIT_AMT_WIDTH,
			COUNTER_WIDTH_LOG	=> COUNTER_WIDTH,
			RESET_VALUE			=> 2**COUNTER_WIDTH-1,
			START_ON_RESET		=> true,
			IS_ADD				=> false
		)
		Port map (
			clk => clk, rst	=> rst,
			input_data		=> length_0_data,
			input_valid		=> length_0_valid,
			input_ready		=> length_0_ready,
			output_data 	=> len_cnt_rst_data,
			output_valid	=> len_cnt_rst_valid,
			output_ready	=> len_cnt_rst_ready
		);
		
	partial_sum_no_reset: entity work.AXIS_PARTIAL_SUM
		Generic map(
			INPUT_WIDTH_LOG		=> BIT_AMT_WIDTH,
			COUNTER_WIDTH_LOG	=> COUNTER_WIDTH,
			RESET_VALUE			=> 2**COUNTER_WIDTH-1,
			START_ON_RESET		=> false,
			IS_ADD				=> false
		)
		Port map (
			clk => clk, rst	=> rst,
			input_data		=> length_1_data,
			input_valid		=> length_1_valid,
			input_ready		=> length_1_ready,
			output_data 	=> len_cnt_data,
			output_valid	=> len_cnt_valid,
			output_ready	=> len_cnt_ready
		);
		
	--preparation of shift value
	shift_sub: entity work.AXIS_ARITHMETIC_OP
		Generic map (
			DATA_WIDTH_0 => BIT_AMT_WIDTH,
			DATA_WIDTH_1 => BIT_AMT_WIDTH,
			OUTPUT_DATA_WIDTH => BIT_AMT_WIDTH,
			IS_ADD => false,
			SIGN_EXTEND_0 => false,
			SIGN_EXTEND_1 => false,
			SIGNED_OP => false
		)
		Port map(
			clk => clk, rst => rst,
			input_0_data  => std_logic_vector(to_unsigned(CODE_WIDTH, BIT_AMT_WIDTH)),
			input_0_valid => '1',
			input_0_ready => open,
			input_1_data  => length_2_data,
			input_1_valid => length_2_valid,
			input_1_ready => length_2_ready,
			output_data	  => adjust_data,
			output_valid  => adjust_valid,
			output_ready  => adjust_ready
		);
		
	--delay for sum w/reset
	len_cnt_rst_buf: entity work.AXIS_FIFO
		Generic map (
			DATA_WIDTH => COUNTER_WIDTH,
			FIFO_DEPTH => 2 + FIFO_SLACK
		)
		Port map (
			clk => clk, rst => rst,
			input_ready =>len_cnt_rst_ready,
			input_valid =>len_cnt_rst_valid,
			input_data  =>len_cnt_rst_data,
			output_ready=>len_cnt_rst_ready_buf,
			output_valid=>len_cnt_rst_valid_buf,
			output_data =>len_cnt_rst_data_buf
		);
		
	shift_add: entity work.AXIS_ARITHMETIC_OP
		Generic map (
			DATA_WIDTH_0 => OUTPUT_WIDTH_LOG,
			DATA_WIDTH_1 => BIT_AMT_WIDTH,
			OUTPUT_DATA_WIDTH => COUNTER_WIDTH,
			IS_ADD => true,
			SIGN_EXTEND_0 => false,
			SIGN_EXTEND_1 => false,
			SIGNED_OP => false
		)
		Port map(
			clk => clk, rst => rst,
			input_0_data  => len_cnt_rst_data_buf(OUTPUT_WIDTH_LOG - 1 downto 0),
			input_0_valid => len_cnt_rst_valid_buf,
			input_0_ready => len_cnt_rst_ready_buf,
			input_1_data  => adjust_data,
			input_1_valid => adjust_valid,
			input_1_ready => adjust_ready,
			output_data	  => final_shift_data,
			output_valid  => final_shift_valid,
			output_ready  => final_shift_ready
		);
		
	--FIFO buffer before shifter
	data_buf: entity work.AXIS_FIFO
		Generic map (
			DATA_WIDTH => CODE_WIDTH,
			FIFO_DEPTH => 5 + FIFO_SLACK
		)
		Port map ( 
			clk => clk, rst	=> rst,
			--input axi port
			input_valid		=> sss_1_valid,
			input_ready		=> sss_1_ready,
			input_data		=> sss_1_data_code,
			--out axi port
			output_ready	=> sss_1_ready_buf,
			output_data		=> sss_1_data_code_buf,
			output_valid	=> sss_1_valid_buf
		);
		
	--shifter
	data_code_extended <= (SHIFTED_WIDTH - 1 downto CODE_WIDTH => '0') & sss_1_data_code_buf;
	shifter: entity work.AXIS_SHIFTER 
		Generic map (
			SHIFT_WIDTH	=> COUNTER_WIDTH,
			DATA_WIDTH  => SHIFTED_WIDTH,
			LEFT	    => true,
			ARITHMETIC	=> false
		)
		Port map ( 
			clk => clk, rst	=> rst,
			shift_data		=> final_shift_data,
			shift_ready		=> final_shift_ready,
			shift_valid		=> final_shift_valid,
			input_data		=> data_code_extended, 
			input_ready		=> sss_1_ready_buf,
			input_valid		=> sss_1_valid_buf,
			output_data		=> shifted_data,
			output_ready	=> shifted_ready,
			output_valid	=> shifted_valid
		);
		
	--delay fifo for len_cnt
	len_cnt_buf: entity work.AXIS_FIFO
		Generic map (
			DATA_WIDTH => COUNTER_WIDTH,
			FIFO_DEPTH => 12 + FIFO_SLACK
		)
		Port map ( 
			clk => clk, rst	=> rst,
			--input axi port
			input_valid		=> len_cnt_valid,
			input_ready		=> len_cnt_ready,
			input_data		=> len_cnt_data,
			--out axi port
			output_ready	=> len_cnt_ready_buf,
			output_data		=> len_cnt_data_buf,
			output_valid	=> len_cnt_valid_buf
		);
		
	--segmenter
	segmenter: entity work.CODE_TO_WORD_SEGMENTER 
		Generic map (
			BASE_WIDTH => CODE_WIDTH,
			WORD_WIDTH_LOG => OUTPUT_WIDTH_LOG,
			WORD_CNT_SLACK => OUTPUT_WIDTH_SLACK
		)
		Port map (
			clk => clk, rst => rst,
			bits_data		=> shifted_data,
			bits_ready		=> shifted_ready,
			bits_valid		=> shifted_valid,
			position_data	=> len_cnt_data_buf,
			position_ready	=> len_cnt_ready_buf,
			position_valid	=> len_cnt_valid_buf,
			output_data		=> segmenter_data,
			output_ends_word=> segmenter_ends_word,
			output_ready	=> segmenter_ready,
			output_valid	=> segmenter_valid,
			has_data_buffered=> open
		);

	--remove critical path here
	segmenter_merger_delay: entity work.AXIS_LATCHED_CONNECTION
		Generic map(
			DATA_WIDTH => 2**OUTPUT_WIDTH_LOG + 1
		)
		Port map (
			clk => clk, rst => rst,
			input_ready => segmenter_ready,
			input_valid => segmenter_valid,
			input_data  => segmenter_data & segmenter_ends_word,
			output_ready => segmenter_ready_buf,
			output_valid => segmenter_valid_buf,
			output_data  => segmenter_data_ends_buf
		);
	segmenter_data_buf <= segmenter_data_ends_buf(2**OUTPUT_WIDTH_LOG downto 1);
	segmenter_ends_word_buf <= segmenter_data_ends_buf(0);
		
	--merger
	merger: entity work.WORD_MERGER 
		Generic map (
			WORD_WIDTH => 2**OUTPUT_WIDTH_LOG
		)
		Port map (
			clk => clk, rst => rst,
			input_data		=> segmenter_data_buf,
			input_ends_word	=> segmenter_ends_word_buf,
			input_valid		=> segmenter_valid_buf,
			input_ready		=> segmenter_ready_buf,
			output_data		=> merger_data,
			output_valid	=> merger_valid,
			output_ready	=> merger_ready,
			flush   		=> '0'
		);
		
	output_valid <= merger_valid;
	merger_ready <= output_ready;
	output_data  <= merger_data;
		
end Behavioral;
