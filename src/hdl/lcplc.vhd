----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 21.02.2019 12:08:17
-- Design Name: 
-- Module Name: LCPLC - Behavioral
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
use work.am_data_types.all;

entity LCPLC is
	Generic (
		--configure input data width
		DATA_WIDTH: integer := 16;
		--configure output data width
		WORD_WIDTH_LOG: integer := 5;
		--configure max slice size 
		--the max slice size accepted is 2**MAX_SLICE_SIZE_LOG
		MAX_SLICE_SIZE_LOG: integer := 10;  --4,6,8,10,12
		--width of the alpha value. This can increase accuracy in prediction
		ALPHA_WIDTH: integer := 10;
		--window with which predictions are made. Smaller windows adapt better to fast changes, while 
		--bigger windows are better for smoother images
		ACCUMULATOR_WINDOW: integer := 32;
		--quantizer shift. With every shift, a bit is lost so that compression is better
		--but accuracy is lower
		QUANTIZER_SHIFT_WIDTH: integer := 4
	);
	Port (
		clk, rst		: in	std_logic;
		x_valid			: in 	std_logic;
		x_ready			: out 	std_logic;
		x_data			: in  	std_logic_vector(DATA_WIDTH - 1 downto 0);
		x_last_r		: in	std_logic; --1 when the sample is the last of its row
		x_last_s		: in 	std_logic; --1 when the sample is the last of its slice (implies r)
		x_last_b		: in 	std_logic; --1 when the sample is the last of its block (implies s,r)
		x_last_i		: in 	std_logic; --1 when the sample is the last of its image (implies b,s,r)
		output_data		: out 	std_logic_vector(2**WORD_WIDTH_LOG - 1 downto 0);
		output_ready	: in	std_logic;
		output_valid	: out	std_logic;
		output_last		: out 	std_logic;
		--config
		--threshold for compression. If distortion is greater than this threshold for a certain slice,
		--the slice is compressed. Otherwise the slice is skipped. Set to zero for lossless compression.
		cfg_quant_shift	: in  std_logic_vector(QUANTIZER_SHIFT_WIDTH - 1 downto 0);
		cfg_threshold	: in  std_logic_vector((DATA_WIDTH + 3)*2 + MAX_SLICE_SIZE_LOG - 1 downto 0)
	);
end LCPLC;

