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
use work.data_types.all;
use IEEE.NUMERIC_STD.ALL;

entity CODER is
	Generic (
		MAPPED_ERROR_WIDTH: integer := 19;
		ACCUMULATOR_WINDOW: integer := 32;
		--ACC_LOG: integer := 5; change for the real stuff
		BLOCK_SIZE_LOG: integer := 8;
		OUTPUT_WIDTH_LOG: integer := 5;
		ALPHA_WIDTH: integer := 10;
		DATA_WIDTH: integer := 16
	);
	Port (
		clk, rst	: in 	std_logic;
		--EHAT INPUT: total of 2**BLOCK_SIZE_LOG per BAND
		--	first one is not a mapped error but a raw value that goes to the exp coder
		--	but comes here for ease of use
		ehat_data	: in	std_logic_vector(MAPPED_ERROR_WIDTH - 1 downto 0);
		ehat_ready	: out	std_logic;
		ehat_valid	: in 	std_logic;
		ehat_last_s : in 	std_logic; --last sample in slice
		ehat_last_b : in 	std_logic; --last sample in band
		ehat_last_i : in 	std_logic; --last sample in image (triggers inner buffer flush)
		--KJ INPUT: total of 2**BLOCK_SIZE_LOG - 1 per BAND
		--	one less is needed than EHAT since the first goes to EXP coder and does not need param kj
		kj_data		: in    std_logic_vector(bits(bits(ACCUMULATOR_WINDOW-1)+DATA_WIDTH) - 1 downto 0);
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
		--OUTPUT DATA (32 bit words straight to memory)
		output_data	: out	std_logic_vector(2**OUTPUT_WIDTH_LOG - 1 downto 0);
		output_valid: out	std_logic;
		output_ready: in 	std_logic;
		output_last	: out 	std_logic --triggers for ehat_last_i input
	);
end CODER;

