----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:38:46 07/02/2018 
-- Design Name: 
-- Module Name:    MQCoder_piped - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
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
use work.JypecConstants.all;


entity MQCoder_piped is
	generic (
		OUT_FIFO_DEPTH: positive := 32;
		BOUND_UPDATE_FIFO_DEPTH: positive := 32
	);
	port(
		--control signals
		clk, rst: in std_logic;
		
		--input & input control
		--if we have stuff available to read
		in_empty: in std_logic;
		--request input
		in_request: out std_logic;
		--bit to code
		in_bit: in std_logic;
		--flag to end coding and output remaining bits
		end_coding_enable: in std_logic;
		--context with which this is coding
		in_context: in context_label_t;
		
		--output & output control
		fifo_ob_readen: in std_logic;
		fifo_ob_out: out std_logic_vector(7 downto 0);
		fifo_ob_empty: out std_logic;
		mq_finished: out std_logic
	);
end MQCoder_piped;




architecture Behavioral of MQCoder_piped is
	--mq state
	type MQ_STATE_T is (IDLE, WORKING, FLUSHING_IU_FIFO, TERMINATE_SEGMENT, FINISHED);
	signal state_mq_curr, state_mq_next: mq_state_t;
	signal end_bound_update: std_logic;
	
	--interval update fifo signals
	constant FIFO_IU_DATA_WIDTH: integer := 1 + 16 + 4;
	signal fifo_iu_wren: std_logic;
	signal fifo_iu_in: std_logic_vector(FIFO_IU_DATA_WIDTH - 1 downto 0);
	signal fifo_iu_readen: std_logic;
	signal fifo_iu_out: std_logic_Vector(FIFO_IU_DATA_WIDTH - 1 downto 0);
	signal fifo_iu_empty: std_logic;
	signal fifo_iu_lah_full: std_logic;
	
	signal fifo_iu_in_end, fifo_iu_out_end: std_logic;
	signal fifo_iu_in_hit, fifo_iu_out_hit: std_logic;
	signal fifo_iu_in_prob, fifo_iu_out_prob: unsigned(15 downto 0);
	signal fifo_iu_in_shift, fifo_iu_out_shift: unsigned(3 downto 0);
	
	
	
	--mq interval update control
	type MQ_IU_CTRL_T is (IDLE, REQUESTED, FLUSH_1, FLUSH_2, IU_FINISHED);
	signal state_mq_iu_curr, state_mq_iu_next: MQ_IU_CTRL_T;
	signal mq_iu_enable: std_logic;
	signal iu_finished_flag: std_logic;
	
	--mq bound update flags and outputs
	signal bound_update_finished, bound_update_idle: std_logic;
	signal fifo_ob_wren: std_logic;
	signal fifo_ob_in: std_logic_vector(7 downto 0);
	
	

	
	
