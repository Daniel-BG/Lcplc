----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.02.2019 12:20:04
-- Design Name: 
-- Module Name: coder - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

entity CODER is
	Generic (
		MAPPED_ERROR_WIDTH: integer := 19;
		ACC_LOG: integer := 5;
		BLOCK_SIZE_LOG: integer := 8;
		OUTPUT_WIDTH_LOG: integer := 5;
		ALPHA_WIDTH: integer := 10;
		DATA_WIDTH: integer := 16
	);
	Port (
		clk, rst	: in 	std_logic;
		--control
		flush		: in	std_logic;
		flushed		: out 	std_logic;
		--EHAT INPUT: total of 2**BLOCK_SIZE_LOG per BAND
		--	first one is not a mapped error but a raw value that goes to the exp coder
		--	but comes here for ease of use
		ehat_data	: in	std_logic_vector(MAPPED_ERROR_WIDTH - 1 downto 0);
		ehat_ready	: out	std_logic;
		ehat_valid	: in 	std_logic;
		--KJ INPUT: total of 2**BLOCK_SIZE_LOG - 1 per BAND
		--	one less is needed than EHAT since the first goes to EXP coder and does not need param kj
		kj_data		: in 	std_logic_vector(ACC_LOG - 1 downto 0);
		kj_ready	: out	std_logic;
		kj_valid	: in 	std_logic;
		--D FLAG INPUT: one per BAND, if flag is 1 the block is coded, otherwise it is not
		--	first flag should always be 1 since the first band is always coded
		d_flag_data	: in	std_logic_vector(0 downto 0);
		d_flag_ready: out	std_logic;
		d_flag_valid: in 	std_logic;
		--ALPHA INPUT: one per band except last (last comes trimmed from outside)
		alpha_data	: in 	std_logic_vector(ALPHA_WIDTH - 1 downto 0);
		alpha_ready : out 	std_logic;
		alpha_valid	: in 	std_logic;
		--XMEAN INPUT: one per band except first (first comes trimmed from outside)
		xmean_data	: in 	std_logic_vector(DATA_WIDTH - 1 downto 0);
		xmean_ready : out 	std_logic;
		xmean_valid : in 	std_logic;
		--outputs
		--??????
		output_data	: out	std_logic_vector(2**OUTPUT_WIDTH_LOG - 1 downto 0);
		output_valid: out	std_logic;
		output_ready: in 	std_logic
	);
end CODER;