architecture Behavioral of CODER is
	--coding constants
	constant CODING_LENGTH_MAX: integer := MAPPED_ERROR_WIDTH*2+1;
	constant CODING_LENGTH_MAX_LOG: integer := 6; --bits(CODING_LENGTH_MAX);
	constant KJ_WIDTH: integer := 5; --bits(bits(ACCUMULATOR_WINDOW-1)+DATA_WIDTH);
	
	--ehat_splitter
	signal ehat_splitter_input_data: std_logic_vector(MAPPED_ERROR_WIDTH + 2 downto 0);
	signal ehat_splitter_0_valid, ehat_splitter_0_ready, ehat_splitter_1_valid, ehat_splitter_1_ready: std_logic;
	signal ehat_splitter_0_data_full, ehat_splitter_1_data_full: std_logic_vector(MAPPED_ERROR_WIDTH + 2 downto 0);
	signal ehat_splitter_0_data, ehat_splitter_1_data: std_logic_vector(MAPPED_ERROR_WIDTH - 1 downto 0);
    signal ehat_splitter_0_last_i, ehat_splitter_0_last_b, ehat_splitter_0_last_s: std_logic;
	signal ehat_splitter_1_last_i, ehat_splitter_1_last_b, ehat_splitter_1_last_s: std_logic;
	signal ehat_splitter_1_last_s_stdlv: std_logic_vector(0 downto 0);
	

	--diverter signals
	signal diverter_input_data: std_logic_vector(MAPPED_ERROR_WIDTH + 2 downto 0);
	signal diverter_0_valid, diverter_1_valid, diverter_0_ready, diverter_1_ready: std_logic;
	signal diverter_0_data_full, diverter_1_data_full: std_logic_vector(MAPPED_ERROR_WIDTH + 2 downto 0);
	signal diverter_0_data, diverter_1_data: std_logic_vector(MAPPED_ERROR_WIDTH - 1 downto 0);
	signal diverter_0_last_s, diverter_0_last_b, diverter_0_last_i : std_logic;
	signal diverter_1_last_s, diverter_1_last_b, diverter_1_last_i : std_logic;

	--splitter signals
	signal d_flag_0_valid, d_flag_1_valid, d_flag_2_valid, d_flag_3_valid: std_logic;
	signal d_flag_0_data, d_flag_1_data, d_flag_2_data, d_flag_3_data: std_logic_vector(0 downto 0); 
	signal d_flag_0_ready, d_flag_1_ready, d_flag_2_ready, d_flag_3_ready: std_logic;

	--filter for golomb coder
	signal diverter_0_valid_filtered, diverter_0_ready_filtered: std_logic;
	signal diverter_0_data_filtered: std_logic_vector(MAPPED_ERROR_WIDTH - 1 downto 0);

	--exp zero golomb coder
	signal eg_code: std_logic_vector(CODING_LENGTH_MAX - 1 downto 0);
	signal eg_length: std_logic_vector(CODING_LENGTH_MAX_LOG - 1 downto 0);
	signal eg_valid, eg_ready: std_logic;

	--syncer for merr and kj
	signal sync_merr_kj_valid, sync_merr_kj_ready, sync_merr_kj_last: std_logic;
	signal sync_merr_kj_merr: std_logic_vector(MAPPED_ERROR_WIDTH - 1 downto 0);
	signal sync_merr_kj_kj: std_logic_vector(KJ_WIDTH - 1 downto 0);
	signal sync_merr_kj_data: std_logic_vector(MAPPED_ERROR_WIDTH + KJ_WIDTH - 1 downto 0);
	
	--golomb filter
	signal coder_filter_valid, coder_filter_ready, coder_filter_last: std_logic;
	signal coder_filter_data: std_logic_vector(MAPPED_ERROR_WIDTH + KJ_WIDTH - 1 downto 0);

	--normal golomb
	signal golomb_code: std_logic_vector(CODING_LENGTH_MAX - 1 downto 0);
	signal golomb_length: std_logic_vector(CODING_LENGTH_MAX_LOG - 1 downto 0);
	signal golomb_valid, golomb_ready, golomb_last: std_logic;
	
	--alpha xmean syncer
	signal sync_xmean_alpha_valid, sync_xmean_alpha_ready: std_logic;
	signal sync_xmean_alpha_xmean: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal sync_xmean_alpha_alpha: std_logic_vector(ALPHA_WIDTH - 1 downto 0);
	signal sync_xmean_alpha_data: std_logic_vector(DATA_WIDTH + ALPHA_WIDTH - 1 downto 0);
	
	--alpha xmean filtered
	signal xmean_alpha_valid, xmean_alpha_ready: std_logic;
	signal xmean_alpha_data: std_logic_vector(DATA_WIDTH + ALPHA_WIDTH - 1 downto 0);
	
	
	--------------
	--CONTROLLER--
	--------------
	type coder_ctrl_state_t is (IDLE, IDLE_FIRST, DISCARD_FLAG, OUTPUT_FLAG, OUTPUT_XMEAN_ALPHA, OUTPUT_EXP_GOL, OUTPUT_GOL);
	signal state_curr, state_next: coder_ctrl_state_t;
	
	--control signals
	signal control_input_data, control_output_data: std_logic_vector(1 downto 0); --2 flags
	signal control_ready, control_valid: std_logic;
	signal control_end_block, control_end_image: std_logic;
	
	--control signals buffer
	signal control_end_image_buff, control_end_image_buff_next, control_end_block_buff, control_end_block_buff_next: std_logic;
	
	--packer
	signal packer_valid, packer_ready, packer_last: std_logic;
	signal packer_code: std_logic_vector(CODING_LENGTH_MAX - 1 downto 0);
	signal packer_length: std_logic_vector(CODING_LENGTH_MAX_LOG - 1 downto 0);

