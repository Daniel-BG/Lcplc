----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11.02.2019 10:02:47
-- Design Name: 
-- Module Name: nthbandmodule - Behavioral
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

entity NTHBANDMODULE is
	Generic (
		DATA_WIDTH: positive := 16;
		ALPHA_WIDTH: positive := 10;
		BLOCK_SIZE_LOG: positive := 8;
		KJ_WIDTH: positive := 6;
		UPSHIFT: positive := 1;
		DOWNSHIFT: positive := 1
	);
	Port (
		clk, rst		: in  std_logic;
		--input x, xhat, xmean, xhatmean, alpha
		--x is the original value (xmean the mean for the block slice)
		--xhat is the decoded value of previous block slice
		--alpha is the alpha value for the current block slice
		x_valid			: in  std_logic;
		x_ready			: out std_logic;
		x_data			: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		xhat_valid		: in  std_logic;
		xhat_ready		: out std_logic;
		xhat_data		: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		xmean_valid		: in  std_logic;
		xmean_ready		: out std_logic;
		xmean_data		: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		xhatmean_valid	: in  std_logic;
		xhatmean_ready	: out std_logic;
		xhatmean_data	: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		alpha_valid     : in  std_logic;
		alpha_ready		: out std_logic;
		alpha_data		: in std_logic_vector(ALPHA_WIDTH - 1 downto 0);
		--output distortion, mapped error, parameter kj and prediction
		--mapped error is going to be coded with parameter kj later
		--the distortion might be used to skip coding of the current block
		--predictions will be sent as xhat if the block is skipped
		merr_ready		: in std_logic;
		merr_valid		: out std_logic;
		merr_data		: out std_logic_vector(DATA_WIDTH downto 0);
		kj_ready		: in std_logic;
		kj_valid		: out std_logic;
		kj_data			: out std_logic_vector(KJ_WIDTH - 1 downto 0);
		xtilde_valid	: out std_logic;
		xtilde_ready	: in std_logic;
		xtilde_data		: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		xhatout_valid   : out std_logic;
		xhatout_ready	: in std_logic;
		xhatout_data	: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		distortion_valid: out std_logic;
		distortion_ready: in std_logic;
		distortion_data : out std_logic_vector((DATA_WIDTH + 3)*2 + BLOCK_SIZE_LOG - 1 downto 0)
	);
end NTHBANDMODULE;

