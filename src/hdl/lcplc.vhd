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
use work.data_types.all;

entity LCPLC is
	Generic (
		--configure input data width
		DATA_WIDTH: integer := 16;
		--configure output data width
		WORD_WIDTH_LOG: integer := 5;
		--configure max slice size 
		--the max slice size accepted is 2**MAX_SLICE_SIZE_LOG
		MAX_SLICE_SIZE_LOG: integer := 8;
		--width of the alpha value. This can increase accuracy in prediction
		ALPHA_WIDTH: integer := 10;
		--window with which predictions are made. Smaller windows adapt better to fast changes, while 
		--bigger windows are better for smoother images
		ACCUMULATOR_WINDOW: integer := 32;
		--quantizer up and downshift. With every downshift, a bit is lost so that compression is better
		--but accuracy is lower
		UPSHIFT: integer := 1;
		DOWNSHIFT: integer := 1;
		--threshold for compression. If distortion is greater than this threshold for a certain slice,
		--the slice is compressed. Otherwise the slice is skipped. Set to zero for lossless compression.
		THRESHOLD: std_logic_vector := "100000000000000" 
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
		output_last		: out 	std_logic
	);
end LCPLC;

architecture Behavioral of LCPLC is
	constant PREDICTION_WIDTH: integer := DATA_WIDTH + 3;

	--input separator signals
	signal x_flags_data, x_0_flags_data, x_1_flags_data, x_2_flags_data: std_logic_vector(DATA_WIDTH + 4 - 1 downto 0);
	signal x_0_last_b, x_0_last_s, x_1_last_i, x_1_last_b, x_1_last_s, x_1_last_r, x_2_last_b, x_2_last_s: std_logic;
	signal x_0_valid, x_0_ready, x_1_valid, x_1_ready, x_2_valid, x_2_ready: std_logic;
	signal x_1_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal x_1_flags_bs_data: std_logic_vector(DATA_WIDTH + 2 downto 0);
	
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
	signal prediction_first_ready, prediction_first_valid, prediction_first_last: std_logic;
	signal prediction_first_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	signal prediction_first_data_raw: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--splitter for reduced stuff
	signal x_others_0_valid, x_others_0_ready, x_others_0_last_s, x_others_1_valid, x_others_1_ready: std_logic;
	signal x_others_0_data, x_others_1_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal x_others_2_valid, x_others_2_ready: std_logic;
	signal x_others_2_last_b_stdlv: std_logic_vector(0 downto 0);
	
	--mean calc
	signal xmean_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xmean_valid, xmean_ready: std_logic;
	
	--mean split (alpha and nth pred)
	signal xmean_0_valid, xmean_0_ready, xmean_1_valid, xmean_1_ready, xmean_2_valid, xmean_2_ready: std_logic;
	signal xmean_0_data, xmean_1_data, xmean_2_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--fifo delay for x values
	signal x_delay_ready, x_delay_valid: std_logic;
	signal x_delay_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--fifo delay for nth band prediction
	signal x_delay_delay_ready, x_delay_delay_valid: std_logic;
	signal x_delay_delay_flags_data: std_logic_vector(DATA_WIDTH + 2 downto 0);
	alias  x_delay_delay_data: std_logic_vector(DATA_WIDTH - 1 downto 0) is x_delay_delay_flags_data(DATA_WIDTH - 1 downto 0);
	alias  x_delay_delay_last_s: std_logic is x_delay_delay_flags_data(DATA_WIDTH);
	alias  x_delay_delay_last_b: std_logic is x_delay_delay_flags_data(DATA_WIDTH + 1);
	alias  x_delay_delay_last_i: std_logic is x_delay_delay_flags_data(DATA_WIDTH + 2);

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
	signal xtilde_valid		: std_logic;
	signal xtilde_ready		: std_logic;
	signal xtilde_last		: std_logic;
	signal xtilde_data		: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xhat_valid		: std_logic;
	signal xhat_ready		: std_logic;
	signal xhat_last_s		: std_logic;
	signal xhat_last_b		: std_logic;
	signal xhat_data		: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal d_flag_valid		: std_logic;
	signal d_flag_ready		: std_logic;
	signal d_flag_data 		: std_logic;
	
	--d flag substituter
	signal d_flag_data_stdlv: std_logic_vector(0 downto 0);
	signal d_flag_sub_ready, d_flag_sub_valid: std_logic;
	signal d_flag_sub_data_stdlv: std_logic_vector(0 downto 0);
	
	--d flag last adder
	signal x_2_last_s_and_valid: std_logic;
	signal x_2_last_b_stdlv: std_logic_vector(0 downto 0);
	signal d_flag_presub_valid, d_flag_presub_ready: std_logic;
	signal d_flag_presub_flag, d_flag_presub_last_stdlv: std_logic_vector(0 downto 0); 
	
	--d flag splitter
	signal d_flag_0_data_stdlv, d_flag_1_data_stdlv: std_logic_vector(0 downto 0);
	signal d_flag_0_valid, d_flag_0_ready, d_flag_1_valid, d_flag_1_ready: std_logic;
	
	--xhat precalc
	signal xhatout_data, xhatoutmean_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xhatout_ready, xhatout_valid, xhatout_last, xhatoutmean_ready, xhatoutmean_valid: std_logic;
	
	--xhat splitter
	signal xhatout_0_valid, xhatout_0_ready, xhatout_0_last, xhatout_1_valid, xhatout_1_ready, xhatout_1_last: std_logic;
	signal xhatout_0_data, xhatout_1_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xhatout_1_last_data: std_logic_vector(DATA_WIDTH downto 0);
	
	--xhat delay fifo
	signal xhatout_delay_ready, xhatout_delay_valid, xhatout_delay_last: std_logic;
	signal xhatout_delay_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xhatout_delay_last_data: std_logic_vector(DATA_WIDTH downto 0);
	
	--xhatout mean splitter
	signal xhatoutmean_0_valid, xhatoutmean_0_ready, xhatoutmean_1_valid,xhatoutmean_1_ready: std_logic;
	signal xhatoutmean_0_data, xhatoutmean_1_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--final delays
	signal merr_delay_ready, merr_delay_valid: std_logic;
	signal merr_delay_last_ibs_data: std_logic_vector(PREDICTION_WIDTH + 2 downto 0);
	alias  merr_delay_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0) is merr_delay_last_ibs_data(PREDICTION_WIDTH - 1 downto 0);
	alias  merr_delay_last_i: std_logic is merr_delay_last_ibs_data(PREDICTION_WIDTH + 2);
	alias  merr_delay_last_b: std_logic is merr_delay_last_ibs_data(PREDICTION_WIDTH + 1);
	alias  merr_delay_last_s: std_logic is merr_delay_last_ibs_data(PREDICTION_WIDTH + 0);
	signal kj_delay_data: std_logic_vector(WORD_WIDTH_LOG - 1 downto 0);
	signal kj_delay_ready, kj_delay_valid: std_logic;