begin
	ehat_splitter_input_data <= ehat_last_i & ehat_last_b & ehat_last_s & ehat_data;

	--ehat splitter into ehat and control
	ehat_splitter: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH => MAPPED_ERROR_WIDTH + 3
		)
		Port map (
			clk => clk, rst => rst,
			input_valid		=> ehat_valid,
			input_data		=> ehat_splitter_input_data,
			input_ready		=> ehat_ready,
			output_0_valid	=> ehat_splitter_0_valid,
			output_0_data	=> ehat_splitter_0_data_full,
			output_0_ready	=> ehat_splitter_0_ready,
			output_1_valid	=> ehat_splitter_1_valid,
			output_1_data	=> ehat_splitter_1_data_full,
			output_1_ready	=> ehat_splitter_1_ready
		);
	--0 goes to the diverter
	ehat_splitter_0_data   <= ehat_splitter_0_data_full(MAPPED_ERROR_WIDTH - 1 downto 0);
	ehat_splitter_0_last_i <= ehat_splitter_0_data_full(ehat_splitter_0_data_full'high-0);
	ehat_splitter_0_last_b <= ehat_splitter_0_data_full(ehat_splitter_0_data_full'high-1);
	ehat_splitter_0_last_s <= ehat_splitter_0_data_full(ehat_splitter_0_data_full'high-2);
	--1 goes to control
	ehat_splitter_1_data   <= ehat_splitter_1_data_full(MAPPED_ERROR_WIDTH - 1 downto 0);
	ehat_splitter_1_last_i <= ehat_splitter_1_data_full(ehat_splitter_1_data_full'high-0);
	ehat_splitter_1_last_b <= ehat_splitter_1_data_full(ehat_splitter_1_data_full'high-1);
	ehat_splitter_1_last_s <= ehat_splitter_1_data_full(ehat_splitter_1_data_full'high-2);

	diverter: entity work.AXIS_DIVERTER
		Generic map (
			DATA_WIDTH => MAPPED_ERROR_WIDTH + 3
		)
		Port map (
			clk => clk, rst => rst,
			input_valid		=> ehat_splitter_0_valid,
			input_ready		=> ehat_splitter_0_ready,
			input_data		=> ehat_splitter_0_data_full,
			input_last		=> ehat_splitter_0_last_s,
			--to output axi ports
			output_0_valid	=> diverter_0_valid,
			output_0_ready	=> diverter_0_ready,
			output_0_data	=> diverter_0_data_full,
			output_1_valid	=> diverter_1_valid,
			output_1_ready	=> diverter_1_ready,
			output_1_data	=> diverter_1_data_full
		);
	diverter_0_data   <= diverter_0_data_full(MAPPED_ERROR_WIDTH - 1 downto 0);
	diverter_0_last_i <= diverter_0_data_full(diverter_0_data_full'high-0);
	diverter_0_last_b <= diverter_0_data_full(diverter_0_data_full'high-1);
	diverter_0_last_s <= diverter_0_data_full(diverter_0_data_full'high-2);
	diverter_1_data   <= diverter_1_data_full(MAPPED_ERROR_WIDTH - 1 downto 0);
	diverter_1_last_i <= diverter_1_data_full(diverter_1_data_full'high-0);
	diverter_1_last_b <= diverter_1_data_full(diverter_1_data_full'high-1);
	diverter_1_last_s <= diverter_1_data_full(diverter_1_data_full'high-2);

	--D flag splitter (one for ehat control, one for kj control, one for output)
	d_flag_splitter: entity work.AXIS_SPLITTER_4
		Generic map (
			DATA_WIDTH => 1
		)
		Port map (
			clk => clk, rst => rst,
			--to input axi port
			input_valid => d_flag_valid,
			input_data  => d_flag_data,
			input_ready	=> d_flag_ready,
			input_last  => '0',
			--to output axi ports
			output_0_valid => d_flag_0_valid,
			output_0_data  => d_flag_0_data,
			output_0_ready => d_flag_0_ready,
			output_0_last  => open,
			output_1_valid => d_flag_1_valid,
			output_1_data  => d_flag_1_data,
			output_1_ready => d_flag_1_ready,
			output_1_last  => open,
			output_2_valid => d_flag_2_valid,
			output_2_data  => d_flag_2_data,
			output_2_ready => d_flag_2_ready,
			output_2_last  => open,
			output_3_valid => d_flag_3_valid,
			output_3_data  => d_flag_3_data,
			output_3_ready => d_flag_3_ready,
			output_3_last  => open
		);

	--exp golomb coder filter
	exp_golomb_coder_filter: entity work.AXIS_FILTER 
		Generic map (
			DATA_WIDTH => MAPPED_ERROR_WIDTH,
			ELIMINATE_ON_UP => false --0 is below threshold and does not code then
		)
		Port map (
			clk => clk, rst => rst,
			input_valid	=> diverter_0_valid,
			input_ready => diverter_0_ready,
			input_data	=> diverter_0_data,
			flag_valid	=> d_flag_0_valid,
			flag_ready	=> d_flag_0_ready,
			flag_data	=> d_flag_0_data,
			--to output axi ports
			output_valid=> diverter_0_valid_filtered,
			output_ready=> diverter_0_ready_filtered,
			output_data	=> diverter_0_data_filtered
		);

	--exp zero golomb coder
	exp_zero_coder: entity work.EXP_ZERO_GOLOMB		
		Generic map (
			DATA_WIDTH => MAPPED_ERROR_WIDTH
		)
		Port map (
			input_data	=> diverter_0_data_filtered,
			input_valid => diverter_0_valid_filtered,
			input_ready	=> diverter_0_ready_filtered,
			output_code	  => eg_code,
			output_length => eg_length,
			output_valid  => eg_valid,
			output_ready  => eg_ready
		);

	--merger of diverter_1 and kj for normal golomb coding
	sync_merr_kj: entity work.AXIS_SYNCHRONIZER_2 
		Generic map(
			DATA_WIDTH_0 => MAPPED_ERROR_WIDTH,
			DATA_WIDTH_1 => KJ_WIDTH,
			LATCH => true,
			LAST_POLICY => PASS_ZERO
		)
		Port map (
			clk => clk, rst => rst,
			--to input axi port
			input_0_valid => diverter_1_valid,
			input_0_ready => diverter_1_ready,
			input_0_data  => diverter_1_data,
			input_0_last  => diverter_1_last_s,
			input_1_valid => kj_valid,
			input_1_ready => kj_ready, 
			input_1_data  => kj_data,
			input_1_last  => '0',
			--to output axi ports
			output_valid  => sync_merr_kj_valid,
			output_ready  => sync_merr_kj_ready,
			output_data_0 => sync_merr_kj_merr,
			output_data_1 => sync_merr_kj_kj,
			output_last	  => sync_merr_kj_last
		);
	sync_merr_kj_data <= sync_merr_kj_merr & sync_merr_kj_kj;

	--filter to normal coder
	coder_batch_filter: entity work.AXIS_BATCH_FILTER
		Generic map (
			DATA_WIDTH => KJ_WIDTH + MAPPED_ERROR_WIDTH,
			ELIMINATE_ON_UP => false
		)
		Port map (
			clk => clk, rst => rst,
			input_valid		=> sync_merr_kj_valid,
			input_ready		=> sync_merr_kj_ready,
			input_data		=> sync_merr_kj_data,
			input_last		=> sync_merr_kj_last,
			flag_valid		=> d_flag_1_valid,
			flag_ready		=> d_flag_1_ready,
			flag_data		=> d_flag_1_data,
			output_valid	=> coder_filter_valid,
			output_ready	=> coder_filter_ready,
			output_data		=> coder_filter_data,
			output_last		=> coder_filter_last
		);

	--golomb coder
	golomb_coder: entity work.GOLOMB_CODING 
		Generic map (
			DATA_WIDTH => MAPPED_ERROR_WIDTH,
			MAX_PARAM_VALUE => KJ_WIDTH + DATA_WIDTH, --bits(ACCUMULATOR_WINDOW-1)+DATA_WIDTH ??
			MAX_PARAM_VALUE_LOG => KJ_WIDTH,
			OUTPUT_WIDTH => CODING_LENGTH_MAX,
			SLACK_LOG => 4,
			MAX_1_OUT_LOG => 5,
			LAST_POLICY => AND_ALL
		)
		Port map (
			clk => clk, rst => rst,
			input_param_data  => coder_filter_data(coder_filter_data'high downto coder_filter_data'high - KJ_WIDTH + 1),
			input_param_valid => coder_filter_valid,
			input_param_ready => coder_filter_ready,
			input_param_last  => coder_filter_last,
			input_value_data  => coder_filter_data(MAPPED_ERROR_WIDTH - 1 downto 0),
			input_value_valid => coder_filter_valid,
			input_value_ready => open,
			input_value_last  => coder_filter_last,
			output_code		  => golomb_code,
			output_length	  => golomb_length,
			output_last       => golomb_last,
			output_valid	  => golomb_valid,
			output_ready	  => golomb_ready
		);

	--merger of mean and alpha
	sync_xmean_alpha: entity work.AXIS_SYNCHRONIZER_2 
		Generic map(
			DATA_WIDTH_0 => DATA_WIDTH,
			DATA_WIDTH_1 => ALPHA_WIDTH,
			LATCH => true,
			LAST_POLICY => PASS_ZERO
		)
		Port map (
			clk => clk, rst => rst,
			--to input axi port
			input_0_valid => xmean_valid,
			input_0_ready => xmean_ready,
			input_0_data  => xmean_data,
			input_0_last  => '0',
			input_1_valid => alpha_valid,
			input_1_ready => alpha_ready, 
			input_1_data  => alpha_data,
			input_1_last  => '0',
			--to output axi ports
			output_valid  => sync_xmean_alpha_valid,
			output_ready  => sync_xmean_alpha_ready,
			output_data_0 => sync_xmean_alpha_xmean,
			output_data_1 => sync_xmean_alpha_alpha,
			output_last	  => open
		);
	sync_xmean_alpha_data <= sync_xmean_alpha_xmean & sync_xmean_alpha_alpha;

	--xmean_alpha_filter
	xmean_alpha_filter: entity work.AXIS_FILTER 
		Generic map (
			DATA_WIDTH => DATA_WIDTH + ALPHA_WIDTH,
			ELIMINATE_ON_UP => false --0 is below threshold and does not code then
		)
		Port map (
			clk => clk, rst => rst,
			input_valid	=> sync_xmean_alpha_valid,
			input_ready => sync_xmean_alpha_ready,
			input_data	=> sync_xmean_alpha_data,
			flag_valid	=> d_flag_2_valid,
			flag_ready	=> d_flag_2_ready,
			flag_data	=> d_flag_2_data,
			--to output axi ports
			output_valid=> xmean_alpha_valid,
			output_ready=> xmean_alpha_ready,
			output_data	=> xmean_alpha_data
		);

	---------------
	--  CONTROL  --
	---------------
	control_input_data <= ehat_splitter_1_last_i & ehat_splitter_1_last_b;
	ehat_splitter_1_last_s_stdlv <= "1" when ehat_splitter_1_last_s = '1' else "0";
	control_filter: entity work.AXIS_FILTER
		Generic map (
			DATA_WIDTH => 2,
			ELIMINATE_ON_UP => false
		)
		Port map (
			clk => clk, rst => rst,
			input_valid		=> ehat_splitter_1_valid,
			input_ready		=> ehat_splitter_1_ready,
			input_data		=> control_input_data,
			flag_valid		=> ehat_splitter_1_valid,
			flag_ready		=> open,
			flag_data		=> ehat_splitter_1_last_s_stdlv,
			--to output axi ports
			output_valid	=> control_valid,
			output_ready	=> control_ready,
			output_data		=> control_output_data
		);
	control_end_image <= control_output_data(1);
	control_end_block <= control_output_data(0);

	seq : process (rst, clk)
	begin
		if (rising_edge(clk)) then
			if rst = '1' then
				state_curr <= IDLE;
				control_end_image_buff <= '0';
				control_end_block_buff <= '0';
			else
				state_curr <= state_next;
				control_end_image_buff <= control_end_image_buff_next;
				control_end_block_buff <= control_end_block_buff_next;
			end if;
		end if;
	end process;


	comb: process (state_curr, control_valid, control_end_block, control_end_image, 
		packer_ready, control_end_image_buff, control_end_block_buff,
		eg_valid, eg_code, eg_length, golomb_valid, golomb_code, golomb_length, golomb_last,
		d_flag_3_valid, d_flag_3_data, xmean_alpha_valid, xmean_alpha_data)
	begin
		state_next    <= state_curr;
		control_ready <= '0';
		--bufs
		control_end_block_buff_next <= control_end_block;
		control_end_image_buff_next <= control_end_image;
		--internal components
		eg_ready      <= '0';
		d_flag_3_ready<= '0';
		xmean_alpha_ready <= '0';
		golomb_ready  <= '0';
		--packer
		packer_valid  <= '0';
		packer_code   <= (others => '0');
		packer_length <= (others => '0');
		packer_last   <= '0';


		if state_curr = IDLE_FIRST then
			control_ready <= '1';
			if control_valid = '1' then
				control_end_block_buff_next <= control_end_block;
				control_end_image_buff_next <= control_end_image;
				state_next <= DISCARD_FLAG;
			end if;
		elsif state_curr = DISCARD_FLAG then
			d_flag_3_ready <= '1';
			if d_flag_3_valid = '1' then
				state_next <= OUTPUT_EXP_GOL;
			end if;
		elsif state_curr =  IDLE then
			control_ready <= '1';
			if control_valid = '1' then
				control_end_block_buff_next <= control_end_block;
				control_end_image_buff_next <= control_end_image;
				state_next <= OUTPUT_FLAG;
			end if;
		elsif state_curr = OUTPUT_FLAG then
			d_flag_3_ready <= packer_ready;
			packer_valid <= d_flag_3_valid;
			packer_code  <= (CODING_LENGTH_MAX - 1 downto 1 => '0') & d_flag_3_data;
			packer_length<= std_logic_vector(to_unsigned(1, packer_length'length));
			if d_flag_3_valid = '1' and packer_ready = '1' then
				state_next <= OUTPUT_XMEAN_ALPHA;
			end if;
		elsif state_curr = OUTPUT_XMEAN_ALPHA then
			xmean_alpha_ready <= packer_ready;
			packer_valid <= xmean_alpha_valid;
			packer_code  <= (CODING_LENGTH_MAX - 1 downto xmean_alpha_data'high + 1 => '0') & xmean_alpha_data;
			packer_length<= std_logic_vector(to_unsigned(DATA_WIDTH + ALPHA_WIDTH, packer_length'length));
			if xmean_alpha_valid = '1' and packer_ready = '1' then
				state_next <= OUTPUT_EXP_GOL;
			end if;
		elsif state_curr = OUTPUT_EXP_GOL then
			eg_ready     <= packer_ready;
			packer_valid <= eg_valid;
			packer_code  <= eg_code;
			packer_length<= eg_length;
			if eg_valid = '1' and packer_ready = '1' then
				state_next <= OUTPUT_GOL;
			end if;
		elsif state_curr = OUTPUT_GOL then
			golomb_ready <= packer_ready;
			packer_valid <= golomb_valid;
			packer_code  <= golomb_code;
			packer_length<= golomb_length;
			if golomb_last = '1' and control_end_image_buff = '1' then
				packer_last  <= '1';
			end if;
			if golomb_valid = '1' and packer_ready = '1' then
				if golomb_last = '1' then
					if control_end_block_buff = '1' then
						state_next <= IDLE_FIRST;
					else
						state_next <= IDLE;
					end if;
				end if;
			end if;
		end if;
	end process;

	packer: entity work.CODING_OUTPUT_PACKER
		Generic map (
			CODE_WIDTH => CODING_LENGTH_MAX,
			OUTPUT_WIDTH_LOG => OUTPUT_WIDTH_LOG
		)
		Port map (
			clk => clk, rst => rst,
			input_code_data		=> packer_code,
			input_length_data	=> packer_length,
			input_valid			=> packer_valid,
			input_ready			=> packer_ready,
			input_last 			=> packer_last,
			output_data			=> output_data,
			output_valid		=> output_valid,
			output_ready		=> output_ready,
			output_last 		=> output_last
		);
		


end Behavioral;