architecture Behavioral of LCPLC is
	constant PREDICTION_WIDTH: integer := DATA_WIDTH + 3;

	--input separator signals
	signal x_flags_data, x_0_flags_data, x_1_flags_data, x_2_flags_data, x_3_flags_data: std_logic_vector(DATA_WIDTH + 4 - 1 downto 0);
	signal x_0_last_b, x_0_last_s, x_1_last_i, x_1_last_b, x_1_last_s, x_1_last_r, x_3_last_s, x_3_last_b: std_logic;
	signal x_0_valid, x_0_ready, x_1_valid, x_1_ready, x_2_valid, x_2_ready, x_3_valid, x_3_ready: std_logic;
	signal x_1_data, x_3_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal x_1_flags_bs_data: std_logic_vector(DATA_WIDTH + 2 downto 0);
	signal x_2_last_bs: std_logic_vector(1 downto 0);
	signal x_2_valid_and_last_s: std_logic;

	--input bs split
	signal x_2_0_valid, x_2_0_ready, x_2_1_valid, x_2_1_ready, x_2_2_valid, x_2_2_ready, x_2_3_valid, x_2_3_ready: std_logic;
	signal x_2_0_last_b_stdlv, x_2_1_last_b_stdlv, x_2_2_last_b_stdlv, x_2_3_last_b_stdlv: std_logic_vector(0 downto 0);
	alias x_2_0_last_b: std_logic is x_2_0_last_b_stdlv(0);
	alias x_2_1_last_b: std_logic is x_2_1_last_b_stdlv(0);
	alias x_2_2_last_b: std_logic is x_2_2_last_b_stdlv(0);
	alias x_2_3_last_b: std_logic is x_2_3_last_b_stdlv(0);

	--mean calc
	signal xmean_pre_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xmean_pre_valid, xmean_pre_ready: std_logic;

	--mean calc
	signal xmean_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xmean_valid, xmean_ready: std_logic;
	signal xmean_last_stdlv: std_logic_vector(0 downto 0);
	signal xmean_last: std_logic;

	--mean splitter (1 coder, 1 to remove first, 1 to remove last)
	signal xmean_0_valid, xmean_0_ready, xmean_1_valid, xmean_1_ready, xmean_2_valid, xmean_2_ready: std_logic;
	signal xmean_0_data, xmean_1_data, xmean_2_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xmean_0_last, xmean_1_last: std_logic; 
	signal xmean_1_last_stdlv: std_logic_vector(0 downto 0);

	--xmean filtered
	signal xmean_nonfirst_valid, xmean_nonfirst_ready: std_logic;
	signal xmean_nonfirst_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xmean_nonlast_valid, xmean_nonlast_ready: std_logic;
	signal xmean_nonlast_data: std_logic_vector(DATA_WIDTH - 1 downto 0);

	--xmean filtered splitters
	signal xmean_nonfirst_0_valid, xmean_nonfirst_0_ready, xmean_nonfirst_1_valid, xmean_nonfirst_1_ready, xmean_nonfirst_2_valid, xmean_nonfirst_2_ready: std_logic;
	signal xmean_nonfirst_0_data, xmean_nonfirst_1_data, xmean_nonfirst_2_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xmean_nonlast_0_valid, xmean_nonlast_0_ready, xmean_nonlast_1_valid, xmean_nonlast_1_ready,  xmean_nonlast_2_valid, xmean_nonlast_2_ready: std_logic;
	signal xmean_nonlast_0_data, xmean_nonlast_1_data, xmean_nonlast_2_data: std_logic_vector(DATA_WIDTH - 1 downto 0);

	--diverter for first band/rest
	signal x_0_red_flags_data: std_logic_vector(DATA_WIDTH + 4 - 1 downto 0);
	signal x_0_red_ready, x_0_red_valid: std_logic;
	signal x_0_red_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal x_0_red_last_r, x_0_red_last_s: std_logic;

	signal x_1_red_flags_data: std_logic_vector(DATA_WIDTH + 4 - 1 downto 0);
	signal x_1_red_ready, x_1_red_valid: std_logic;
	signal x_1_red_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal x_1_red_last_s, x_1_red_last_b: std_logic;
	signal x_1_red_last_b_stdlv: std_logic_vector(0 downto 0);
	
	--prediction first band
	signal prediction_first_pre_ready, prediction_first_pre_valid: std_logic;
	signal prediction_first_pre_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	signal prediction_first_pre_data_raw: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal prediction_first_pre_last: std_logic;
	signal prediction_first_pre_last_data: std_logic_vector(PREDICTION_WIDTH downto 0);

	--fifo after first prediction
	signal prediction_first_ready, prediction_first_valid: std_logic;
	signal prediction_first_last_data: std_logic_vector(PREDICTION_WIDTH downto 0);
	alias  prediction_first_last: std_logic is prediction_first_last_data(prediction_first_last_data'high);
	alias  prediction_first_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0) is prediction_first_last_data(PREDICTION_WIDTH - 1 downto 0);
	
	--splitter for reduced stuff
	signal x_others_1_valid, x_others_1_ready: std_logic;
	signal x_others_1_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal x_others_2_valid, x_others_2_ready: std_logic;
	signal x_others_2_last_b_stdlv: std_logic_vector(0 downto 0);
	
	--fifo delay for x values
	signal x_delay_ready, x_delay_valid: std_logic;
	signal x_delay_data: std_logic_vector(DATA_WIDTH - 1 downto 0);

	--splitter after fifo for both alpha modules
	signal x_delay_0_valid, x_delay_0_ready, x_delay_1_valid, x_delay_1_ready: std_logic;
	signal x_delay_0_data,  x_delay_1_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--fifo delay for nth band prediction
	signal x_delay_delay_ready, x_delay_delay_valid: std_logic;
	signal x_delay_delay_flags_data: std_logic_vector(DATA_WIDTH + 2 downto 0);
	alias  x_delay_delay_data: std_logic_vector(DATA_WIDTH - 1 downto 0) is x_delay_delay_flags_data(DATA_WIDTH - 1 downto 0);
	alias  x_delay_delay_last_s: std_logic is x_delay_delay_flags_data(DATA_WIDTH);
	alias  x_delay_delay_last_b: std_logic is x_delay_delay_flags_data(DATA_WIDTH + 1);
	alias  x_delay_delay_last_i: std_logic is x_delay_delay_flags_data(DATA_WIDTH + 2);

	--precalculated alphas
	signal alpha_xhat_data, alpha_xtilde_data: std_logic_vector(ALPHA_WIDTH - 1 downto 0);
	signal alpha_xhat_ready, alpha_xhat_valid, alpha_xtilde_ready, alpha_xtilde_valid: std_logic;

	--alpha result
	signal alpha_ready, alpha_valid: std_logic;
	signal alpha_data: std_logic_vector(ALPHA_WIDTH - 1 downto 0);
	
	--alpha splitter
	signal alpha_0_ready, alpha_0_valid: std_logic;
	signal alpha_0_data: std_logic_vector(ALPHA_WIDTH - 1 downto 0);
	signal alpha_1_ready, alpha_1_valid: std_logic;
	signal alpha_1_data: std_logic_vector(ALPHA_WIDTH - 1 downto 0);
	
	--prediction other bands
	signal prediction_rest_ready, prediction_rest_valid, prediction_rest_last: std_logic;
	signal prediction_rest_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	
	--b flag that goes to the prediction junnction merger
	signal delayed_last_b_ready, delayed_last_b_valid: std_logic;
	signal delayed_last_b_stdlv: std_logic_vector(0 downto 0);
	
	--sync with b flag
	signal prediction_rest_bsync_valid, prediction_rest_bsync_ready: std_logic;
	signal prediction_rest_bsync_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	signal prediction_rest_bsync_last_b_stdlv: std_logic_vector(0 downto 0);
	signal prediction_rest_bsync_last_s: std_logic;
	
	--prediction junction
	signal prediction_valid, prediction_ready, prediction_last: std_logic;
	signal prediction_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	
	--error calc
	signal merr_ready		: std_logic;
	signal merr_valid		: std_logic;
	signal merr_last_s		: std_logic;
	signal merr_last_b		: std_logic;     
	signal merr_last_i      : std_logic;
	signal merr_data		: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	signal merr_last_data	: std_logic_vector(PREDICTION_WIDTH + 3 - 1 downto 0);
	signal kj_ready			: std_logic;
	signal kj_valid			: std_logic;
	signal kj_data			: std_logic_vector(WORD_WIDTH_LOG - 1 downto 0);
	signal xtilde_pre_valid, xtilde_valid		: std_logic;
	signal xtilde_pre_ready, xtilde_ready		: std_logic;
	signal xtilde_pre_last_s,xtilde_last_s		: std_logic;
	signal xtilde_pre_data,  xtilde_data		: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xtilde_pre_last_data: std_logic_vector(DATA_WIDTH downto 0);
	signal xhat_pre_valid,   xhat_valid			: std_logic;
	signal xhat_pre_ready,   xhat_ready			: std_logic;
	signal xhat_pre_last_s,  xhat_last_s		: std_logic;
	signal xhat_pre_last_b,  xhat_last_b		: std_logic;
	signal xhat_pre_data, 	 xhat_data			: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal d_flag_valid		: std_logic;
	signal d_flag_ready		: std_logic;
	signal d_flag_data 		: std_logic;

	--xtilde delayer
	signal xtilde_pre_buf_valid, xtilde_pre_buf_ready: std_logic;
	signal xtilde_pre_buf_last_data: std_logic_vector(DATA_WIDTH downto 0);
	alias  xtilde_pre_buf_data: std_logic_vector(DATA_WIDTH - 1 downto 0) is xtilde_pre_buf_last_data(DATA_WIDTH - 1 downto 0);
	alias  xtilde_pre_buf_last_s: std_logic is xtilde_pre_buf_last_data(DATA_WIDTH);

	--xhat and xtilde splitters
	signal xtilde_0_valid, xtilde_0_ready, xtilde_0_last_s, xtilde_1_valid, xtilde_1_ready, xtilde_1_last_s: std_logic;
	signal xtilde_0_data, xtilde_1_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xhat_0_valid, xhat_0_ready, xhat_0_last_s, xhat_1_valid, xhat_1_ready, xhat_1_last_s: std_logic;
	signal xhat_0_data, xhat_1_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xhat_1_last_data, xtilde_1_last_data: std_logic_vector(DATA_WIDTH downto 0);

	--fifo before the nth band coder
	signal xhat_1_buf_ready, xhat_1_buf_valid: std_logic;
	signal xhat_1_buf_last_data: std_logic_vector(DATA_WIDTH downto 0);
	alias  xhat_1_buf_last_s: std_logic is xhat_1_buf_last_data(DATA_WIDTH);
	alias  xhat_1_buf_data: std_logic_vector(DATA_WIDTH - 1 downto 0) is xhat_1_buf_last_data(DATA_WIDTH - 1 downto 0);
	signal xtilde_1_buf_ready, xtilde_1_buf_valid: std_logic;
	signal xtilde_1_buf_last_data: std_logic_vector(DATA_WIDTH downto 0);
	alias  xtilde_1_buf_last_s: std_logic is xtilde_1_buf_last_data(DATA_WIDTH);
	alias  xtilde_1_buf_data: std_logic_vector(DATA_WIDTH - 1 downto 0) is xtilde_1_buf_last_data(DATA_WIDTH - 1 downto 0);

	--xhat/xtilde selection
	signal xhatout_valid, xhatout_ready, xhatout_last_s: std_logic;
	signal xhatout_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--d flag substituter
	signal d_flag_data_stdlv: std_logic_vector(0 downto 0);
	signal d_flag_sub_ready, d_flag_sub_valid, d_flag_sub_last: std_logic;
	signal d_flag_sub_data_stdlv: std_logic_vector(0 downto 0);
	
	--d flag last adder
	signal x_2_last_s_and_valid: std_logic;
	signal x_2_last_b_stdlv: std_logic_vector(0 downto 0);
	signal d_flag_presub_valid, d_flag_presub_ready: std_logic;
	signal d_flag_presub_flag, d_flag_presub_last_stdlv: std_logic_vector(0 downto 0); 
	
	--d flag splitter
	signal d_flag_0_data_stdlv, d_flag_1_data_stdlv, d_flag_2_data_stdlv: std_logic_vector(0 downto 0);
	signal d_flag_0_valid, d_flag_0_ready, d_flag_1_valid, d_flag_1_ready, d_flag_2_valid, d_flag_2_ready: std_logic;
	signal d_flag_2_last_b: std_logic;
	signal d_flag_2_last_b_stdlv: std_logic_vector(0 downto 0);
	signal d_flag_2_valid_and_not_b: std_logic;

	--dflag nonlast stuff
	signal d_flag_nonlast_0_valid, d_flag_nonlast_0_ready, d_flag_nonlast_1_valid, d_flag_nonlast_1_ready: std_logic;
	signal d_flag_nonlast_0_data_stdlv, d_flag_nonlast_1_data_stdlv: std_logic_vector(0 downto 0);
	
	--buffers before coder
	signal alpha_1_buf_data: std_logic_vector(ALPHA_WIDTH - 1 downto 0);
	signal alpha_1_buf_ready, alpha_1_buf_valid: std_logic;
	signal xmean_2_buf_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xmean_2_buf_ready, xmean_2_buf_valid: std_logic;

	--final delays
	signal merr_delay_ready, merr_delay_valid: std_logic;
	signal merr_delay_last_ibs_data: std_logic_vector(PREDICTION_WIDTH + 2 downto 0);
	alias  merr_delay_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0) is merr_delay_last_ibs_data(PREDICTION_WIDTH - 1 downto 0);
	alias  merr_delay_last_i: std_logic is merr_delay_last_ibs_data(PREDICTION_WIDTH + 2);
	alias  merr_delay_last_b: std_logic is merr_delay_last_ibs_data(PREDICTION_WIDTH + 1);
	alias  merr_delay_last_s: std_logic is merr_delay_last_ibs_data(PREDICTION_WIDTH + 0);
	signal kj_delay_data: std_logic_vector(WORD_WIDTH_LOG - 1 downto 0);
	signal kj_delay_ready, kj_delay_valid: std_logic;
	