begin

	--input to first band predictor and second band predictor
	x_flags_data <= x_last_i & x_last_b & x_last_s & x_last_r & x_data;
	input_splitter: entity work.AXIS_SPLITTER_3
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
			output_2_data   => x_2_flags_data
		);
	x_0_last_b <= x_0_flags_data(x_0_flags_data'high-1);
	x_0_last_s <= x_0_flags_data(x_0_flags_data'high-2);
	x_1_data   <= x_1_flags_data(DATA_WIDTH - 1 downto 0);
	x_1_last_i <= x_1_flags_data(x_1_flags_data'high-0);
	x_1_last_b <= x_1_flags_data(x_1_flags_data'high-1);
	x_1_last_s <= x_1_flags_data(x_1_flags_data'high-2);
	x_1_last_r <= x_1_flags_data(x_1_flags_data'high-3);
	x_2_last_b <= x_2_flags_data(x_2_flags_data'high-1);
	x_2_last_s <= x_2_flags_data(x_2_flags_data'high-2);
		
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
			MAX_SLICE_SIZE_LOG => MAX_SLICE_SIZE_LOG
		)
		Port map (
			clk => clk, rst => rst,
			x_valid      => x_0_red_valid,
			x_ready	     => x_0_red_ready,
			x_data       => x_0_red_data,
			x_last_r     => x_0_red_last_r,
			x_last_s     => x_0_red_last_s,
			xtilde_ready => prediction_first_ready,
			xtilde_valid => prediction_first_valid,
			xtilde_data  => prediction_first_data_raw,
			xtilde_last  => prediction_first_last
		);
	prediction_first_data <= std_logic_vector(resize(unsigned(prediction_first_data_raw), prediction_first_data'length));
	

		
	--splitter for rest of bands
	x_1_red_last_b_stdlv <= x_1_red_last_b & "";
	splitter_others_1: entity work.AXIS_SPLITTER_3
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
			input_last  => x_1_red_last_s,
			input_user  => x_1_red_last_b_stdlv,
			output_0_valid	=> x_others_0_valid,
			output_0_ready	=> x_others_0_ready,
			output_0_data	=> x_others_0_data,
			output_0_last   => x_others_0_last_s,
			output_1_valid	=> x_others_1_valid,
			output_1_ready	=> x_others_1_ready,
			output_1_data	=> x_others_1_data,
			output_1_last   => open,
			output_2_valid  => x_others_2_valid,
			output_2_ready  => x_others_2_ready,
			output_2_user   => x_others_2_last_b_stdlv
		);
	
	--raw mean 
	raw_mean_calc: entity work.AXIS_AVERAGER 
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			MAX_COUNT_LOG => MAX_SLICE_SIZE_LOG,
			IS_SIGNED => false
		)
		Port map (
			clk => clk, rst => rst,
			input_data		=> x_others_0_data,
			input_valid		=> x_others_0_valid,
			input_ready		=> x_others_0_ready,
			input_last      => x_others_0_last_s,
			output_data		=> xmean_data,
			output_valid	=> xmean_valid,
			output_ready	=> xmean_ready
		);
		
	--xmean splitter (alpha and nth prediciton)
	splitter_xmean: entity work.AXIS_SPLITTER_3
		Generic map (
			DATA_WIDTH	 => DATA_WIDTH
		)
		Port map ( 
			clk => clk, rst => rst,
			--to input axi port
			input_valid => xmean_valid,
			input_ready	=> xmean_ready,
			input_data	=> xmean_data,
			output_0_valid	=> xmean_0_valid,
			output_0_ready	=> xmean_0_ready,
			output_0_data	=> xmean_0_data,
			output_1_valid	=> xmean_1_valid,
			output_1_ready	=> xmean_1_ready,
			output_1_data	=> xmean_1_data,
			output_2_valid  => xmean_2_valid,
			output_2_ready  => xmean_2_ready,
			output_2_data   => xmean_2_data
		);
		
	--buffer for samples for alpha
	alpha_x_buffer: entity work.AXIS_FIFO 
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			FIFO_DEPTH => 2**MAX_SLICE_SIZE_LOG
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
	
	--alpha calculation
	alpha_calc: entity work.ALPHA_CALC 
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			MAX_SLICE_SIZE_LOG => MAX_SLICE_SIZE_LOG,
			ALPHA_WIDTH => ALPHA_WIDTH
		)
		Port map (
			clk => clk, rst	=> rst,
			x_valid			=> x_delay_valid,
			x_ready			=> x_delay_ready,
			x_data			=> x_delay_data,
			xhat_valid		=> xhatout_0_valid,
			xhat_ready		=> xhatout_0_ready,
			xhat_data		=> xhatout_0_data,
			xhat_last_s		=> xhatout_0_last,
			xmean_valid		=> xmean_0_valid,
			xmean_ready		=> xmean_0_ready,
			xmean_data		=> xmean_0_data,
			xhatmean_valid	=> xhatoutmean_0_valid, 
			xhatmean_ready	=> xhatoutmean_0_ready,
			xhatmean_data	=> xhatoutmean_0_data,
			alpha_ready     => alpha_ready,
			alpha_valid		=> alpha_valid,
			alpha_data		=> alpha_data
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
			xhat_valid		=> xhatout_delay_valid,
			xhat_ready 		=> xhatout_delay_ready,
			xhat_data  		=> xhatout_delay_data,
			xhat_last_b		=> xhatout_delay_last,
			xmean_valid		=> xmean_1_valid,
			xmean_ready		=> xmean_1_ready,
			xmean_data		=> xmean_1_data,
			xhatmean_valid	=> xhatoutmean_1_valid,
			xhatmean_ready	=> xhatoutmean_1_ready,
			xhatmean_data	=> xhatoutmean_1_data,
			alpha_valid     => alpha_0_valid, 
			alpha_ready		=> alpha_0_ready,
			alpha_data		=> alpha_0_data,
			--output prediction
			xtilde_ready => prediction_rest_ready,
			xtilde_valid => prediction_rest_valid,
			xtilde_data  => prediction_rest_data,
			xtilde_last_b=> prediction_rest_last
		);
		
	--fifo for B flag that joins the nth band prediction
	b_flag_fifo: entity work.AXIS_FIFO
		generic map (
			DATA_WIDTH => 1,
			FIFO_DEPTH => 2**MAX_SLICE_SIZE_LOG
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
			FIFO_DEPTH => (2**MAX_SLICE_SIZE_LOG)*2
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
			UPSHIFT => UPSHIFT,
			DOWNSHIFT => DOWNSHIFT,
			THRESHOLD => THRESHOLD
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
			xtilde_out_valid=> xtilde_valid,
			xtilde_out_ready=> xtilde_ready,
			xtilde_out_data => xtilde_data,
			xtilde_out_last_s=> xtilde_last,
			xhatout_valid   => xhat_valid,
			xhatout_ready	=> xhat_ready,
			xhatout_data	=> xhat_data,
			xhatout_last_s  => xhat_last_s,
			xhatout_last_b  => xhat_last_b,
			d_flag_valid	=> d_flag_valid,
			d_flag_ready	=> d_flag_ready,
			d_flag_data 	=> d_flag_data
		);
		
	--get substituter helper flags
	x_2_last_b <= x_2_flags_data(x_2_flags_data'high-1);
	x_2_last_s <= x_2_flags_data(x_2_flags_data'high-2);
	--syncrhonize d flag with input b and s flags
	d_flag_data_stdlv <= "1" when d_flag_data = '1' else "0";
	x_2_last_s_and_valid <= x_2_last_s and x_2_valid;
	x_2_last_b_stdlv <= "1" when x_2_last_b = '1' else "0";
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
			input_1_valid => x_2_last_s_and_valid,
			input_1_ready => x_2_ready,
			input_1_data => x_2_last_b_stdlv,
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
			output_data => d_flag_sub_data_stdlv
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
			output_0_valid	=> d_flag_0_valid,
			output_0_ready	=> d_flag_0_ready,
			output_0_data	=> d_flag_0_data_stdlv,
			output_1_valid	=> d_flag_1_valid,
			output_1_ready	=> d_flag_1_ready,
			output_1_data	=> d_flag_1_data_stdlv
		);
		
	--xhat prediction and such
	xhat_precalc: entity work.NEXT_XHAT_PRECALC
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			MAX_SLICE_SIZE_LOG => MAX_SLICE_SIZE_LOG
		)
		Port map (
			rst => rst, clk	=> clk,
			--inputs
			xhat_data		=> xhat_data,
			xhat_ready		=> xhat_ready,
			xhat_valid		=> xhat_valid,
			xhat_last_s	 	=> xhat_last_s,
			xhat_last_b     => xhat_last_b,
			xtilde_data		=> xtilde_data,
			xtilde_ready	=> xtilde_ready,
			xtilde_valid	=> xtilde_valid,
			xtilde_last_s	=> xtilde_last,
			d_flag_data		=> d_flag_0_valid,
			d_flag_ready	=> d_flag_0_ready,
			d_flag_valid	=> d_flag_0_valid,
			xhatout_ready	=> xhatout_ready,
			xhatout_valid	=> xhatout_valid,
			xhatout_data	=> xhatout_data,
			xhatout_last_s  => xhatout_last,
			xhatoutmean_ready	=> xhatoutmean_ready,
			xhatoutmean_data	=> xhatoutmean_data, 
			xhatoutmean_valid	=> xhatoutmean_valid
		);
		
	--splitter for xhatout
	xhatout_splitter: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH	 => DATA_WIDTH
		)
		Port map ( 
			clk => clk, rst => rst,
			--to input axi port
			input_valid => xhatout_valid,
			input_ready	=> xhatout_ready,
			input_data	=> xhatout_data,
			input_last	=> xhatout_last,
			output_0_valid	=> xhatout_0_valid,
			output_0_ready	=> xhatout_0_ready,
			output_0_data	=> xhatout_0_data,
			output_0_last   => xhatout_0_last,
			output_1_valid	=> xhatout_1_valid,
			output_1_ready	=> xhatout_1_ready,
			output_1_data	=> xhatout_1_data,
			output_1_last   => xhatout_1_last
		);
	
	--one fifo for nth band input
	xhatout_1_last_data <= xhatout_1_last & xhatout_1_data;
	xhatout_buffer: entity work.AXIS_FIFO 
		Generic map (
			DATA_WIDTH => DATA_WIDTH + 1,
			FIFO_DEPTH => 2**MAX_SLICE_SIZE_LOG
		)
		Port map ( 
			clk	=> clk, rst => rst,
			--input axi port
			input_valid => xhatout_1_valid,
			input_ready => xhatout_1_ready,
			input_data	=> xhatout_1_last_data,
			--out axi port
			output_ready=> xhatout_delay_ready,
			output_data => xhatout_delay_last_data,
			output_valid=> xhatout_delay_valid
		);
	xhatout_delay_last <= xhatout_delay_last_data(DATA_WIDTH);
	xhatout_delay_data <= xhatout_delay_last_data(DATA_WIDTH - 1 downto 0);
		
	--splitter for xhatoutmean
	xhatoutmean_splitter: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH	 => DATA_WIDTH
		)
		Port map ( 
			clk => clk, rst => rst,
			--to input axi port
			input_valid => xhatoutmean_valid,
			input_ready	=> xhatoutmean_ready,
			input_data	=> xhatoutmean_data,
			output_0_valid	=> xhatoutmean_0_valid,
			output_0_ready	=> xhatoutmean_0_ready,
			output_0_data	=> xhatoutmean_0_data,
			output_1_valid	=> xhatoutmean_1_valid,
			output_1_ready	=> xhatoutmean_1_ready,
			output_1_data	=> xhatoutmean_1_data
		);
		
		
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
			alpha_data	=> alpha_1_data,
			alpha_ready => alpha_1_ready,
			alpha_valid	=> alpha_1_valid,
			xmean_data	=> xmean_2_data,
			xmean_ready => xmean_2_ready,
			xmean_valid => xmean_2_valid,
			--outputs
			output_data	=> output_data,
			output_valid=> output_valid,
			output_ready=> output_ready,
			output_last => output_last
		);


end Behavioral;
