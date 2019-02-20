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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity CODER is
	Generic (
		MAPPED_ERROR_WIDTH: integer := 19;
		ACC_LOG: integer := 5;
		BLOCK_SIZE_LOG: integer := 8;
		OUTPUT_WIDTH_LOG: integer := 5
	);
	Port (
		clk, rst	: in 	std_logic;
		--inputs
		ehat_data	: in	std_logic_vector(MAPPED_ERROR_WIDTH - 1 downto 0);
		ehat_ready	: out	std_logic;
		ehat_valid	: in 	std_logic;
		kj_data		: in 	std_logic_vector(ACC_LOG - 1 downto 0);
		kj_ready	: out	std_logic;
		kj_valid	: in 	std_logic;
		d_flag_data	: in	std_logic_vector(0 downto 0);
		d_flag_ready: out	std_logic;
		d_flag_valid: in 	std_logic;
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
	
	--d flag limiter
	signal flag_lim_clear, flag_lim_saturated, flag_valid_lim, flag_ready_lim: std_logic;
	
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
	
	--limiter to exp golomb coder	
	signal exp_golomb_limiter_clear, exp_golomb_limiter_saturated: std_logic;
	signal ehat_zero_valid_lim, ehat_zero_ready_lim: std_logic;
	
	--coding constants
	constant CODING_LENGTH_MAX: integer := MAPPED_ERROR_WIDTH*2+1;
	constant CODING_LENGTH_MAX_LOG: integer := bits(CODING_LENGTH_MAX);
	
	--exp zero golomb coder
	signal eg_code: std_logic_vector(CODING_LENGTH_MAX - 1 downto 0);
	signal eg_length: natural range 0 to CODING_LENGTH_MAX;
	signal eg_valid, eg_ready: std_logic;
	
	--normal golomb
	signal golomb_code: std_logic_vector(CODING_LENGTH_MAX - 1 downto 0);
	signal golomb_length: natural range 0 to CODING_LENGTH_MAX;
	signal golomb_valid, golomb_ready: std_logic;
	
	--limiter after e0 golomb coder
	signal exp_golomb_output_limiter_clear, exp_golomb_output_limiter_saturated: std_logic;
	signal eg_valid_lim, eg_ready_lim: std_logic;
	
	--limiter to golomb coder	
	signal golomb_limiter_clear, golomb_limiter_saturated: std_logic;
	signal ehat_one_valid_lim, ehat_one_ready_lim: std_logic;
	
	--merger stuff
	signal merger_input_0, merger_input_1, merger_input_2: std_logic_vector(CODING_LENGTH_MAX + CODING_LENGTH_MAX_LOG - 1 downto 0);
	signal merger_clear: std_logic;
	signal merger_valid, merger_ready: std_logic;
	signal merger_data: std_logic_vector(CODING_LENGTH_MAX + CODING_LENGTH_MAX_LOG - 1 downto 0);
	signal merger_code: std_logic_vector(CODING_LENGTH_MAX - 1 downto 0);
	signal merger_length: natural range 0 to CODING_LENGTH_MAX;
	
	--packer stuff
	signal packer_flush, packer_flushed: std_logic;
	
	--control signals
	type coder_control_t is (AWAIT_SATURATION, FLUSHING);
	signal state_curr, state_next: coder_control_t;
begin

	------CONTROL BEGIN---------
	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= AWAIT_SATURATION;
			else
				state_curr <= state_next;
			end if;
		end if;	
	end process;
	

	
	comb: process(state_curr, exp_golomb_limiter_saturated, exp_golomb_output_limiter_saturated, golomb_limiter_saturated, flag_lim_saturated, packer_flushed)
	begin
		state_next <= state_curr;
		packer_flush <= '1';
		exp_golomb_limiter_clear <= '0';
		exp_golomb_output_limiter_clear <= '0';
		golomb_limiter_clear <= '0';
		flag_lim_clear <= '0';
		merger_clear <= '0';
		
		if state_curr = AWAIT_SATURATION then
			--data went to exp zero golomb coder
			if exp_golomb_limiter_saturated = '1' and flag_lim_saturated = '1' and exp_golomb_output_limiter_saturated = '1' and golomb_limiter_saturated = '1' then
				state_next <= FLUSHING;
			end if;
		elsif state_curr = FLUSHING then
			packer_flush <= '1';
			if packer_flushed = '1' then
				--reset all limiters
				state_next <= AWAIT_SATURATION;
				exp_golomb_limiter_clear <= '1';
				exp_golomb_output_limiter_clear <= '1';
				golomb_limiter_clear <= '1';
				merger_clear <= '1';
				flag_lim_clear <= '1';
			end if;
		end if;
	end process;
	------CONTROL END-----------

	--D flag splitter (one for ehat control, one for kj control, one for output)
	d_flag_splitter: entity work.SPLITTER_AXI_3 
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
		
	--D flag limiter for output
	d_flag_limiter: entity work.TRANSACTION_LIMITER
		Generic map (
			DATA_WIDTH => 1,
			NUMBER_OF_TRANSACTIONS => 1
		)
		Port map (
			clk => clk, rst => rst,
			clear => flag_lim_clear,
			saturated => flag_lim_saturated,
			input_valid => d_flag_0_valid,
			input_ready => d_flag_0_ready,
			output_valid => flag_valid_lim,
			output_ready => flag_ready_lim
		);
		
	--repeater for KJ control
	kj_control_repeater: entity work.DATA_REPEATER_AXI
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
	ehat_control_repeater: entity work.DATA_REPEATER_AXI
		Generic map (
			DATA_WIDTH => 1,
			NUMBER_OF_REPETITIONS => 2**BLOCK_SIZE_LOG - 1
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
	ehat_filter: entity work.FILTER_AXI 
		Generic map (
			DATA_WIDTH => MAPPED_ERROR_WIDTH,
			FILTER_ON_UP => false --0 is below threshold and does not code then
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
	kj_filter: entity work.FILTER_AXI
		Generic map (
			DATA_WIDTH => ACC_LOG,
			FILTER_ON_UP => false
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
	separator: entity work.SEPARATOR_AXI 
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
			output_valid_0	=> ehat_zero_valid,
			output_ready_0	=> ehat_zero_ready,
			output_data_0	=> ehat_zero_data,
			output_valid_1	=> ehat_one_valid,
			output_ready_1	=> ehat_one_ready,
			output_data_1	=> ehat_one_data
		);
		
	--limiter to exp golomb coder
	limiter_to_exp_golomb: entity work.TRANSACTION_LIMITER
			Generic map (
				DATA_WIDTH => MAPPED_ERROR_WIDTH,
				NUMBER_OF_TRANSACTIONS => 1
			)
			Port map (
				clk => clk, rst => rst,
				clear => exp_golomb_limiter_clear,
				saturated => exp_golomb_limiter_saturated,
				input_valid => ehat_zero_valid,
				input_ready => ehat_zero_ready,
				output_valid => ehat_zero_valid_lim,
				output_ready => ehat_zero_ready_lim
			);
	
	--exp zero golomb coder
	exp_zero_coder: entity work.EXP_ZERO_GOLOMB		
		Generic map (
			DATA_WIDTH => MAPPED_ERROR_WIDTH
		)
		Port map (
			input_data	=> ehat_zero_data,
			input_valid => ehat_zero_valid_lim,
			input_ready	=> ehat_zero_ready_lim,
			output_code	  => eg_code,
			output_length => eg_length,
			output_valid  => eg_valid,
			output_ready  => eg_ready
		);
		
		
	--limiter after exp zero
	limiter_after_exp_zero: entity work.TRANSACTION_LIMITER
		Generic map (
			DATA_WIDTH => MAPPED_ERROR_WIDTH,
			NUMBER_OF_TRANSACTIONS => 1
		)
		Port map (
			clk => clk, rst => rst,
			clear => exp_golomb_output_limiter_clear,
			saturated => exp_golomb_output_limiter_saturated,
			input_valid => eg_valid,
			input_ready => eg_ready,
			output_valid => eg_valid_lim,
			output_ready => eg_ready_lim
		);
		
	--limiter to golomb coder
	limiter_to_golomb: entity work.TRANSACTION_LIMITER
		Generic map (
			DATA_WIDTH => MAPPED_ERROR_WIDTH,
			NUMBER_OF_TRANSACTIONS => 1
		)
		Port map (
			clk => clk, rst => rst,
			clear => golomb_limiter_clear,
			saturated => golomb_limiter_saturated,
			input_valid => ehat_one_valid,
			input_ready => ehat_one_ready,
			output_valid => ehat_one_valid_lim,
			output_ready => ehat_one_ready_lim
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
			input_value_valid => ehat_one_valid_lim,
			input_value_ready => ehat_one_ready_lim,
			output_code		  => golomb_code,
			output_length	  => golomb_length,
			output_valid	  => golomb_valid,
			output_ready	  => golomb_ready
		);


	--merger for both coders
	merger_input_0 <= (CODING_LENGTH_MAX_LOG - 1 downto 1 => '0') & '1' & (CODING_LENGTH_MAX - 1 downto 1 => '0') & d_flag_0_data;
	merger_input_1 <= std_logic_vector(to_unsigned(eg_length, CODING_LENGTH_MAX_LOG)) & eg_code;
	merger_input_2 <= std_logic_vector(to_unsigned(golomb_length, CODING_LENGTH_MAX_LOG)) & golomb_code;
	merger: entity work.MERGER_AXI 
		Generic map (
			DATA_WIDTH => CODING_LENGTH_MAX + CODING_LENGTH_MAX_LOG, --space for both length and the bits themselves
			FROM_PORT_ZERO => 1 --one from exp coder, the rest from the golomb coder
		)
		Port map ( 
			clk => clk, rst => rst,
			clear => merger_clear,
			--to input axi port
			input_valid_0	=> flag_valid_lim,
			input_ready_0	=> flag_ready_lim,
			input_data_0	=> merger_input_0,
			input_valid_1	=> eg_valid_lim,
			input_ready_1	=> eg_ready_lim,
			input_data_1	=> merger_input_1,
			input_valid_2	=> golomb_valid,
			input_ready_2	=> golomb_ready,
			input_data_2    => merger_input_2,
			--to output axi ports
			output_valid	=> merger_valid,
			output_ready	=> merger_ready,
			output_data		=> merger_data
		);
	merger_code <= merger_data(CODING_LENGTH_MAX-1 downto 0);
	merger_length <= to_integer(unsigned(merger_data(merger_data'high downto merger_data'high-CODING_LENGTH_MAX_LOG + 1)));
		
	packer: entity work.CODING_OUTPUT_PACKER
		Generic map (
			CODE_WIDTH => CODING_LENGTH_MAX,
			OUTPUT_WIDTH_LOG => OUTPUT_WIDTH_LOG
		)
		Port map (
			clk => clk, rst => rst,
			flush				=> packer_flush,
			flushed				=> packer_flushed,
			input_code_data		=> merger_code,
			input_length_data	=> merger_length,
			input_valid			=> merger_valid,
			input_ready			=> merger_ready,
			output_data			=> output_data,
			output_valid		=> output_valid,
			output_ready		=> output_ready
		);


end Behavioral;
