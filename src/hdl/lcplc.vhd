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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity LCPLC is
	Generic (
		DATA_WIDTH: integer := 16;
		WORD_WIDTH_LOG: integer := 5;
		BLOCK_SIZE_LOG: integer := 8;
		ALPHA_WIDTH: integer := 10;
		NUMBER_OF_BANDS: integer := 224;
		UPSHIFT: integer := 1;
		DOWNSHIFT: integer := 1;
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
	signal x_flags_data, x_0_flags_data, x_1_flags_data: std_logic_vector(DATA_WIDTH + 4 - 1 downto 0);
	signal x_0_last_b, x_0_last_s, x_1_last_i, x_1_last_b, x_1_last_s, x_1_last_r: std_logic;
	signal x_0_valid, x_0_ready, x_1_valid, x_1_ready: std_logic;
	signal x_1_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--diverter for first band/rest
	signal x_0_red_flags_data: std_logic_vector(DATA_WIDTH + 4 - 1 downto 0);
	signal x_0_red_ready, x_0_red_valid: std_logic;
	signal x_0_red_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal x_0_red_last_row, x_0_red_last_slice: std_logic;

	signal x_1_red_flags_data: std_logic_vector(DATA_WIDTH + 4 - 1 downto 0);
	signal x_1_red_ready, x_1_red_valid: std_logic;
	signal x_1_red_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal x_1_red_last_slice: std_logic;

	--prediction first band
	signal prediction_first_ready, prediction_first_valid, prediction_first_last: std_logic;
	signal prediction_first_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	signal prediction_first_data_raw: std_logic_vector(DATA_WIDTH downto 0);
	
	
	
	--splitter for reduced stuff
	signal x_others_0_valid, x_others_0_ready, x_others_0_last, x_others_1_valid, x_others_1_ready, x_others_1_last: std_logic;
	signal x_others_0_data, x_others_1_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
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
	signal x_delay_delay_ready,x_delay_delay_valid: std_logic;
	signal x_delay_delay_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--alpha result
	signal alpha_ready, alpha_valid: std_logic;
	signal alpha_data: std_logic_vector(ALPHA_WIDTH - 1 downto 0);
	
	--alpha splitter
	signal alpha_0_ready, alpha_0_valid: std_logic;
	signal alpha_0_data: std_logic_vector(ALPHA_WIDTH - 1 downto 0);
	signal alpha_1_ready, alpha_1_valid: std_logic;
	signal alpha_1_data: std_logic_vector(ALPHA_WIDTH - 1 downto 0);
	
	--prediction other bands
	signal prediction_rest_ready, prediction_rest_valid: std_logic;
	signal prediction_rest_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	
	--prediction junction
	signal prediction_valid, prediction_ready: std_logic;
	signal prediction_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	
	--error calc
	signal merr_ready	: std_logic;
	signal merr_valid	: std_logic;
	signal merr_data	: std_logic_vector(DATA_WIDTH + 2 downto 0);
	signal kj_ready		: std_logic;
	signal kj_valid		: std_logic;
	signal kj_data		: std_logic_vector(WORD_WIDTH_LOG - 1 downto 0);
	signal xtilde_valid	: std_logic;
	signal xtilde_ready	: std_logic;
	signal xtilde_data	: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xhat_valid	: std_logic;
	signal xhat_ready	: std_logic;
	signal xhat_data	: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal d_flag_valid	: std_logic;
	signal d_flag_ready	: std_logic;
	signal d_flag_data 	: std_logic;
	
	--d flag substituter
	signal d_flag_data_stdlv: std_logic_vector(0 downto 0);
	signal d_flag_sub_ready, d_flag_sub_valid: std_logic;
	signal d_flag_sub_data_stdlv: std_logic_vector(0 downto 0);
	
	--d flag splitter
	signal d_flag_0_data_stdlv, d_flag_1_data_stdlv: std_logic_vector(0 downto 0);
	signal d_flag_0_valid, d_flag_0_ready, d_flag_1_valid, d_flag_1_ready: std_logic;
	
	--xhat precalc
	signal xhatout_data, xhatoutmean_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal xhatout_ready, xhatout_valid, xhatoutmean_ready, xhatoutmean_valid: std_logic;
	
	--xhat splitter
	signal xhatout_0_valid, xhatout_0_ready, xhatout_1_valid, xhatout_1_ready: std_logic;
	signal xhatout_0_data, xhatout_1_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--xhat delay fifo
	signal xhatout_delay_ready, xhatout_delay_valid: std_logic;
	signal xhatout_delay_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--xhatout mean splitter
	signal xhatoutmean_0_valid, xhatoutmean_0_ready, xhatoutmean_1_valid,xhatoutmean_1_ready: std_logic;
	signal xhatoutmean_0_data, xhatoutmean_1_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--reducers before coder
	signal alpha_1_ready_red, alpha_1_valid_red: std_logic;
	signal alpha_1_data_red: std_logic_vector(ALPHA_WIDTH - 1 downto 0);
	signal xmean_2_valid_red, xmean_2_ready_red: std_logic;
	signal xmean_2_data_red: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--final delays
	signal merr_delay_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	signal merr_delay_ready, merr_delay_valid: std_logic;
	signal kj_delay_data: std_logic_vector(WORD_WIDTH_LOG - 1 downto 0);
	signal kj_delay_ready, kj_delay_valid: std_logic;

begin

	--input to first band predictor and second band predictor
	x_flags_data <= x_last_i & x_last_b & x_last_s & x_last_r & x_data;
	input_splitter: entity work.AXIS_SPLITTER_2
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
			output_1_data   => x_1_flags_data
		);
	x_0_last_b <= x_0_flags_data(x_0_flags_data'high-1);
	x_0_last_s <= x_0_flags_data(x_0_flags_data'high-2);
	x_1_data   <= x_1_flags_data(DATA_WIDTH - 1 downto 0);
	x_1_last_i <= x_1_flags_data(x_1_flags_data'high-0);
	x_1_last_b <= x_1_flags_data(x_1_flags_data'high-1);
	x_1_last_s <= x_1_flags_data(x_1_flags_data'high-2);
	x_1_last_r <= x_1_flags_data(x_1_flags_data'high-3);
		
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
	x_0_red_last_row <= x_0_red_flags_data(x_0_red_flags_data'high - 3);
	x_0_red_last_slice <= x_0_red_flags_data(x_0_red_flags_data'high - 2);
	x_1_red_data <= x_1_red_flags_data(DATA_WIDTH - 1 downto 0);
	x_1_red_last_slice <= x_1_red_flags_data(x_1_red_flags_data'high - 2);
		
	--first band predictor
	first_band_predictor: entity work.FIRSTBAND_PREDICTOR
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			BLOCK_SIZE_LOG => BLOCK_SIZE_LOG
		)
		Port map (
			clk => clk, rst => rst,
			x_valid => x_0_red_valid,
			x_ready	=> x_0_red_ready,
			x_data  => x_0_red_data,
			x_last_row => x_0_red_last_row,
			x_last_slice => x_0_red_last_slice,
			prediction_ready => prediction_first_ready,
			prediction_valid => prediction_first_valid,
			prediction_data  => prediction_first_data_raw,
			prediction_last  => prediction_first_last
		);
	prediction_first_data <= "00" & prediction_first_data_raw;
	

		
	--splitter for rest of bands
	splitter_others_1: entity work.AXIS_SPLITTER_2
		Generic map (
			DATA_WIDTH	 => DATA_WIDTH
		)
		Port map ( 
			clk => clk, rst => rst,
			--to input axi port
			input_valid => x_1_red_valid,
			input_ready	=> x_1_red_ready,
			input_data	=> x_1_red_data,
			input_last  => x_1_red_last_slice,
			output_0_valid	=> x_others_0_valid,
			output_0_ready	=> x_others_0_ready,
			output_0_data	=> x_others_0_data,
			output_0_last   => x_others_0_last,
			output_1_valid	=> x_others_1_valid,
			output_1_ready	=> x_others_1_ready,
			output_1_data	=> x_others_1_data,
			output_1_last   => x_others_1_last
		);
	
	--raw mean 
	raw_mean_calc: entity work.AXIS_AVERAGER 
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			COUNT_LOG => BLOCK_SIZE_LOG,
			IS_SIGNED => false
		)
		Port map (
			clk => clk, rst => rst,
			input_data		=> x_others_0_data,
			input_valid		=> x_others_0_valid,
			input_ready		=> x_others_0_ready,
			input_last      => x_others_0_last,
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
			FIFO_DEPTH => 2**BLOCK_SIZE_LOG
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
			MAX_SIZE_LOG => BLOCK_SIZE_LOG,
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
			ALPHA_WIDTH => ALPHA_WIDTH,
			BLOCK_SIZE_LOG => BLOCK_SIZE_LOG
		)
		Port map (
			clk => clk, rst => rst,
			xhat_valid		=> xhatout_delay_valid,
			xhat_ready 		=> xhatout_delay_ready,
			xhat_data  		=> xhatout_delay_data,
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
			prediction_ready => prediction_rest_ready,
			prediction_valid => prediction_rest_valid,
			prediction_data  => prediction_rest_data
		);
		
	--junction for preductions
	prediction_junction: entity work.AXIS_COMBINER
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH,
			FROM_PORT_ZERO => 2**BLOCK_SIZE_LOG,
			FROM_PORT_ONE => 2**BLOCK_SIZE_LOG*(NUMBER_OF_BANDS - 1 )
		)
		Port map ( 
			clk => clk, rst => rst,
			input_0_valid	=> prediction_first_valid,
			input_0_ready	=> prediction_first_ready,
			input_0_data	=> prediction_first_data,
			input_1_valid	=> prediction_rest_valid,
			input_1_ready	=> prediction_rest_ready,
			input_1_data	=> prediction_rest_data,
			output_valid	=> prediction_valid,
			output_ready	=> prediction_ready,
			output_data		=> prediction_data
		);
		
	--buffer for samples for error calc
	error_calc_x_buffer: entity work.AXIS_FIFO 
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			FIFO_DEPTH => (2**BLOCK_SIZE_LOG)*2
		)
		Port map ( 
			clk	=> clk, rst => rst,
			--input axi port
			input_valid => x_2_valid,
			input_ready => x_2_ready,
			input_data	 => x_2_data,
			--out axi port
			output_ready=> x_delay_delay_ready,
			output_data => x_delay_delay_data,
			output_valid=> x_delay_delay_valid
		);
		
	--error calculations
	error_calc: entity work.ERROR_CALC 
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			BLOCK_SIZE_LOG => BLOCK_SIZE_LOG,
			ACC_LOG => WORD_WIDTH_LOG,
			UPSHIFT => UPSHIFT,
			DOWNSHIFT => DOWNSHIFT,
			THRESHOLD => THRESHOLD
		)
		Port map (
			clk => clk, rst	=> rst,
			x_valid			=> x_delay_delay_valid,
			x_ready			=> x_delay_delay_ready,
			x_data			=> x_delay_delay_data,
			prediction_ready=> prediction_ready,
			prediction_valid=> prediction_valid,
			prediction_data => prediction_data,
			merr_ready		=> merr_ready,
			merr_valid		=> merr_valid,
			merr_data		=> merr_data,
			kj_ready		=> kj_ready,
			kj_valid		=> kj_valid,
			kj_data			=> kj_data,
			xtilde_valid	=> xtilde_valid,
			xtilde_ready	=> xtilde_ready,
			xtilde_data		=> xtilde_data,
			xhatout_valid   => xhat_valid,
			xhatout_ready	=> xhat_ready,
			xhatout_data	=> xhat_data,
			d_flag_valid	=> d_flag_valid,
			d_flag_ready	=> d_flag_ready,
			d_flag_data 	=> d_flag_data
		);
		
	--substitute the first flag by '1' to indicate 
	d_flag_data_stdlv <= "1" when d_flag_data = '1' else "0";
	substitute_first_d_flag: entity work.AXIS_SUBSTITUTER 
		Generic map (
			DATA_WIDTH => 1,
			INVALID_TRANSACTIONS => 1,
			VALID_TRANSACTIONS => NUMBER_OF_BANDS - 1
		)
		Port map (
			clk => clk, rst => rst, 
			input_ready => d_flag_ready,
			input_valid => d_flag_valid,
			input_data	=> d_flag_data_stdlv,
			input_sub	=> "1",
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
			BLOCK_SIZE_LOG => BLOCK_SIZE_LOG
		)
		Port map (
			rst => rst, clk	=> clk,
			--inputs
			xhat_data		=> xhat_data,
			xhat_ready		=> xhat_ready,
			xhat_valid		=> xhat_valid,
			xtilde_data		=> xtilde_data,
			xtilde_ready	=> xtilde_ready,
			xtilde_valid	=> xtilde_valid,
			d_flag_data		=> d_flag_0_valid,
			d_flag_ready	=> d_flag_0_ready,
			d_flag_valid	=> d_flag_0_valid,
			xhatout_data	=> xhatout_data,
			xhatout_ready	=> xhatout_ready,
			xhatout_valid	=> xhatout_valid,
			xhatoutmean_data	=> xhatoutmean_data,
			xhatoutmean_ready	=> xhatoutmean_ready,
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
			output_0_valid	=> xhatout_0_valid,
			output_0_ready	=> xhatout_0_ready,
			output_0_data	=> xhatout_0_data,
			output_1_valid	=> xhatout_1_valid,
			output_1_ready	=> xhatout_1_ready,
			output_1_data	=> xhatout_1_data
		);
	
	--one fifo for nth band input
	xhatout_buffer: entity work.AXIS_FIFO 
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			FIFO_DEPTH => 2**BLOCK_SIZE_LOG
		)
		Port map ( 
			clk	=> clk, rst => rst,
			--input axi port
			input_valid => xhatout_1_valid,
			input_ready => xhatout_1_ready,
			input_data	 => xhatout_1_data,
			--out axi port
			output_ready=> xhatout_delay_ready,
			output_data => xhatout_delay_data,
			output_valid=> xhatout_delay_valid
		);
		
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
	delay_mapped_err: entity work.AXIS_FIFO
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH,
			FIFO_DEPTH => 2**BLOCK_SIZE_LOG
		)
		Port map ( 
			clk	=> clk, rst => rst,
			--input axi port
			input_valid => merr_valid,
			input_ready => merr_ready,
			input_data	 => merr_data,
			--out axi port
			output_ready=> merr_delay_ready,
			output_data => merr_delay_data,
			output_valid=> merr_delay_valid
		);
			
	--one fifo for nth band input
	delay_kj_calc: entity work.AXIS_FIFO 
		Generic map (
			DATA_WIDTH => WORD_WIDTH_LOG,
			FIFO_DEPTH => 2**BLOCK_SIZE_LOG
		)
		Port map ( 
			clk	=> clk, rst => rst,
			--input axi port
			input_valid => kj_valid,
			input_ready => kj_ready,
			input_data	 => kj_data,
			--out axi port
			output_ready=> kj_delay_ready,
			output_data => kj_delay_data,
			output_valid=> kj_delay_valid
		);
		
	--reducers for coder inputs
	alpha_red: entity work.AXIS_REDUCER
		Generic map (
			DATA_WIDTH => ALPHA_WIDTH,
			VALID_TRANSACTIONS => 2**BLOCK_SIZE_LOG - 1,
			INVALID_TRANSACTIONS => 1,
			START_VALID => true
		)
		Port map (
			clk => clk, rst => rst,
			input_ready     => alpha_1_ready,
			input_valid		=> alpha_1_valid,
			input_data		=> alpha_1_data,
			output_ready	=> alpha_1_ready_red,
			output_valid	=> alpha_1_valid_red,
			output_data		=> alpha_1_data_red
		);
		
	xmean_red: entity work.AXIS_REDUCER
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			VALID_TRANSACTIONS => 2**BLOCK_SIZE_LOG - 1,
			INVALID_TRANSACTIONS => 1,
			START_VALID => false
		)
		Port map (
			clk => clk, rst => rst,
			input_ready     => xmean_2_ready,
			input_valid		=> xmean_2_valid,
			input_data		=> xmean_2_data,
			output_ready	=> xmean_2_ready_red,
			output_valid	=> xmean_2_valid_red,
			output_data		=> xmean_2_data_red
		);
		
	--coder
	coder: entity work.CODER 
		Generic map (
			MAPPED_ERROR_WIDTH => PREDICTION_WIDTH,
			ACC_LOG => WORD_WIDTH_LOG,
			BLOCK_SIZE_LOG => BLOCK_SIZE_LOG,
			OUTPUT_WIDTH_LOG => WORD_WIDTH_LOG
		)
		Port map (
			clk => clk, rst	=> rst,
			--control
			flush	=> flush,
			flushed	=> flushed,
			--inputs
			ehat_data	=> merr_delay_data,
			ehat_ready	=> merr_delay_ready,
			ehat_valid	=> merr_delay_valid,
			kj_data		=> kj_delay_data,
			kj_ready	=> kj_delay_ready,
			kj_valid	=> kj_delay_valid,
			d_flag_data	=> d_flag_1_data_stdlv,
			d_flag_ready=> d_flag_1_ready,
			d_flag_valid=> d_flag_1_valid,
			alpha_data	=> alpha_1_data_red,
			alpha_ready => alpha_1_ready_red,
			alpha_valid	=> alpha_1_valid_red,
			--XMEAN INPUT: one per band except first (first comes trimmed from outside)
			xmean_data	=> xmean_2_data_red,
			xmean_ready => xmean_2_ready_red,
			xmean_valid => xmean_2_valid_red,
			--outputs
			output_data	=> output_data,
			output_valid=> output_valid,
			output_ready=> output_ready
		);


end Behavioral;