--pragma synthesis_off
	--in_module checkers
	COMPONENT inline_axis_checker 
		GENERIC (
			DATA_WIDTH: integer;
			SKIP: integer;
			FILE_NAME: string
		);
		PORT (
			clk: in std_logic;
			rst: in std_logic;
			valid: in std_logic;
			ready: in std_logic;
			data: in std_logic_vector
		);
	END COMPONENT;

	constant test_dir: string := "C:/Users/Daniel/Repositorios/Lcplc/test_data_2/";
--pragma synthesis_on

begin

	--input to first band predictor and second band predictor
	x_flags_data <= x_last_i & x_last_b & x_last_s & x_last_r & x_data;
	input_splitter: entity work.AXIS_SPLITTER_4
		Generic map (
			DATA_WIDTH	 => DATA_WIDTH + 4
		)
		Port map ( 
			clk => clk, rst => rst,
			--to input axi port
			input_valid => x_valid,
			input_ready	=> x_ready,
			input_data	=> x_flags_data,
			output_0_valid	=> x_0_valid,
			output_0_ready	=> x_0_ready,
			output_0_data	=> x_0_flags_data,
			output_1_valid  => x_1_valid,
			output_1_ready  => x_1_ready,
			output_1_data   => x_1_flags_data,
			output_2_valid  => x_2_valid,
			output_2_ready  => x_2_ready,
			output_2_data   => x_2_flags_data,
			output_3_valid	=> x_3_valid,
			output_3_ready	=> x_3_ready,
			output_3_data	=> x_3_flags_data
		);
	x_0_last_b <= x_0_flags_data(x_0_flags_data'high-1);
	x_0_last_s <= x_0_flags_data(x_0_flags_data'high-2);
	x_1_data   <= x_1_flags_data(DATA_WIDTH - 1 downto 0);
	x_1_last_i <= x_1_flags_data(x_1_flags_data'high-0);
	x_1_last_b <= x_1_flags_data(x_1_flags_data'high-1);
	x_1_last_s <= x_1_flags_data(x_1_flags_data'high-2);
	x_1_last_r <= x_1_flags_data(x_1_flags_data'high-3);
	x_2_last_bs<= x_2_flags_data(x_2_flags_data'high-1 downto x_2_flags_data'high-2);
	x_3_data   <= x_3_flags_data(DATA_WIDTH - 1 downto 0);
	x_3_last_s <= x_3_flags_data(x_3_flags_data'high-2);
	x_3_last_b <= x_3_flags_data(x_3_flags_data'high-1);

	--splitter for bs flags
	x_2_valid_and_last_s <= x_2_valid and x_2_last_bs(0);
	input_bs_splitter: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH => 1
		)
		Port map (
			clk => clk, rst => rst,
			input_valid 	=> x_2_valid_and_last_s,
			input_ready 	=> x_2_ready,
			input_data  	=> x_2_last_bs(1 downto 1),
			output_0_valid	=> x_2_0_valid,
			output_0_ready	=> x_2_0_ready,
			output_0_data	=> x_2_0_last_b_stdlv,
			output_1_valid  => x_2_1_valid,
			output_1_ready	=> x_2_1_ready,
			output_1_data	=> x_2_1_last_b_stdlv
		);
	input_bs_splitter_2: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH => 1
		)
		Port map (
			clk => clk, rst => rst,
			input_valid 	=> x_2_0_valid,
			input_ready 	=> x_2_0_ready,
			input_data  	=> x_2_0_last_b_stdlv,
			output_0_valid	=> x_2_2_valid,
			output_0_ready	=> x_2_2_ready,
			output_0_data	=> x_2_2_last_b_stdlv,
			output_1_valid  => x_2_3_valid,
			output_1_ready	=> x_2_3_ready,
			output_1_data	=> x_2_3_last_b_stdlv
		);

	--average calculator
	input_averager: entity work.AXIS_AVERAGER 
	Generic map (
			DATA_WIDTH 		=> DATA_WIDTH,
			MAX_COUNT_LOG	=> MAX_SLICE_SIZE_LOG,
			IS_SIGNED		=> false
		)
		Port map (
			clk => clk, rst => rst,
			input_data		=> x_3_data,
			input_valid		=> x_3_valid,
			input_ready		=> x_3_ready,
			input_last		=> x_3_last_s,
			input_last_pt 	=> x_3_last_b,
			output_data		=> xmean_data,
			output_valid 	=> xmean_valid,
			output_ready 	=> xmean_ready,
			output_last_pt 	=> xmean_last
		);

	--need now to split the means
	average_splitter: entity work.AXIS_SPLITTER_3
		Generic map (
			DATA_WIDTH	 => DATA_WIDTH
		)
		Port map ( 
			clk => clk, rst => rst,
			--to input axi port
			input_valid => xmean_valid,
			input_ready	=> xmean_ready,
			input_data	=> xmean_data,
			input_last 	=> xmean_last,
			output_0_valid	=> xmean_0_valid,
			output_0_ready	=> xmean_0_ready,
			output_0_data	=> xmean_0_data,
			output_0_last	=> xmean_0_last,
			output_1_valid  => xmean_1_valid,
			output_1_ready  => xmean_1_ready,
			output_1_data   => xmean_1_data,
			output_1_last	=> xmean_1_last,
			output_2_valid  => xmean_2_valid,
			output_2_ready  => xmean_2_ready,
			output_2_data   => xmean_2_data
		);
	xmean_1_last_stdlv <= "1" when xmean_1_last = '1' else "0";

	--one mean stream removes the first, the other removes the last
	filter_first_out: entity work.AXIS_DIVERTER
		Generic map (
			DATA_WIDTH => DATA_WIDTH
		)
		Port map ( 
			clk => clk, rst => rst,
			input_valid		=> xmean_0_valid,
			input_ready		=> xmean_0_ready,
			input_data		=> xmean_0_data,
			input_last_zero	=> '1',
			input_last_one	=> xmean_0_last,
			output_0_valid	=> open,
			output_0_ready	=> '1',
			output_0_data	=> open,
			output_1_valid	=> xmean_nonfirst_valid,
			output_1_ready	=> xmean_nonfirst_ready,
			output_1_data	=> xmean_nonfirst_data
		);

	filter_last_out: entity work.AXIS_FILTER
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			ELIMINATE_ON_UP => true
		)
		Port map (
			clk => clk, rst => rst,
			input_valid		=> xmean_1_valid,
			input_ready		=> xmean_1_ready,
			input_data		=> xmean_1_data,
			flag_valid		=> xmean_1_valid,
			flag_ready		=> open,
			flag_data		=> xmean_1_last_stdlv,
			--to output axi ports
			output_valid	=> xmean_nonlast_valid,
			output_ready	=> xmean_nonlast_ready,
			output_data		=> xmean_nonlast_data
		);

	--split xmeans (nonfirst & nonlast)
	xmean_nonfirst_split: entity work.AXIS_SPLITTER_3
		Generic map (
			DATA_WIDTH	 => DATA_WIDTH
		)
		Port map ( 
			clk => clk, rst => rst,
			--to input axi port
			input_valid => xmean_nonfirst_valid,
			input_ready	=> xmean_nonfirst_ready,
			input_data	=> xmean_nonfirst_data,
			output_0_valid	=> xmean_nonfirst_0_valid,
			output_0_ready	=> xmean_nonfirst_0_ready,
			output_0_data	=> xmean_nonfirst_0_data,
			output_1_valid  => xmean_nonfirst_1_valid,
			output_1_ready  => xmean_nonfirst_1_ready,
			output_1_data   => xmean_nonfirst_1_data,
			output_2_valid  => xmean_nonfirst_2_valid,
			output_2_ready  => xmean_nonfirst_2_ready,
			output_2_data   => xmean_nonfirst_2_data
		);
	xmean_nonlast_split: entity work.AXIS_SPLITTER_3
		Generic map (
			DATA_WIDTH	 => DATA_WIDTH
		)
		Port map ( 
			clk => clk, rst => rst,
			--to input axi port
			input_valid => xmean_nonlast_valid,
			input_ready	=> xmean_nonlast_ready,
			input_data	=> xmean_nonlast_data,
			output_0_valid	=> xmean_nonlast_0_valid,
			output_0_ready	=> xmean_nonlast_0_ready,
			output_0_data	=> xmean_nonlast_0_data,
			output_1_valid  => xmean_nonlast_1_valid,
			output_1_ready  => xmean_nonlast_1_ready,
			output_1_data   => xmean_nonlast_1_data,
			output_2_valid  => xmean_nonlast_2_valid,
			output_2_ready  => xmean_nonlast_2_ready,
			output_2_data   => xmean_nonlast_2_data
		);

			
	diverter_firstband_others: entity work.AXIS_DIVERTER
		Generic map (
			DATA_WIDTH => DATA_WIDTH + 4
		)
		Port map ( 
			clk => clk, rst => rst,
			--to input axi port
			input_valid		=> x_0_valid,
			input_ready		=> x_0_ready,
			input_data		=> x_0_flags_data,
			input_last_zero	=> x_0_last_s,
			input_last_one	=> x_0_last_b,
			--to output axi ports
			output_0_valid	=> x_0_red_valid,
			output_0_ready	=> x_0_red_ready,
			output_0_data	=> x_0_red_flags_data,
			output_1_valid	=> x_1_red_valid,
			output_1_ready	=> x_1_red_ready,
			output_1_data	=> x_1_red_flags_data
		);
	x_0_red_data <= x_0_red_flags_data(DATA_WIDTH - 1 downto 0);
	x_0_red_last_r <= x_0_red_flags_data(x_0_red_flags_data'high - 3);
	x_0_red_last_s <= x_0_red_flags_data(x_0_red_flags_data'high - 2);
	x_1_red_data <= x_1_red_flags_data(DATA_WIDTH - 1 downto 0);
	x_1_red_last_s <= x_1_red_flags_data(x_1_red_flags_data'high - 2);
	x_1_red_last_b <= x_1_red_flags_data(x_1_red_flags_data'high - 1);

	--first band predictor
	first_band_predictor: entity work.FIRSTBAND_PREDICTOR
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			MAX_SLICE_SIZE_LOG => MAX_SLICE_SIZE_LOG,
			QUANTIZER_SHIFT_WIDTH => QUANTIZER_SHIFT_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			x_valid      => x_0_red_valid,
			x_ready	     => x_0_red_ready,
			x_data       => x_0_red_data,
			x_last_r     => x_0_red_last_r,
			x_last_s     => x_0_red_last_s,
			xtilde_ready => prediction_first_pre_ready,
			xtilde_valid => prediction_first_pre_valid,
			xtilde_data  => prediction_first_pre_data_raw,
			xtilde_last  => prediction_first_pre_last,
			cfg_quant_shift => cfg_quant_shift
		);
	prediction_first_pre_data <= std_logic_vector(resize(unsigned(prediction_first_pre_data_raw), prediction_first_pre_data'length));
	prediction_first_pre_last_data <= prediction_first_pre_last & prediction_first_pre_data;

	fifo_firstband: entity work.AXIS_FIFO
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH + 1,
			FIFO_DEPTH => 2**MAX_SLICE_SIZE_LOG
		)
		Port map ( 
			clk => clk, rst => rst,
			input_valid		=> prediction_first_pre_valid,
			input_ready		=> prediction_first_pre_ready,
			input_data		=> prediction_first_pre_last_data,
			--out axi port
			output_ready	=> prediction_first_ready,
			output_data		=> prediction_first_last_data,
			output_valid	=> prediction_first_valid
		);
	

	--splitter for rest of bands
	x_1_red_last_b_stdlv <= x_1_red_last_b & "";
	splitter_others_1: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH	 => DATA_WIDTH,
			USER_WIDTH   => 1
		)
		Port map ( 
			clk => clk, rst => rst,
			--to input axi port
			input_valid => x_1_red_valid,
			input_ready	=> x_1_red_ready,
			input_data	=> x_1_red_data,
			input_user  => x_1_red_last_b_stdlv,
			output_0_valid	=> x_others_1_valid,
			output_0_ready	=> x_others_1_ready,
			output_0_data	=> x_others_1_data,
			output_1_valid  => x_others_2_valid,
			output_1_ready  => x_others_2_ready,
			output_1_user   => x_others_2_last_b_stdlv
		);
		
	--buffer for samples for alpha
	alpha_x_buffer: entity work.AXIS_FIFO 
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			FIFO_DEPTH => (2**MAX_SLICE_SIZE_LOG) + 50 --give slack for the extra ~50 cycles per slice
		)
		Port map ( 
			clk	=> clk, rst => rst,
			--input axi port
			input_valid => x_others_1_valid,
			input_ready => x_others_1_ready,
			input_data	 => x_others_1_data,
			--out axi port
			output_ready=> x_delay_ready,
			output_data => x_delay_data,
			output_valid=> x_delay_valid
		);

	alpha_x_buffer_split: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH	 => DATA_WIDTH
		)
		Port map ( 
			clk => clk, rst => rst,
			--to input axi port
			input_valid => x_delay_valid,
			input_ready	=> x_delay_ready,
			input_data	=> x_delay_data,
			output_0_valid	=> x_delay_0_valid,
			output_0_ready	=> x_delay_0_ready,
			output_0_data	=> x_delay_0_data,
			output_1_valid	=> x_delay_1_valid,
			output_1_ready	=> x_delay_1_ready,
			output_1_data	=> x_delay_1_data
		);
	
	--alpha calculation
	alpha_calc_xhat: entity work.ALPHA_CALC 
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			MAX_SLICE_SIZE_LOG => MAX_SLICE_SIZE_LOG,
			ALPHA_WIDTH => ALPHA_WIDTH
		)
		Port map (
			clk => clk, rst	=> rst,
			x_valid			=> x_delay_0_valid,
			x_ready			=> x_delay_0_ready,
			x_data			=> x_delay_0_data,
			xhat_valid		=> xhat_0_valid,
			xhat_ready		=> xhat_0_ready,
			xhat_data		=> xhat_0_data,
			xhat_last_s		=> xhat_0_last_s,
			xmean_valid		=> xmean_nonfirst_0_valid, 
			xmean_ready		=> xmean_nonfirst_0_ready,
			xmean_data		=> xmean_nonfirst_0_data,
			xhatmean_valid	=> xmean_nonlast_0_valid,
			xhatmean_ready	=> xmean_nonlast_0_ready,
			xhatmean_data	=> xmean_nonlast_0_data,
			alpha_ready     => alpha_xhat_ready,
			alpha_valid		=> alpha_xhat_valid,
			alpha_data		=> alpha_xhat_data
		);

	alpha_calc_xtilde: entity work.ALPHA_CALC
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			MAX_SLICE_SIZE_LOG => MAX_SLICE_SIZE_LOG,
			ALPHA_WIDTH => ALPHA_WIDTH
		)
		Port map (
			clk => clk, rst	=> rst,
			x_valid			=> x_delay_1_valid,
			x_ready			=> x_delay_1_ready,
			x_data			=> x_delay_1_data,
			xhat_valid		=> xtilde_0_valid,
			xhat_ready		=> xtilde_0_ready,
			xhat_data		=> xtilde_0_data,
			xhat_last_s		=> xtilde_0_last_s,
			xmean_valid		=> xmean_nonfirst_1_valid, 
			xmean_ready		=> xmean_nonfirst_1_ready,
			xmean_data		=> xmean_nonfirst_1_data,
			xhatmean_valid	=> xmean_nonlast_1_valid,
			xhatmean_ready	=> xmean_nonlast_1_ready,
			xhatmean_data	=> xmean_nonlast_1_data,
			alpha_ready     => alpha_xtilde_ready,
			alpha_valid		=> alpha_xtilde_valid,
			alpha_data		=> alpha_xtilde_data
		);

	--alpha selector
	alpha_selector: entity work.AXIS_SELECTOR
		generic map (
			DATA_WIDTH => ALPHA_WIDTH
		)
		port map (
			clk => clk, rst => rst,
			input_0_data	=> alpha_xtilde_data,
			input_0_ready	=> alpha_xtilde_ready,
			input_0_valid	=> alpha_xtilde_valid,
			input_1_data	=> alpha_xhat_data,
			input_1_ready	=> alpha_xhat_ready,
			input_1_valid	=> alpha_xhat_valid,
			flag_data		=> d_flag_nonlast_0_data_stdlv,
			flag_ready		=> d_flag_nonlast_0_ready,
			flag_valid		=> d_flag_nonlast_0_valid,
			output_data		=> alpha_data,
			output_valid	=> alpha_valid,
			output_ready	=> alpha_ready
		);

	--alpha_splitter
	alpha_split: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH => ALPHA_WIDTH
		)
		Port map (
			clk => clk, rst	=> rst,
			--to input axi port
			input_valid		=> alpha_valid,
			input_data		=> alpha_data,
			input_ready		=> alpha_ready,
			--to output axi ports
			output_0_valid	=> alpha_0_valid,
			output_0_data	=> alpha_0_data,
			output_0_ready	=> alpha_0_ready,
			output_1_valid	=> alpha_1_valid,
			output_1_data	=> alpha_1_data,
			output_1_ready	=> alpha_1_ready
		);
		
	--nth band predictor
	nthband_predictor: entity work.NTHBAND_PREDICTOR
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			ALPHA_WIDTH => ALPHA_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			xhat_valid		=> xhatout_valid,
			xhat_ready 		=> xhatout_ready,
			xhat_data  		=> xhatout_data,
			xhat_last_s		=> xhatout_last_s,
			xmean_valid		=> xmean_nonfirst_2_valid,
			xmean_ready		=> xmean_nonfirst_2_ready,
			xmean_data		=> xmean_nonfirst_2_data,
			xhatmean_valid	=> xmean_nonlast_2_valid,
			xhatmean_ready	=> xmean_nonlast_2_ready,
			xhatmean_data	=> xmean_nonlast_2_data,
			alpha_valid     => alpha_0_valid, 
			alpha_ready		=> alpha_0_ready,
			alpha_data		=> alpha_0_data,
			--output prediction
			xtilde_ready => prediction_rest_ready,
			xtilde_valid => prediction_rest_valid,
			xtilde_data  => prediction_rest_data,
			xtilde_last_s=> prediction_rest_last
		);
		
	--fifo for B flag that joins the nth band prediction
	b_flag_fifo: entity work.AXIS_FIFO
		generic map (
			DATA_WIDTH => 1,
			FIFO_DEPTH => (2**MAX_SLICE_SIZE_LOG)*2
		)
		port map (
			clk => clk, rst => rst,
			input_valid => x_others_2_valid,
			input_ready => x_others_2_ready,
			input_data  => x_others_2_last_b_stdlv,
			output_ready=> delayed_last_b_ready,
			output_valid=> delayed_last_b_valid,
			output_data => delayed_last_b_stdlv
		);
		
	--synchronizer for b flag and prediction from other bands
	prediction_others_b_flag_sync: entity work.AXIS_SYNCHRONIZER_2
		generic map (
			DATA_WIDTH_0 => PREDICTION_WIDTH,
			DATA_WIDTH_1 => 1,
			LATCH => true,
			LAST_POLICY => PASS_ZERO
		)
		port map (
			clk => clk, rst => rst,
			input_0_valid => prediction_rest_valid,
			input_0_ready => prediction_rest_ready,
			input_0_data  => prediction_rest_data,
			input_0_last  => prediction_rest_last,
			input_1_valid => delayed_last_b_valid,
			input_1_ready => delayed_last_b_ready, 
			input_1_data  => delayed_last_b_stdlv,
			output_valid  => prediction_rest_bsync_valid,
			output_ready  => prediction_rest_bsync_ready,
			output_data_0 => prediction_rest_bsync_data,
			output_data_1 => prediction_rest_bsync_last_b_stdlv,
			output_last	  => prediction_rest_bsync_last_s
		);
		
	--junction for preductions
	prediction_junction: entity work.AXIS_MERGER_2
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH,
			START_ON_PORT => 0
		)
		Port map ( 
			clk => clk, rst => rst,
			input_0_valid	=> prediction_first_valid,
			input_0_ready	=> prediction_first_ready,
			input_0_data	=> prediction_first_data,
			input_0_last    => prediction_first_last,
			input_0_merge   => prediction_first_last,
			input_1_valid	=> prediction_rest_bsync_valid,
			input_1_ready	=> prediction_rest_bsync_ready,
			input_1_data	=> prediction_rest_bsync_data,
			input_1_last    => prediction_rest_bsync_last_s,
			input_1_merge   => prediction_rest_bsync_last_b_stdlv(0),
			output_valid	=> prediction_valid,
			output_ready	=> prediction_ready,
			output_data		=> prediction_data,
			output_last     => prediction_last
		);
		
	--buffer for samples for error calc
	x_1_flags_bs_data <= x_1_last_i & x_1_last_b & x_1_last_s & x_1_data;
	error_calc_x_buffer: entity work.AXIS_FIFO 
		Generic map (
			DATA_WIDTH => DATA_WIDTH + 3,
			FIFO_DEPTH => (2**MAX_SLICE_SIZE_LOG)*2 --leave some slack for the pipeline fill up times
		)
		Port map ( 
			clk	=> clk, rst => rst,
			--input axi port
			input_valid => x_1_valid,
			input_ready => x_1_ready,
			input_data	 => x_1_flags_bs_data,
			--out axi port
			output_ready=> x_delay_delay_ready,
			output_data => x_delay_delay_flags_data,
			output_valid=> x_delay_delay_valid
		);
		
	--error calculations
	error_calc: entity work.ERROR_CALC 
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			MAX_SLICE_SIZE_LOG => MAX_SLICE_SIZE_LOG,
			ACCUMULATOR_WINDOW => ACCUMULATOR_WINDOW,
			QUANTIZER_SHIFT_WIDTH => QUANTIZER_SHIFT_WIDTH
		)
		Port map (
			clk => clk, rst	=> rst,
			x_valid			=> x_delay_delay_valid,
			x_ready			=> x_delay_delay_ready,
			x_data			=> x_delay_delay_data,
			x_last_s	    => x_delay_delay_last_s,
			x_last_b		=> x_delay_delay_last_b,
			x_last_i		=> x_delay_delay_last_i,
			xtilde_in_ready => prediction_ready,
			xtilde_in_valid => prediction_valid,
			xtilde_in_data  => prediction_data,
			xtilde_in_last_s=> prediction_last,
			merr_ready		=> merr_ready,
			merr_valid		=> merr_valid,
			merr_data		=> merr_data,
			merr_last_s     => merr_last_s,
			merr_last_b     => merr_last_b,
			merr_last_i     => merr_last_i,
			kj_ready		=> kj_ready,
			kj_valid		=> kj_valid,
			kj_data			=> kj_data,
			xtilde_out_valid=> xtilde_pre_valid,
			xtilde_out_ready=> xtilde_pre_ready,
			xtilde_out_data => xtilde_pre_data,
			xtilde_out_last_s=> xtilde_pre_last_s,
			xhatout_valid   => xhat_pre_valid,
			xhatout_ready	=> xhat_pre_ready,
			xhatout_data	=> xhat_pre_data,
			xhatout_last_s  => xhat_pre_last_s,
			xhatout_last_b  => xhat_pre_last_b,
			d_flag_valid	=> d_flag_valid,
			d_flag_ready	=> d_flag_ready,
			d_flag_data 	=> d_flag_data,
			cfg_quant_shift => cfg_quant_shift,
			cfg_threshold   => cfg_threshold
		);
	--add small buffer for xtilde since it comes out first
	xtilde_pre_last_data <= xtilde_pre_last_s & xtilde_pre_data;
	delay_err_calc_xtilde: entity work.AXIS_FIFO
		Generic map (
			DATA_WIDTH => DATA_WIDTH + 1,
			FIFO_DEPTH => 20
		)
		Port map ( 
			clk	=> clk, rst => rst,
			input_valid => xtilde_pre_valid,
			input_ready => xtilde_pre_ready,
			input_data	=> xtilde_pre_last_data,
			output_ready=> xtilde_pre_buf_ready,
			output_data => xtilde_pre_buf_last_data,
			output_valid=> xtilde_pre_buf_valid
		);
	--filter signals for last band
	xtilde_filter: entity work.AXIS_BATCH_FILTER
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			ELIMINATE_ON_UP => true
		)
		Port map (
			clk => clk, rst => rst,
			input_valid		=> xtilde_pre_buf_valid,
			input_ready		=> xtilde_pre_buf_ready,
			input_data		=> xtilde_pre_buf_data,
			input_last		=> xtilde_pre_buf_last_s,
			flag_valid		=> x_2_2_valid,
			flag_ready		=> x_2_2_ready,
			flag_data		=> x_2_2_last_b_stdlv,
			--to output axi ports
			output_valid	=> xtilde_valid,
			output_ready	=> xtilde_ready,
			output_data		=> xtilde_data,
			output_last		=> xtilde_last_s
		);

	xhat_filter: entity work.AXIS_BATCH_FILTER
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			ELIMINATE_ON_UP => true
		)
		Port map (
			clk => clk, rst => rst,
			input_valid		=> xhat_pre_valid,
			input_ready		=> xhat_pre_ready,
			input_data		=> xhat_pre_data,
			input_last		=> xhat_pre_last_s,
			flag_valid		=> x_2_3_valid,
			flag_ready		=> x_2_3_ready,
			flag_data		=> x_2_3_last_b_stdlv,
			--to output axi ports
			output_valid	=> xhat_valid,
			output_ready	=> xhat_ready,
			output_data		=> xhat_data,
			output_last		=> xhat_last_s
		);

		
	--xtilde split (one to alpha, one to xhat precalc)
	xtilde_split: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH	 => DATA_WIDTH
		)
		Port map ( 
			clk => clk, rst => rst,
			--to input axi port
			input_valid => xtilde_valid,
			input_ready	=> xtilde_ready,
			input_data	=> xtilde_data,
			input_last  => xtilde_last_s,
			output_0_valid	=> xtilde_0_valid,
			output_0_ready	=> xtilde_0_ready,
			output_0_data	=> xtilde_0_data,
			output_0_last   => xtilde_0_last_s,
			output_1_valid	=> xtilde_1_valid,
			output_1_ready	=> xtilde_1_ready,
			output_1_data	=> xtilde_1_data,
			output_1_last	=> xtilde_1_last_s
		);
	xhat_split: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH	 => DATA_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			input_valid => xhat_valid,
			input_ready	=> xhat_ready,
			input_data	=> xhat_data,
			input_last  => xhat_last_s,
			output_0_valid	=> xhat_0_valid,
			output_0_ready	=> xhat_0_ready,
			output_0_data	=> xhat_0_data,
			output_0_last   => xhat_0_last_s,
			output_1_valid	=> xhat_1_valid,
			output_1_ready	=> xhat_1_ready,
			output_1_data	=> xhat_1_data,
			output_1_last	=> xhat_1_last_s
		);

	d_flag_2_valid_and_not_b <= d_flag_2_valid and (not d_flag_2_last_b);
	flag_nonlast_splitter: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH	 => 1
		)
		Port map (
			clk => clk, rst => rst,
			input_valid => d_flag_2_valid_and_not_b,
			input_ready	=> d_flag_2_ready,
			input_data	=> d_flag_2_data_stdlv,
			output_0_valid	=> d_flag_nonlast_0_valid,
			output_0_ready	=> d_flag_nonlast_0_ready,
			output_0_data	=> d_flag_nonlast_0_data_stdlv,
			output_1_valid	=> d_flag_nonlast_1_valid,
			output_1_ready	=> d_flag_nonlast_1_ready,
			output_1_data	=> d_flag_nonlast_1_data_stdlv
		);

	--batch selector for nth band module input
	--need two fifos here 
	xhat_1_last_data <= xhat_1_last_s & xhat_1_data;
	delay_xhat_1: entity work.AXIS_FIFO
		Generic map (
			DATA_WIDTH => DATA_WIDTH + 1,
			FIFO_DEPTH => 2**MAX_SLICE_SIZE_LOG
		)
		Port map ( 
			clk	=> clk, rst => rst,
			input_valid => xhat_1_valid,
			input_ready => xhat_1_ready,
			input_data	=> xhat_1_last_data,
			output_ready=> xhat_1_buf_ready,
			output_data => xhat_1_buf_last_data,
			output_valid=> xhat_1_buf_valid
		);
	xtilde_1_last_data <= xtilde_1_last_s & xtilde_1_data;
	delay_xtilde_1: entity work.AXIS_FIFO
		Generic map (
			DATA_WIDTH => DATA_WIDTH + 1,
			FIFO_DEPTH => 2**MAX_SLICE_SIZE_LOG
		)
		Port map ( 
			clk	=> clk, rst => rst,
			input_valid => xtilde_1_valid,
			input_ready => xtilde_1_ready,
			input_data	=> xtilde_1_last_data,
			output_ready=> xtilde_1_buf_ready,
			output_data => xtilde_1_buf_last_data,
			output_valid=> xtilde_1_buf_valid
		);
	xhat_tilde_batch_sel: entity work.AXIS_BATCH_SELECTOR
		generic map (
			DATA_WIDTH => DATA_WIDTH,
			LAST_POLICY => PASS_ZERO
		)
		port map (
			clk => clk, rst => rst,
			input_0_data	=> xtilde_1_buf_data,
			input_0_ready	=> xtilde_1_buf_ready,
			input_0_valid	=> xtilde_1_buf_valid,
			input_0_last	=> xtilde_1_buf_last_s,
			input_1_data	=> xhat_1_buf_data,
			input_1_ready	=> xhat_1_buf_ready,
			input_1_valid	=> xhat_1_buf_valid,
			input_1_last	=> xhat_1_buf_last_s,
			flag_data		=> d_flag_nonlast_1_data_stdlv,
			flag_ready		=> d_flag_nonlast_1_ready,
			flag_valid		=> d_flag_nonlast_1_valid,
			output_data		=> xhatout_data,
			output_valid	=> xhatout_valid,
			output_ready	=> xhatout_ready,
			output_last		=> xhatout_last_s
		);

		
	--syncrhonize d flag with input b and s flags
	d_flag_data_stdlv <= "1" when d_flag_data = '1' else "0";
	d_flag_x_flags_syncer: entity work.AXIS_SYNCHRONIZER_2
		Generic map (
			DATA_WIDTH_0 => 1,
			DATA_WIDTH_1 => 1,
			LATCH => true
		)
		Port map (
			clk => clk, rst => rst,
			input_0_valid => d_flag_valid,
			input_0_ready => d_flag_ready,
			input_0_data  => d_flag_data_stdlv,
			input_1_valid => x_2_1_valid,
			input_1_ready => x_2_1_ready,
			input_1_data => x_2_1_last_b_stdlv,
			output_valid => d_flag_presub_valid,
			output_ready => d_flag_presub_ready,
			output_data_0=> d_flag_presub_flag,
			output_data_1=> d_flag_presub_last_stdlv 
		); 
		
	--substitute the first flag by '1' to indicate 
	
	substitute_first_d_flag: entity work.AXIS_SUBSTITUTER 
		Generic map (
			DATA_WIDTH => 1,
			INVALID_TRANSACTIONS => 1
		)
		Port map (
			clk => clk, rst => rst, 
			input_ready => d_flag_presub_ready,
			input_valid => d_flag_presub_valid,
			input_data	=> d_flag_presub_flag, --need to change the logic of this module
			input_sub	=> "1",
			input_last  => d_flag_presub_last_stdlv(0),
			output_ready=> d_flag_sub_ready,
			output_valid=> d_flag_sub_valid,
			output_data => d_flag_sub_data_stdlv,
			output_last => d_flag_sub_last
		);
	
	--d flag splitter
	d_flag_splitter: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH	 => 1
		)
		Port map ( 
			clk => clk, rst => rst,
			--to input axi port
			input_valid => d_flag_sub_valid,
			input_ready	=> d_flag_sub_ready,
			input_data	=> d_flag_sub_data_stdlv,
			input_last  => d_flag_sub_last,
			output_0_valid	=> d_flag_1_valid,
			output_0_ready	=> d_flag_1_ready,
			output_0_data	=> d_flag_1_data_stdlv,
			output_1_valid  => d_flag_2_valid,
			output_1_ready  => d_flag_2_ready,
			output_1_data	=> d_flag_2_data_stdlv,
			output_1_last	=> d_flag_2_last_b
		);		
	d_flag_2_last_b_stdlv <= "1" when d_flag_2_last_b = '1' else "0";
		
	--one fifo for nth band input
	merr_last_data <= merr_last_i & merr_last_b & merr_last_s & merr_data;
	delay_mapped_err: entity work.AXIS_FIFO
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH + 3,
			FIFO_DEPTH => 2**MAX_SLICE_SIZE_LOG
		)
		Port map ( 
			clk	=> clk, rst => rst,
			--input axi port
			input_valid => merr_valid,
			input_ready => merr_ready,
			input_data	 => merr_last_data,
			--out axi port
			output_ready=> merr_delay_ready,
			output_data => merr_delay_last_ibs_data,
			output_valid=> merr_delay_valid
		);
			
	--one fifo for nth band input
	delay_kj_calc: entity work.AXIS_FIFO 
		Generic map (
			DATA_WIDTH => WORD_WIDTH_LOG,
			FIFO_DEPTH => 2**MAX_SLICE_SIZE_LOG
		)
		Port map ( 
			clk	=> clk, rst => rst,
			--input axi port
			input_valid => kj_valid,
			input_ready => kj_ready,
			input_data	=> kj_data,
			--out axi port
			output_ready=> kj_delay_ready,
			output_data => kj_delay_data,
			output_valid=> kj_delay_valid
		);
		
	--coder
	delay_xmean: entity work.AXIS_LATCHED_CONNECTION 
		Generic map (
			DATA_WIDTH => DATA_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			input_ready => xmean_2_ready,
			input_valid => xmean_2_valid,
			input_data  => xmean_2_data,
			output_ready=> xmean_2_buf_ready,
			output_valid=> xmean_2_buf_valid,
			output_data => xmean_2_buf_data
		);
	delay_alpha_coder: entity work.AXIS_LATCHED_CONNECTION 
		Generic map (
			DATA_WIDTH => ALPHA_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			input_ready => alpha_1_ready,
			input_valid => alpha_1_valid,
			input_data  => alpha_1_data,
			output_ready=> alpha_1_buf_ready,
			output_valid=> alpha_1_buf_valid,
			output_data => alpha_1_buf_data
		);

	coder: entity work.CODER 
		Generic map (
			MAPPED_ERROR_WIDTH => PREDICTION_WIDTH,
			ACCUMULATOR_WINDOW => ACCUMULATOR_WINDOW,
			OUTPUT_WIDTH_LOG => WORD_WIDTH_LOG,
			ALPHA_WIDTH => ALPHA_WIDTH,
			DATA_WIDTH => DATA_WIDTH
		)
		Port map (
			clk => clk, rst	=> rst,
			--inputs
			ehat_data	=> merr_delay_data,
			ehat_ready	=> merr_delay_ready,
			ehat_valid	=> merr_delay_valid,
			ehat_last_s => merr_delay_last_s,
			ehat_last_b => merr_delay_last_b,
			ehat_last_i => merr_delay_last_i,
			kj_data		=> kj_delay_data,
			kj_ready	=> kj_delay_ready,
			kj_valid	=> kj_delay_valid,
			d_flag_data	=> d_flag_1_data_stdlv,
			d_flag_ready=> d_flag_1_ready,
			d_flag_valid=> d_flag_1_valid,
			alpha_data	=> alpha_1_buf_data,
			alpha_ready => alpha_1_buf_ready,
			alpha_valid	=> alpha_1_buf_valid,
			xmean_data	=> xmean_2_buf_data,
			xmean_ready => xmean_2_buf_ready,
			xmean_valid => xmean_2_buf_valid,
			--outputs
			output_data	=> output_data,
			output_valid=> output_valid,
			output_ready=> output_ready,
			output_last => output_last
		);
		
		
		
	--checkers for data validity