begin

	state_control: process(state_mq_curr, in_empty, iu_finished_flag, fifo_iu_empty, bound_update_idle, bound_update_finished)
	begin
		end_bound_update <= '0';
		mq_finished <= '0';
		state_mq_next <= state_mq_curr;
		
		case state_mq_curr is
			when IDLE =>
				if in_empty = '0' then
					state_mq_next <= WORKING;
				end if;
			when WORKING =>
				if iu_finished_flag = '1' then
					state_mq_next <= FLUSHING_IU_FIFO;
				end if;
			when FLUSHING_IU_FIFO =>
				--ensure that the bound update has finished normal operation before enabling end_bound_update
				if fifo_iu_empty = '1' and bound_update_idle = '1' then
					state_mq_next <= TERMINATE_SEGMENT;
				end if;
			--enable end coding for one cycle.
			when TERMINATE_SEGMENT =>
				end_bound_update <= '1';
				if bound_update_finished = '1' then
					state_mq_next <= FINISHED;
				end if;
			when FINISHED =>
				mq_finished <= '1';
			end case;
	end process;



	--update both interval and bound control processes
	control_update: process(clk, rst)
	begin
		if (rising_edge(clk)) then
			if rst = '1' then
				state_mq_iu_curr <= IDLE;
				state_mq_curr <= IDLE;
			else
				state_mq_iu_curr <= state_mq_iu_next;
				state_mq_curr <= state_mq_next;
			end if;
		end if;
	end process;

	interval_update_ctrl: process(in_empty, fifo_iu_lah_full, state_mq_iu_curr, end_coding_enable)
	begin	
		--dont request anything by default, go back to idle state
		in_request <= '0';
		iu_finished_flag <= '0';
		state_mq_iu_next <= state_mq_iu_curr;
		
		case state_mq_iu_curr is
			when IDLE =>
				--if fifo is almost full to the lookahead value just wait on reading more
				if (in_empty = '0' and fifo_iu_lah_full = '0') then
					in_request <= '1';
					state_mq_iu_next <= REQUESTED;
				end if;
				--detect end coding and flush the pipeline
				if (in_empty = '1' and end_coding_enable = '1') then
					state_mq_iu_next <= FLUSH_1;
				end if;
				
			when REQUESTED =>
				--if fifo is almost full to the lookahead value just wait on reading more
				if (in_empty = '0' and fifo_iu_lah_full = '0') then
					in_request <= '1';
				else
					state_mq_iu_next <= IDLE;
				end if;
					
			when FLUSH_1 =>
				state_mq_iu_next <= FLUSH_2;
			when FLUSH_2 =>
				state_mq_iu_next <= IU_FINISHED;
			when IU_FINISHED =>
				iu_finished_flag <= '1';
		end case;

	

	end process;
	
	mq_iu_enable <= '1' when state_mq_iu_curr = REQUESTED else '0';
	
	interval_update: entity work.MQ_interval_update
		port map (
			clk => clk, rst => rst, clk_en => mq_iu_enable,
			in_bit => in_bit, 
			in_context => in_context,
			out_hit => fifo_iu_in_hit,
			out_prob => fifo_iu_in_prob,
			out_shift => fifo_iu_in_shift,
			out_enable => fifo_iu_wren		
		);
		
	fifo_iu_in <= fifo_iu_in_hit & std_logic_vector(fifo_iu_in_prob & fifo_iu_in_shift);
	
	
	assert BOUND_UPDATE_FIFO_DEPTH >= 4 report "A depth of 4 is needed for the IU FIFO" severity failure;
		
	interval_update_fifo: entity work.LOOKAHEAD_FIFO
		generic map (
			DATA_WIDTH => 1 + 16 + 4,
			FIFO_DEPTH => BOUND_UPDATE_FIFO_DEPTH,
			LOOK_AHEAD => 3
		)
		port map (
			clk => clk, 
			rst => rst,
			wren => fifo_iu_wren,
			datain => fifo_iu_in,
			readen => fifo_iu_readen,
			dataout => fifo_iu_out,
			empty => fifo_iu_empty,
			full => open,
			lah_empty => open,
			lah_full => fifo_iu_lah_full
		);
		
		
	
		
	fifo_iu_out_hit <= fifo_iu_out(FIFO_IU_DATA_WIDTH - 1);
	fifo_iu_out_prob <= unsigned(fifo_iu_out(FIFO_IU_DATA_WIDTH - 2 downto FIFO_IU_DATA_WIDTH - 17));
	fifo_iu_out_shift <= unsigned(fifo_iu_out(FIFO_IU_DATA_WIDTH - 18 downto 0));
		
	bound_update: entity work.MQ_bound_update
		generic map (
			OUT_FIFO_DEPTH => OUT_FIFO_DEPTH
		)
		port map (
			--control signals
			clk => clk, rst => rst,
			--inputs
			end_coding_enable => end_bound_update,
			fifonorm_empty => fifo_iu_empty,
			fifonorm_readen => fifo_iu_readen,
			fifonorm_out_hit => fifo_iu_out_hit,
			fifonorm_out_prob => fifo_iu_out_prob,
			fifonorm_out_shift => fifo_iu_out_shift,
			--outputs
			fifo_ob_readen => fifo_ob_readen,
			fifo_ob_out => fifo_ob_out,
			fifo_ob_empty => fifo_ob_empty,
			bound_update_finished => bound_update_finished,
			bound_update_idle => bound_update_idle
		);



end Behavioral;