architecture Behavioral of NTHBANDMODULE is
	constant PREDICTION_WIDTH: integer := DATA_WIDTH + 3;

	type nthband_prediction_state_t is (WAIT_PARAMS, CALCULATING);
	signal prediction_state_curr, prediction_state_next: nthband_prediction_state_t;
	
	--buffers for means and alphas
	signal xmean_buffer, xmean_buffer_next, xhatmean_buffer, xhatmean_buffer_next: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal alpha_buffer, alpha_buffer_next: std_logic_vector(ALPHA_WIDTH - 1 downto 0);
	
	--prediction input limit
	signal pred_in_lim_enable, pred_in_lim_saturated: std_logic;
	signal pred_in_lim_out_valid, pred_in_lim_out_ready: std_logic;
	
	--prediction stage 0
	signal prediction_stage_0_input_a, prediction_stage_0_input_b: std_logic_vector(DATA_WIDTH downto 0);
	signal prediction_stage_0_data: std_logic_vector(DATA_WIDTH downto 0);
	signal prediction_stage_0_out_valid, prediction_stage_0_out_ready: std_logic;
	
	--prediction stage 1
	signal prediction_stage_1_input_b: std_logic_vector(DATA_WIDTH downto 0);
	signal prediction_stage_1_data: std_logic_vector(33 downto 0);
	signal prediction_stage_1_out_valid, prediction_stage_1_out_ready: std_logic;
	
	--prediction stage 2
	signal prediction_stage_2_input_a, prediction_stage_2_input_b: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	signal prediction_stage_2_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	signal prediction_stage_2_out_valid, prediction_stage_2_out_ready: std_logic;
	
	--prediction splitter into 3: 
		--(0) first one goes to output prediction (in case we skip coding)
		--(1) second one goes on to error calculation
		--(2) third one is saved for calculating xhatout
	constant SPLITTER_PORTS: positive := 3;
	constant XTILDE_INDEX			 : natural := 0;
	constant XHATOUT_CALC_FIFO_INDEX : natural := 1;
	constant UNQUANT_ERROR_JOIN_INDEX: natural := 2;
	signal prediction_splitter_valid: std_logic_vector(SPLITTER_PORTS-1 downto 0);
	signal prediction_splitter_data: std_logic_vector(PREDICTION_WIDTH*SPLITTER_PORTS - 1 downto 0);
	signal prediction_splitter_ready: std_logic_vector(SPLITTER_PORTS-1 downto 0);
	
	--fifo for xhatout calculation later (after quantizing/dequantizing the error)
	constant XHATOUT_CALC_FIFO_DEPTH: positive := 3; --as much as the quantizing and dequantizing take
	signal xhatout_calc_fifo_ready, xhatout_calc_fifo_valid: std_logic;
	signal xhatout_calc_fifo_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	
	--unquant error joiner
	constant UNQUANT_ERROR_JOIN_PORTS: positive := 2;
	signal unquant_error_join_output_valid, unquant_error_join_output_ready: std_logic;
	signal unquant_error_join_output_data_0: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal unquant_error_join_output_data_1: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	
	--unquant error calculation
	signal unquant_error_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	signal unquant_error_valid, unquant_error_ready: std_logic;
	
	--error splitter signals
	signal error_splitter_valid_0, error_splitter_valid_1, error_splitter_ready_0, error_splitter_ready_1: std_logic;
	signal error_splitter_data_0, error_splitter_data_1: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	
	--distortion multiplier
	signal distortion_mult_data: std_logic_vector(PREDICTION_WIDTH*2-1 downto 0);
	signal distortion_mult_valid, distortion_mult_ready: std_logic;
	
	--error quantizer
	signal error_quant_ready, error_quant_valid: std_logic;
	signal error_quant_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
	
	--error dequantizer
	signal error_unquant_ready, error_unquant_valid: std_logic;
	signal error_unquant_data: std_logic_vector(PREDICTION_WIDTH - 1 downto 0);
					