architecture Behavioral of CODER is
	--splitter signals
	signal d_flag_0_valid, d_flag_1_valid, d_flag_2_valid: std_logic;
	signal d_flag_0_data, d_flag_1_data, d_flag_2_data: std_logic_vector(0 downto 0); 
	signal d_flag_0_ready, d_flag_1_ready, d_flag_2_ready: std_logic;
	
	--repeaters
	signal d_flag_kj_ready, d_flag_ehat_ready, d_flag_kj_valid, d_flag_ehat_valid: std_logic;
	signal d_flag_kj_data, d_flag_ehat_data: std_logic_vector(0 downto 0);
	
	--filter to ehat
	signal ehat_filtered_valid, ehat_filtered_ready: std_logic;
	signal ehat_filtered_data: std_logic_vector(MAPPED_ERROR_WIDTH - 1 downto 0);
	--filter to kj 
	signal kj_filtered_valid, kj_filtered_ready: std_logic;
	signal kj_filtered_data: std_logic_vector(ACC_LOG - 1 downto 0);
	
	--separated ehat
	signal ehat_zero_valid, ehat_zero_ready, ehat_one_valid, ehat_one_ready: std_logic;
	signal ehat_zero_data, ehat_one_data: std_logic_vector(MAPPED_ERROR_WIDTH - 1 downto 0);
	
	--coding constants
	constant CODING_LENGTH_MAX: integer := MAPPED_ERROR_WIDTH*2+1;
	constant CODING_LENGTH_MAX_LOG: integer := bits(CODING_LENGTH_MAX);
	
	--exp zero golomb coder
	signal eg_code: std_logic_vector(CODING_LENGTH_MAX - 1 downto 0);
	signal eg_length: std_logic_vector(CODING_LENGTH_MAX_LOG - 1 downto 0);
	signal eg_valid, eg_ready: std_logic;
	
	--normal golomb
	signal golomb_code: std_logic_vector(CODING_LENGTH_MAX - 1 downto 0);
	signal golomb_length: std_logic_vector(CODING_LENGTH_MAX_LOG - 1 downto 0);
	signal golomb_valid, golomb_ready: std_logic;
	signal golomb_ends_input: std_logic;
	
	--trasher for merger
	signal merger_valid_pre, merger_ready_pre: std_logic;
	signal merger_data_pre: std_logic_vector(CODING_LENGTH_MAX + CODING_LENGTH_MAX_LOG - 1 downto 0);

	--alpha xmean stuff
	signal alpha_xmean_sync_valid, alpha_xmean_sync_ready: std_logic;
	signal alpha_xmean_sync_alpha: std_logic_vector(ALPHA_WIDTH-1 downto 0);
	signal alpha_xmean_sync_xmean: std_logic_vector(DATA_WIDTH-1 downto 0);
	signal alpha_xmean_data: std_logic_vector(ALPHA_WIDTH + DATA_WIDTH - 1 downto 0);

	--merger stuff
	signal merger_input_0, merger_input_1, merger_input_2, merger_input_3: std_logic_vector(CODING_LENGTH_MAX + CODING_LENGTH_MAX_LOG - 1 downto 0);
	signal merger_valid, merger_ready: std_logic;
	signal merger_input_2_last: std_logic;
	signal merger_data: std_logic_vector(CODING_LENGTH_MAX + CODING_LENGTH_MAX_LOG - 1 downto 0);
	signal merger_code: std_logic_vector(CODING_LENGTH_MAX - 1 downto 0);
	signal merger_length: std_logic_vector(CODING_LENGTH_MAX_LOG - 1 downto 0);
	
	--control signals
	signal counter_bitplane, counter_bitplane_next: natural range 0 to 2**BLOCK_SIZE_LOG - 1;