--pragma synthesis_off
	--coder inputs
	coder_check_merr: inline_axis_checker
		generic map (
			DATA_WIDTH	=> PREDICTION_WIDTH,
			FILE_NAME	=> test_dir & "merr.smpl",
			SKIP 		=> 0
		)
		port map (
			clk => clk, rst => rst, 
			valid => merr_delay_valid, data => merr_delay_data, ready => merr_delay_ready
		);
	coder_check_kj: inline_axis_checker
		generic map (
			DATA_WIDTH	=> WORD_WIDTH_LOG,
			FILE_NAME	=> test_dir & "kj.smpl",
			SKIP 		=> 0
		)
		port map (
			clk => clk, rst => rst, 
			valid => kj_delay_valid, data => kj_delay_data, ready => kj_delay_ready
		);
	coder_check_d_flag: inline_axis_checker
		generic map (
			DATA_WIDTH	=> 1,
			FILE_NAME	=> test_dir & "dflag.smpl",
			SKIP 		=> 0
		)
		port map (
			clk => clk, rst => rst, 
			valid => d_flag_1_valid, data => d_flag_1_data_stdlv, ready => d_flag_1_ready
		);
	coder_check_alpha: inline_axis_checker
		generic map (
			DATA_WIDTH	=> ALPHA_WIDTH,
			FILE_NAME	=> test_dir & "alpha.smpl",
			SKIP 		=> 0
		)
		port map (
			clk => clk, rst => rst, 
			valid => alpha_1_valid, data => alpha_1_data, ready => alpha_1_ready
		);
	coder_check_xmean: inline_axis_checker
		generic map (
			DATA_WIDTH	=> DATA_WIDTH,
			FILE_NAME	=> test_dir & "xmean.smpl",
			SKIP 		=> 0
		)
		port map (
			clk => clk, rst => rst, 
			valid => xmean_nonfirst_valid, data => xmean_nonfirst_data, ready => xmean_nonfirst_ready --xmean after removing first
		);
	-------------------

	--error_calc inputs
	err_calc_check_xtilde: inline_axis_checker
		generic map (
			DATA_WIDTH	=> PREDICTION_WIDTH,
			FILE_NAME	=> test_dir & "xtilde.smpl",
			SKIP 		=> 0
		)
		port map (
			clk => clk, rst => rst, 
			valid => prediction_valid, data => prediction_data, ready => prediction_ready
		);
	err_calc_check_x: inline_axis_checker
		generic map (
			DATA_WIDTH	=> DATA_WIDTH,
			FILE_NAME	=> test_dir & "x.smpl",
			SKIP 		=> 0
		)
		port map (
			clk => clk, rst => rst, 
			valid => x_delay_delay_valid, data => x_delay_delay_data, ready => x_delay_delay_ready
		);
	------------------

	--predictor checks
	firstband_pred_check_xtilde: inline_axis_checker
		generic map (
			DATA_WIDTH 	=> PREDICTION_WIDTH,
			FILE_NAME 	=> test_dir & "xtilde_firstband.smpl",
			SKIP => 0
		)
		port map (
			clk => clk, rst => rst, 
			valid => prediction_first_valid, data => prediction_first_data, ready => prediction_first_ready
		);
	------------------

	--nth band checks
	nthband_pred_check_xhat: inline_axis_checker
		generic map (
			DATA_WIDTH 	=> DATA_WIDTH,
			FILE_NAME	=> test_dir & "xhat.smpl",
			SKIP 		=> 0
		)
		port map (
			clk => clk, rst => rst,
			valid => xhatout_valid, ready => xhatout_ready, data => xhatout_data
		);
	nthband_pred_check_xmean_nonlast: inline_axis_checker
		generic map (
			DATA_WIDTH => DATA_WIDTH,
			FILE_NAME  => test_dir & "xhatmean.smpl",
			SKIP 		=> 0
		)
		port map (
			clk => clk, rst => rst,
			valid => xmean_nonlast_2_valid, ready => xmean_nonlast_2_ready, data => xmean_nonlast_2_data
		);
	nthband_pred_check_xmean_nonfirst: inline_axis_checker
		generic map (
			DATA_WIDTH => DATA_WIDTH,
			FILE_NAME  => test_dir & "xmean.smpl",
			SKIP 		=> 0
		)
		port map (
			clk => clk, rst => rst,
			valid => xmean_nonfirst_2_valid, ready => xmean_nonfirst_2_ready, data => xmean_nonfirst_2_data
		);
	nthband_pred_check_alpha: inline_axis_checker
		generic map (
			DATA_WIDTH => ALPHA_WIDTH,
			FILE_NAME  => test_dir & "alpha.smpl",
			SKIP 		=> 0
		)
		port map (
			clk => clk, rst => rst,
			valid => alpha_0_valid, ready => alpha_0_ready, data => alpha_0_data
		);
	-----------------

	--other checks
	check_xhatout: inline_axis_checker
		generic map (
			DATA_WIDTH	=> DATA_WIDTH,
			FILE_NAME	=> test_dir & "xhat.smpl",
			SKIP 		=> 0
		)
		port map (
			clk => clk, rst => rst, 
			valid => xhatout_valid, data => xhatout_data, ready => xhatout_ready
		);
	---------------
--pragma synthesis_on
	
end Behavioral;