begin

	seq: process(clk, rst) 
	begin
		if rising_edge(clk) then
			if rst = '1' then
				prediction_state_curr <= WAIT_PARAMS;
				alpha_buffer <= (others => '0');
				xmean_buffer <= (others => '0');
				xhatmean_buffer <= (others => '0');
			else
				prediction_state_curr <= prediction_state_next;
				alpha_buffer <= alpha_buffer_next;
				xmean_buffer <= xmean_buffer_next;
				xhatmean_buffer <= xhatmean_buffer_next;
			end if;
		end if;
	end process;
	
	comb: process(
		prediction_state_curr, 
		xmean_valid, xhatmean_valid, alpha_valid)
	begin
		--readys
		xmean_ready <= '0';
		xhatmean_ready <= '0';
		alpha_ready <= '0';
		--buffers
		alpha_buffer_next <= alpha_buffer;
		xmean_buffer_next <= xmean_buffer;
		xhatmean_buffer_next <= xhatmean_buffer;
		--state
		prediction_state_next <= prediction_state_curr;
		--control
		pred_in_lim_enable <= '0';
		
		
		
		if prediction_state_curr = WAIT_PARAMS then
			if xmean_valid = '1' and xhatmean_valid = '1' and alpha_valid = '1' then
				xmean_ready <= '1';
				xhatmean_ready <= '1';
				alpha_ready <= '1';
				alpha_buffer_next <= alpha_data;
				xmean_buffer_next <= xmean_data;
				xhatmean_buffer_next <= xhatmean_data;
				prediction_state_next <= CALCULATING;
			end if;
		elsif prediction_state_curr = CALCULATING then
			pred_in_lim_enable <= '1';
		end if;
	end process;


	--connects xhat input with substraction
	prediction_input_limit: entity work.TRANSACTION_LIMITER
		Generic map (
			NUMBER_OF_TRANSACTIONS => 2**BLOCK_SIZE_LOG
		)	
		Port map (
			clk => clk, rst => rst,
			enable => pred_in_lim_enable,
			saturated => pred_in_lim_saturated,
			input_valid => xhat_valid,
			input_ready => xhat_ready,
			output_valid => pred_in_lim_out_valid,
			output_ready => pred_in_lim_out_ready
		);
		
	--------------
	--PREDICTION--
	--------------
	
	--first stage
	prediction_stage_0_input_a <= '0' & xhat_data;
	prediction_stage_0_input_b <= '0' & xhatmean_buffer;
	
	prediction_stage_0: entity work.OP_AXI
		Generic Map (
			DATA_WIDTH => DATA_WIDTH + 1,
			IS_ADD => false,
			IS_SIGNED => true
		)
		Port Map (
			clk => clk, rst => rst,
			input_a => prediction_stage_0_input_a, 
			input_b => prediction_stage_0_input_b,
			input_valid => pred_in_lim_out_valid,
			input_ready => pred_in_lim_out_ready,
			output => prediction_stage_0_data,
			output_valid => prediction_stage_0_out_valid,
			output_ready => prediction_stage_0_out_ready
		);
		
	--second stage
	prediction_stage_1_input_b <= (DATA_WIDTH downto ALPHA_WIDTH => '0') & alpha_buffer;
	
	prediction_stage_1: entity work.MULT_AXI
		Generic map (
			DATA_WIDTH => 17
		)
		Port map (
			clk => clk, rst => rst,
			input_a => prediction_stage_0_data,
			input_b => prediction_stage_1_input_b,
			input_valid => prediction_stage_0_out_valid,
			input_ready => prediction_stage_0_out_ready,
			output => prediction_stage_1_data,
			output_valid => prediction_stage_1_out_valid,
			output_ready => prediction_stage_1_out_ready
		);
	
	--third stage
	prediction_stage_2_input_a <= "000" & xmean_buffer; --to make it up to data-width + 3
	prediction_stage_2_input_b <= prediction_stage_1_data(prediction_stage_1_data'high) & prediction_stage_1_data;
	
	prediction_stage_2: entity work.OP_AXI
		Generic Map (
			DATA_WIDTH => PREDICTION_WIDTH,
			IS_ADD => true,
			IS_SIGNED => true
		)
		Port Map (
			clk => clk, rst => rst,
			input_a => prediction_stage_2_input_a, 
			input_b => prediction_stage_2_input_b,
			input_valid => prediction_stage_1_out_valid,
			input_ready => prediction_stage_1_out_ready,
			output => prediction_stage_2_data,
			output_valid => prediction_stage_2_out_valid,
			output_ready => prediction_stage_2_out_ready
		);

	--prediction splitter (to output queue and to error calculation)
	prediction_splitter: entity work.SPLITTER_AXI
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH,
			OUTPUT_PORTS => 3
		)
		Port map (
			input_valid => prediction_stage_2_out_valid,
			input_ready => prediction_stage_2_out_ready,
			input_data => prediction_stage_2_data,
			output_valid => prediction_splitter_valid,
			output_data => prediction_splitter_data,
			output_ready => prediction_splitter_ready
		);
		
	prediction_splitter_ready(XTILDE_INDEX) <= xtilde_ready;
	xtilde_valid <= prediction_splitter_valid(XTILDE_INDEX);
	xtilde_data	 <= prediction_splitter_data(PREDICTION_WIDTH*(XTILDE_INDEX+1) - 1 downto PREDICTION_WIDTH*XTILDE_INDEX);
	
	--fifo to xhatout calculation
	xhatout_calc_fifo: entity work.FIFO_AXI
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH,
			FIFO_DEPTH => XHATOUT_CALC_FIFO_DEPTH
		)
		Port map (
			clk => clk, rst => rst,
			in_valid => prediction_splitter_valid(XHATOUT_CALC_FIFO_INDEX),
			in_ready => prediction_splitter_ready(XHATOUT_CALC_FIFO_INDEX),
			in_data  => prediction_splitter_data(PREDICTION_WIDTH*(XHATOUT_CALC_FIFO_INDEX+1) - 1 downto PREDICTION_WIDTH*XHATOUT_CALC_FIFO_INDEX),
			out_ready => xhatout_calc_fifo_ready,
			out_valid => xhatout_calc_fifo_valid,
			out_data  => xhatout_calc_fifo_data
		);
	
	
	
	--error calculation
	unquant_error_join: entity work.JOINER_AXI 	
		Generic map (
			DATA_WIDTH_0 => DATA_WIDTH,
			DATA_WIDTH_1 => PREDICTION_WIDTH
		)
		Port map (
			input_valid_0 => x_valid,
			input_ready_0 => x_ready,
			input_data_0  => x_data,
			input_valid_1 => prediction_splitter_valid(UNQUANT_ERROR_JOIN_INDEX),
			input_ready_1 => prediction_splitter_ready(UNQUANT_ERROR_JOIN_INDEX),
			input_data_1  => prediction_splitter_data(PREDICTION_WIDTH*(UNQUANT_ERROR_JOIN_INDEX+1) - 1 downto PREDICTION_WIDTH*UNQUANT_ERROR_JOIN_INDEX),
			output_valid  => unquant_error_join_output_valid,
			output_ready  => unquant_error_join_output_ready,
			output_data_0 => unquant_error_join_output_data_0,
			output_data_1 => unquant_error_join_output_data_1
		);
	
	unquant_error_calc: entity work.OP_AXI
		Generic Map (
			DATA_WIDTH => PREDICTION_WIDTH,
			IS_ADD => false,
			IS_SIGNED => true
		)
		Port Map (
			clk => clk, rst => rst,
			input_a => unquant_error_join_output_data_0, 
			input_b => unquant_error_join_output_data_1,
			input_valid => unquant_error_join_output_valid,
			input_ready => unquant_error_join_output_ready,
			output => unquant_error_data,
			output_valid => unquant_error_valid,
			output_ready => unquant_error_ready
		);
		
	--error splitter (1 for distortion calculation and 1 for continuing with calcs
	error_splitter: entity work.SPLITTER_AXI_2
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH
		)
		Port map (
			input_valid => unquant_error_valid,
			input_ready => unquant_error_ready,
			input_data => unquant_error_data,
			output_0_valid => error_splitter_valid_0,
			output_0_data => error_splitter_data_0,
			output_0_ready => error_splitter_ready_0,
			output_1_valid => error_splitter_valid_1,
			output_1_data => error_splitter_data_1,
			output_1_ready => error_splitter_ready_1
		);
		
	--distortion multiplier
	distortion_multiplier: entity work.MULT_AXI
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			input_a => error_splitter_data_0,
			input_b => error_splitter_data_0,
			input_valid => error_splitter_valid_0,
			input_ready => error_splitter_ready_0,
			output => distortion_mult_data,
			output_valid => distortion_mult_valid,
			output_ready => distortion_mult_ready
		);

	--distortion accumulator
	distortion_accumulator: entity work.ACCUMULATOR
		Generic map (
			DATA_WIDTH => PREDICTION_WIDTH*2,
			ACC_LOG => BLOCK_SIZE_LOG,
			IS_SIGNED => true
		)
		Port map (
			clk => clk, rst => rst,
			input => distortion_mult_data,
			input_valid => distortion_mult_valid,
			input_ready => distortion_mult_ready,
			output_data => distortion_data,
			output_valid => distortion_valid,
			output_ready => distortion_ready
		);
		
	--error quant/dequant
	error_quantizer: entity work.BINARY_QUANTIZER
		Generic map (
			UPSHIFT => UPSHIFT,
			DOWNSHIFT_MINUS_1 => DOWNSHIFT - 1,
			DATA_WIDTH => PREDICTION_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			input_ready => error_splitter_ready_1,
			input_valid => error_splitter_valid_1,
			input => error_splitter_data_1,
			output_ready => error_quant_ready,
			output_valid => error_quant_valid,
			output => error_quant_data
		);
		
	error_dequantizer: entity work.BINARY_DEQUANTIZER
		Generic map (
			UPSHIFT => UPSHIFT,
			DOWNSHIFT_MINUS_1 => DOWNSHIFT - 1,
			DATA_WIDTH => PREDICTION_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			input_ready => error_quant_ready,
			input_valid => error_quant_valid,
			input => error_quant_data,
			output_ready => error_unquant_ready,
			output_valid => error_unquant_valid,
			output => error_unquant_data
		);
		


end Behavioral;