begin

	------CONTROL BEGIN---------
	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				counter_bitplane <= 0;
			else
				counter_bitplane <= counter_bitplane_next;
			end if;
		end if;	
	end process;
	
	comb: process(golomb_valid, golomb_ready, golomb_ends_input, counter_bitplane)
	begin
		counter_bitplane_next <= counter_bitplane;
		merger_input_2_last <= '0';

		if golomb_valid = '1' and golomb_ready = '1' and golomb_ends_input = '1' then
			if counter_bitplane = 2**BLOCK_SIZE_LOG - 2 then -- -2 since 1 goes through the normal coder
				counter_bitplane_next <= 0;
				merger_input_2_last <= '1';
			else
				counter_bitplane_next <= counter_bitplane + 1;
			end if;
		end if;
	end process;
	------CONTROL END-----------

	--D flag splitter (one for ehat control, one for kj control, one for output)
	d_flag_splitter: entity work.AXIS_SPLITTER_3 
		Generic map (
			DATA_WIDTH => 1
		)
		Port map (
			clk => clk, rst => rst,
			--to input axi port
			input_valid => d_flag_valid,
			input_data => d_flag_data,
			input_ready	=> d_flag_ready,
			--to output axi ports
			output_0_valid => d_flag_0_valid,
			output_0_data  => d_flag_0_data,
			output_0_ready => d_flag_0_ready,
			output_1_valid => d_flag_1_valid,
			output_1_data  => d_flag_1_data,
			output_1_ready => d_flag_1_ready,
			output_2_valid => d_flag_2_valid,
			output_2_data  => d_flag_2_data,
			output_2_ready => d_flag_2_ready
		);
		
	--repeater for KJ control
	kj_control_repeater: entity work.AXIS_DATA_REPEATER
		Generic map (
			DATA_WIDTH => 1,
			NUMBER_OF_REPETITIONS => 2**BLOCK_SIZE_LOG - 1
		)
		Port map (
			clk => clk, rst => rst,
			input_ready => d_flag_1_ready,
			input_valid => d_flag_1_valid,
			input_data  => d_flag_1_data,
			output_ready=> d_flag_kj_ready,
			output_valid=> d_flag_kj_valid,
			output_data => d_flag_kj_data
		);
	
	--repeater for ehat control
	ehat_control_repeater: entity work.AXIS_DATA_REPEATER
		Generic map (
			DATA_WIDTH => 1,
			NUMBER_OF_REPETITIONS => 2**BLOCK_SIZE_LOG
		)
		Port map (
			clk => clk, rst => rst,
			input_ready => d_flag_2_ready,
			input_valid => d_flag_2_valid,
			input_data  => d_flag_2_data,
			output_ready=> d_flag_ehat_ready,
			output_valid=> d_flag_ehat_valid,
			output_data => d_flag_ehat_data
		);
		
	--ehat_filter
	ehat_filter: entity work.AXIS_FILTER 
		Generic map (
			DATA_WIDTH => MAPPED_ERROR_WIDTH,
			ELIMINATE_ON_UP => false --0 is below threshold and does not code then
		)
		Port map (
			clk => clk, rst => rst,
			input_valid	=> ehat_valid,
			input_ready => ehat_ready,
			input_data	=> ehat_data,
			flag_valid	=> d_flag_ehat_valid,
			flag_ready	=> d_flag_ehat_ready,
			flag_data	=> d_flag_ehat_data,
			--to output axi ports
			output_valid=> ehat_filtered_valid,
			output_ready=> ehat_filtered_ready,
			output_data	=> ehat_filtered_data
		);
		
	--kj_filter
	kj_filter: entity work.AXIS_FILTER
		Generic map (
			DATA_WIDTH => ACC_LOG,
			ELIMINATE_ON_UP => false
		)
		Port map (
			clk => clk, rst => rst,
			input_valid	=> kj_valid,
			input_ready => kj_ready,
			input_data	=> kj_data,
			flag_valid	=> d_flag_kj_valid,
			flag_ready	=> d_flag_kj_ready,
			flag_data	=> d_flag_kj_data,
			--to output axi ports
			output_valid=> kj_filtered_valid,
			output_ready=> kj_filtered_ready,
			output_data	=> kj_filtered_data
		);
		
	--separator to exp golomb coder and golomb coder
	separator: entity work.AXIS_SEPARATOR 
		Generic map (
			DATA_WIDTH => MAPPED_ERROR_WIDTH,
			TO_PORT_ZERO => 1,
			TO_PORT_ONE => 2**BLOCK_SIZE_LOG - 1
		)
		Port map ( 
			clk => clk, rst => rst,
			--to input axi port
			input_valid	=> ehat_filtered_valid,
			input_ready => ehat_filtered_ready,
			input_data	=> ehat_filtered_data,
			--to output axi ports
			output_0_valid	=> ehat_zero_valid,
			output_0_ready	=> ehat_zero_ready,
			output_0_data	=> ehat_zero_data,
			output_1_valid	=> ehat_one_valid,
			output_1_ready	=> ehat_one_ready,
			output_1_data	=> ehat_one_data
		);
	
	--exp zero golomb coder
	exp_zero_coder: entity work.EXP_ZERO_GOLOMB		
		Generic map (
			DATA_WIDTH => MAPPED_ERROR_WIDTH
		)
		Port map (
			input_data	=> ehat_zero_data,
			input_valid => ehat_zero_valid,
			input_ready	=> ehat_zero_ready,
			output_code	  => eg_code,
			output_length => eg_length,
			output_valid  => eg_valid,
			output_ready  => eg_ready
		);
			
	--golomb coder
	golomb_coder: entity work.GOLOMB_CODING 
		Generic map (
			DATA_WIDTH => MAPPED_ERROR_WIDTH,
			MAX_PARAM_VALUE => MAPPED_ERROR_WIDTH,
			MAX_PARAM_VALUE_LOG => ACC_LOG,
			OUTPUT_WIDTH => CODING_LENGTH_MAX,
			SLACK_LOG => 4,
			MAX_1_OUT_LOG => 5
		)
		Port map (
			clk => clk, rst => rst,
			input_param_data  => kj_filtered_data,
			input_param_valid => kj_filtered_valid,
			input_param_ready => kj_filtered_ready,
			input_value_data  => ehat_one_data,
			input_value_valid => ehat_one_valid,
			input_value_ready => ehat_one_ready,
			output_code		  => golomb_code,
			output_length	  => golomb_length,
			output_ends_input => golomb_ends_input,
			output_valid	  => golomb_valid,
			output_ready	  => golomb_ready
		);

	--sync alpha and xmean
	alpha_xmean_sync: entity work.AXIS_SYNCHRONIZER_2
		generic map (
			DATA_WIDTH_0 => ALPHA_WIDTH,
			DATA_WIDTH_1 => DATA_WIDTH,
			LATCH	     => false
		)
		port map (
			clk => clk, rst => rst,
			--to input axi port
			input_0_valid => alpha_valid,
			input_0_ready => alpha_ready,
			input_0_data  => alpha_data,
			input_1_valid => xmean_valid,
			input_1_ready => xmean_ready, 
			input_1_data  => xmean_data,
			--to output axi ports
			output_valid  => alpha_xmean_sync_valid,
			output_ready  => alpha_xmean_sync_ready,
			output_data_0 => alpha_xmean_sync_alpha,
			output_data_1 => alpha_xmean_sync_xmean
		);

	alpha_xmean_data <= alpha_xmean_sync_alpha & alpha_xmean_sync_xmean;




	--merger for both coders
	merger_input_0 <= (CODING_LENGTH_MAX_LOG - 1 downto 1 => '0') & '1' & (CODING_LENGTH_MAX - 1 downto 1 => '0') & d_flag_0_data;
	merger_input_1 <= eg_length & eg_code;
	merger_input_2 <= golomb_length & golomb_code;
	merger_input_3 <= std_logic_vector(to_unsigned(26, CODING_LENGTH_MAX_LOG)) & (CODING_LENGTH_MAX - 1 downto alpha_xmean_data'high + 1 => '0') & alpha_xmean_data;
	merger: entity work.AXIS_MERGER 
		Generic map (
			DATA_WIDTH => CODING_LENGTH_MAX + CODING_LENGTH_MAX_LOG --space for both length and the bits themselves
		)
		Port map ( 
			clk => clk, rst => rst,
			--to input axi port
			input_0_valid	=> d_flag_0_valid,
			input_0_ready	=> d_flag_0_ready,
			input_0_data	=> merger_input_0,
			input_0_last 	=> '1',
			input_1_valid	=> eg_valid,
			input_1_ready	=> eg_ready,
			input_1_data	=> merger_input_1,
			input_1_last	=> '1',
			input_2_valid	=> golomb_valid,
			input_2_ready	=> golomb_ready,
			input_2_data    => merger_input_2,
			input_2_last	=> merger_input_2_last,
			input_3_valid	=> alpha_xmean_sync_valid,
			input_3_ready	=> alpha_xmean_sync_ready,
			input_3_data	=> merger_input_3,
			input_3_last	=> '1',
			--to output axi ports
			output_valid	=> merger_valid_pre,
			output_ready	=> merger_ready_pre,
			output_data		=> merger_data_pre
		);

	trasher: entity work.AXIS_TRASHER
		Generic map (
			DATA_WIDTH => CODING_LENGTH_MAX + CODING_LENGTH_MAX_LOG,
			INVALID_TRANSACTIONS => 1
		)
		Port map (
			clk => clk, rst => rst,
			input_ready  => merger_ready_pre,
			input_valid  => merger_valid_pre,
			input_data   => merger_data_pre,
			output_ready => merger_ready,
			output_valid => merger_valid,
			output_data  => merger_data
		);

	merger_code <= merger_data(CODING_LENGTH_MAX-1 downto 0);
	merger_length <= merger_data(merger_data'high downto merger_data'high-CODING_LENGTH_MAX_LOG + 1);

	packer: entity work.CODING_OUTPUT_PACKER
		Generic map (
			CODE_WIDTH => CODING_LENGTH_MAX,
			OUTPUT_WIDTH_LOG => OUTPUT_WIDTH_LOG
		)
		Port map (
			clk => clk, rst => rst,
			flush				=> flush,
			flushed				=> flushed,
			input_code_data		=> merger_code,
			input_length_data	=> merger_length,
			input_valid			=> merger_valid,
			input_ready			=> merger_ready,
			output_data			=> output_data,
			output_valid		=> output_valid,
			output_ready		=> output_ready
		);


end Behavioral;
