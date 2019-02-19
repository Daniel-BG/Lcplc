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

use work.functions.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity CODING_OUTPUT_PACKER is
	Generic (
		CODE_WIDTH: integer := 39;
		OUTPUT_WIDTH_LOG: integer := 5
	);
	Port (
		clk, rst			: in	std_logic;
		flush				: in 	std_logic;
		flushed				: out 	std_logic;
		input_code_data		: in	std_logic_vector(CODE_WIDTH - 1 downto 0);
		input_length_data	: in 	natural range 0 to CODE_WIDTH;
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
	
	--shiftamt calc outputs
	signal shiftamt_input_ready: std_logic;
	signal shiftamt_shift: std_logic_vector(OUTPUT_WIDTH_LOG + OUTPUT_WIDTH_SLACK - 1 downto 0);
	signal shiftamt_valid: std_logic;
	signal shiftamt_ready: std_logic;
	
	--splitter
	signal shifter_segmenter_splitter_input: std_logic_vector(CODE_WIDTH + OUTPUT_WIDTH_LOG + OUTPUT_WIDTH_SLACK - 1 downto 0);
	signal sss_0_valid, sss_1_ready, sss_0_ready, sss_1_valid: std_logic;
	signal sss_0_data, sss_1_data: std_logic_vector(CODE_WIDTH + OUTPUT_WIDTH_LOG + OUTPUT_WIDTH_SLACK - 1 downto 0);
	signal sss_0_data_code, sss_1_data_code: std_logic_vector(CODE_WIDTH - 1 downto 0);
	signal sss_0_data_shift, sss_1_data_shift: std_logic_vector(OUTPUT_WIDTH_LOG + OUTPUT_WIDTH_SLACK - 1 downto 0);
	
	--shifter
	signal shifter_input_shift: natural range 0 to 2**OUTPUT_WIDTH_LOG - 1;
	signal shifter_input_data, shifter_data: std_logic_vector(CODE_WIDTH + 2**OUTPUT_WIDTH_LOG - 2 downto 0);
	signal shifter_ready, shifter_valid: std_logic;
	
	--fifo to delay inputs to c2w segmenter
	constant SHIFTAMT_DELAY_FIFO_DEPTH: integer := 10;
	signal shamt_delay_fifo_ready, shamt_delay_fifo_valid: std_logic; 
	signal shamt_delay_fifo_data: std_logic_vector(OUTPUT_WIDTH_LOG + OUTPUT_WIDTH_SLACK - 1 downto 0);
	
	--joiner for shifter and fifo
	signal shift_shamt_valid, shift_shamt_ready: std_logic;
	signal shift_shamt_data: std_logic_vector(CODE_WIDTH + 2**OUTPUT_WIDTH_LOG - 2 downto 0);
	signal shift_shamt_shamt: std_logic_vector(OUTPUT_WIDTH_LOG + OUTPUT_WIDTH_SLACK - 1 downto 0);
	
	--segmenter signals
	signal segmenter_data: std_logic_vector(2**OUTPUT_WIDTH_LOG - 1 downto 0);
	signal segmenter_ends_word: std_logic;
	signal segmenter_ready, segmenter_valid: std_logic;
	signal segmenter_buffered: std_logic;
	
	--merger delayed data
	signal merger_delay_data, merger_delay_input_data: std_logic_vector( 2**OUTPUT_WIDTH_LOG downto 0);
	signal merger_delay_ready, merger_delay_valid: std_logic;
	signal merger_delay_data_data: std_logic_vector(2**OUTPUT_WIDTH_LOG - 1 downto 0);
	signal merger_delay_data_flag: std_logic;
	
	--merger hijacked signals for flushing
	signal merger_valid: std_logic;
	signal merger_flush: std_logic;
	
	--flushing control signals
	signal inflight_transactions: natural range 0 to 31; --enough space for all stages within the packer
	type flushing_state_t is (WAITING, COUNTDOWN, FINISHING, FINISHED);
	signal state_curr, state_next: flushing_state_t;
	constant COUNTDOWN_MAX: integer := 4; --4 should be enough
	signal end_countdown, end_countdown_next: natural range 0 to COUNTDOWN_MAX; 
	
begin
	--inflight control
	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				inflight_transactions <= 0;			
				state_curr <= WAITING;
				end_countdown <= 0;
			else
				--how many enter the packer vs how many left the segmenter
				if input_valid = '1' and shiftamt_input_ready = '1' and shift_shamt_ready = '1' and shift_shamt_valid = '1' then
					 --do nothing, one goes in one goes out
				elsif input_valid = '1' and shiftamt_input_ready = '1' then --one goes in
					inflight_transactions <= inflight_transactions + 1;
				elsif shift_shamt_ready = '1' and shift_shamt_valid = '1' then --one goes out
					inflight_transactions <= inflight_transactions - 1;
				end if;
				state_curr <= state_next;
				end_countdown <= end_countdown_next;
			end if;
		end if;
	end process;
	
	--flushing control
	comb: process(state_curr, flush, inflight_transactions,
		end_countdown, merger_valid, output_ready)
	begin
		state_next <= state_curr;
		flushed <= '0';
		end_countdown_next <= end_countdown;
		merger_flush <= '0';
		
		if state_curr = WAITING then
			if flush = '1' and inflight_transactions = 0 then
				state_next <= COUNTDOWN;
			end if;
		elsif state_curr = COUNTDOWN then
			if end_countdown = COUNTDOWN_MAX then
				state_next <= FINISHING;
			elsif merger_valid = '0' or output_ready = '1' then
				end_countdown_next <= end_countdown + 1;
			end if; 
		elsif state_curr = FINISHING then
			merger_flush <= '1';
			if merger_valid = '1' and output_ready = '1' then
				state_next <= FINISHED;
			end if;
		elsif state_curr = FINISHED then
			flushed <= '1';
		end if;
	end process;



	--shift amount calculator
	shiftamt_calc: entity work.ACCUMULATED_SHIFTAMT_CALC 
		generic map (
			INPUT_WIDTH => CODE_WIDTH,
			OUTPUT_WIDTH_LOG => OUTPUT_WIDTH_LOG,
			OUTPUT_WIDTH_SLACK => OUTPUT_WIDTH_SLACK
		)
		port map (
			clk => clk, rst => rst,
			input_shift	=> input_length_data,
			input_valid	=> input_valid,
			input_ready	=> shiftamt_input_ready,
			output_shift=> shiftamt_shift,
			output_valid=> shiftamt_valid,
			output_ready=> shiftamt_ready
		);
	input_ready <= shiftamt_input_ready;
		
	--splitter (one for shifter, one for c2w_segmenter)
	shifter_segmenter_splitter_input <= input_code_data & shiftamt_shift;
	shifter_segmenter_splitter: entity work.SPLITTER_AXI_2 
		Generic map(
			DATA_WIDTH => CODE_WIDTH + OUTPUT_WIDTH_LOG + OUTPUT_WIDTH_SLACK
		)
		Port map (
			clk => clk, rst	=> rst,
			--to input axi port
			input_valid => shiftamt_valid,
			input_data	=> shifter_segmenter_splitter_input,
			input_ready => shiftamt_ready,
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
	sss_0_data_shift <= sss_0_data(OUTPUT_WIDTH_LOG + OUTPUT_WIDTH_SLACK - 1 downto 0);
	sss_1_data_shift <= sss_1_data(OUTPUT_WIDTH_LOG + OUTPUT_WIDTH_SLACK - 1 downto 0);
	
	--shifter
	shifter_input_shift <= to_integer(unsigned(sss_0_data_shift(OUTPUT_WIDTH_LOG - 1 downto 0)));
	shifter_input_data <= (2**OUTPUT_WIDTH_LOG - 2 downto 0 => '0') & sss_1_data_code;
	shifter_instance: entity work.LEFT_SHIFTER
		Generic map (
			DATA_WIDTH => CODE_WIDTH + 2**OUTPUT_WIDTH_LOG - 1
		)
		Port map (
			clk => clk, rst => rst,
			input_shift	=> shifter_input_shift,	
			input_data => shifter_input_data,
			input_ready	=> sss_0_ready,
			input_valid => sss_0_valid,
			output_data	=> shifter_data,
			output_ready=> shifter_ready,
			output_valid=> shifter_valid
		);
		
	--fifo to delay inputs to c2w_segmenter
	shiftamt_delay_fifo: entity work.FIFO_AXI 
		Generic map (
			DATA_WIDTH => OUTPUT_WIDTH_LOG + OUTPUT_WIDTH_SLACK,
			FIFO_DEPTH => SHIFTAMT_DELAY_FIFO_DEPTH
		)
		Port map ( 
			clk => clk, rst => rst,
			--input axi port
			in_valid => sss_1_valid,
			in_ready => sss_1_ready,
			in_data	=> sss_1_data_shift,
			--out axi port
			out_ready => shamt_delay_fifo_ready,
			out_data  => shamt_delay_fifo_data,
			out_valid => shamt_delay_fifo_valid
		);
		
	--join shifter output and shamt in fifo
	shift_shamt_join: entity work.JOINER_AXI_2
		Generic map (
			DATA_WIDTH_0 => CODE_WIDTH + 2**OUTPUT_WIDTH_LOG - 1,
			DATA_WIDTH_1 => OUTPUT_WIDTH_LOG + OUTPUT_WIDTH_SLACK
		)
		Port map (
			clk => clk, rst => rst,
			--to input axi port
			input_valid_0 => shifter_valid, input_valid_1 => shamt_delay_fifo_valid,
			input_ready_0 => shifter_ready, input_ready_1 => shamt_delay_fifo_ready,
			input_data_0  => shifter_data,
			input_data_1  => shamt_delay_fifo_data,
			--to output axi ports
			output_valid => shift_shamt_valid,
			output_ready => shift_shamt_ready,
			output_data_0=> shift_shamt_data,
			output_data_1=> shift_shamt_shamt
		);
	
		
	--code to word segmenter
	c2w_segmenter: entity work.CODE_TO_WORD_SEGMENTER 
		Generic map (
			DATA_WIDTH => CODE_WIDTH,
			WORD_WIDTH_LOG => OUTPUT_WIDTH_LOG,
			WORD_CNT_SLACK => OUTPUT_WIDTH_SLACK
		)
		Port map (
			clk => clk, rst => rst,
			input_data		=> shift_shamt_data,
			input_quantity	=> shift_shamt_shamt,
			input_ready		=> shift_shamt_ready,
			input_valid		=> shift_shamt_valid,
			output_data		=> segmenter_data,
			output_ends_word=> segmenter_ends_word,
			output_ready	=> segmenter_ready,
			output_valid	=> segmenter_valid,
			has_data_buffered => segmenter_buffered
		);
		
	--delay minififo
	merger_delay_input_data <= segmenter_ends_word & segmenter_data;
	merger_delay: entity work.MINIFIFO
		Generic map (DATA_WIDTH => 2**OUTPUT_WIDTH_LOG + 1)
		Port map (
			clk => clk, rst => rst,
			in_ready => segmenter_ready,
			in_valid => segmenter_valid,
			in_data => merger_delay_input_data,
			out_ready => merger_delay_ready,
			out_valid => merger_delay_valid,
			out_data => merger_delay_data
		);
	merger_delay_data_data <= merger_delay_data(2**OUTPUT_WIDTH_LOG - 1 downto 0);
	merger_delay_data_flag <= merger_delay_data(2**OUTPUT_WIDTH_LOG);
	
		
	--word merger
	merger: entity work.WORD_MERGER 
		Generic map (
			WORD_WIDTH => 2**OUTPUT_WIDTH_LOG
		)
		Port map (
			clk => clk, rst => rst,
			input_data		=> merger_delay_data_data,
			input_ends_word	=> merger_delay_data_flag,
			input_valid		=> merger_delay_valid,
			input_ready		=> merger_delay_ready,
			output_data		=> output_data,
			output_valid	=> merger_valid,
			output_ready	=> output_ready,
			flush   		=> merger_flush
		);
		
	output_valid <= merger_valid;

end Behavioral;
