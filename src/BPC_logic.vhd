----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:24:44 06/11/2018 
-- Design Name: 
-- Module Name:    BPC_logic - Behavioral 
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
use work.JypecConstants.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity BPC_logic is
	generic (
		--number of strips
		STRIPS: integer := 16;
		--number of stripes
		COLS: integer := 64;
		--number of bitplanes (excluding sign plane)
		BITPLANES: integer := 15;
		--number of elements in inner queues
		BPC_OUT_QUEUE_SIZE: integer := 32;
		BPC_CXD_QUEUE_SIZE: integer := 32;
		--BPC_MQO_QUEUE_SIZE: integer := 32;
		--BPC_BYT_QUEUE_SIZE: integer := 32;
		BOUND_UPDATE_FIFO_DEPTH: positive := 32;
		OUT_FIFO_DEPTH: positive := 32
	);
	port (
		clk, rst, clk_en: in std_logic;
		--inputs
		input: in std_logic_vector((BITPLANES+1)*4 - 1 downto 0);
		input_loc: in natural range 0 to COLS*STRIPS - 1;
		input_en: in std_logic;
		--outputs
		out_empty:	out std_logic; 
		out_byte:	out std_logic_vector(7 downto 0); 
		out_readen: in std_logic; 
		done: out std_logic
	);
end BPC_logic;

architecture Behavioral of BPC_logic is
	--BPC_LOGIC control
	type logic_control_state_t is (IDLE, BPC_CORE_PROCESSING, BPC_CORE_FLUSHING, 
											BPC_SERIALIZER_PROCESSING, BPC_SERIALIZER_FLUSHING, ENDING_MQ, 
											FLUSHING_LAST_BYTES, BLOCK_FINISHED);
	signal logic_control_state_curr, logic_control_state_next: logic_control_state_t;

	--BPC core control
	type core_control_state_t is (WAITING, STREAM, ENDING, FINISHED);
	signal core_control_state_curr, core_control_state_next: core_control_state_t;
	signal BPC_core_enable: std_logic;
	signal BPC_core_done: std_logic;

	--BPC_core signals
	signal BPC_core_out_contexts, BPC_core_out_contexts_latched: BPC_out_contexts_t;
	signal BPC_core_out_bits, BPC_core_out_bits_latched: BPC_out_bits_t;
	signal BPC_core_out_valid, BPC_core_out_valid_latched: BPC_out_valid_t;
	signal BPC_core_done_next_cycle, BPC_core_done_next_cycle_latched: std_logic;
	signal BPC_fifo_wr_en_latched: std_logic;

	--BPC_fifo signals
	signal BPC_fifo_empty, BPC_fifo_full: std_logic;
	signal BPC_fifo_rd_en, BPC_fifo_wr_en: std_logic;
	signal BPC_fifo_out_contexts: BPC_out_contexts_t;
	signal BPC_fifo_out_bits: BPC_out_bits_t;
	signal BPC_fifo_out_valid: BPC_out_valid_t;

	--BPC serializer signals
	signal BPC_serial_out_bit: std_logic;
	signal BPC_serial_out_context: context_label_t;
	signal BPC_serial_out_valid: std_logic;
	signal BPC_serial_in_available: std_logic;
	signal BPC_serial_idle: std_logic;
	--CXD queue signals
	signal CXD_queue_full, CXD_queue_empty, CXD_queue_rd_en: std_logic;
	signal CXD_queue_out_context: context_label_t;
	signal CXD_queue_out_bit: std_logic;
	
	--arith coder control
	type MQcoder_control_state_t is (IDLE, DATA_READY, PIPE_FLUSHED, FINISHED);
	--signal MQcoder_control_state_next, MQcoder_control_state_curr: MQcoder_control_state_t;
	constant MQCODER_COUNT: integer := 4;
	signal MQcoder_clk_en, MQcoder_end_coding_en: std_logic;
	signal MQcoder_out_bytes: std_logic_vector(15 downto 0);
	signal MQcoder_out_enable: std_logic_vector(1 downto 0);
	--signal MQcoder_counter_next, MQcoder_counter_curr: natural range 0 to MQCODER_COUNT - 1;
	signal MQcoder_finished: std_logic;
	
	--FIFO FOR RAW arit coded rata
	signal fifodata_wren, fifodata_readen, fifodata_empty, fifodata_full: std_logic;
	signal fifodata_in, fifodata_out: std_logic_vector(17 downto 0);
	
	--controlling raw fifo to serialized fifo
	type output_control_t is (IDLE, OUTPUT_ONE, OUTPUT_TWO);
	--signal out_control_state_curr, out_control_state_next: output_control_t;
	signal output_data_curr, output_data_next: std_logic_vector(15 downto 0);
	signal output_data_valid_curr, output_data_valid_next: std_logic_vector(1 downto 0);
	signal outputting: std_logic;
	
		
	--FIFO FOR byte by byte output
	signal out_empty_in: std_logic;
	

begin
	out_empty <= out_empty_in;
	--signals for flushing the pipeline
	--BPC_core_done
	--BPC_fifo_empty
	--BPC_serial_idle
	--CXD_queue_empty

	--FULL LOGIC CONTROL
	logic_state_update: process(logic_control_state_curr, clk_en, BPC_core_done, 
				BPC_fifo_empty, BPC_serial_idle, CXD_queue_empty, MQcoder_finished,
				out_empty_in)
	begin
		logic_control_state_next <= logic_control_state_curr;
		done <= '0';
		MQcoder_end_coding_en <= '0';
		
		case logic_control_state_curr is
			when IDLE =>
				if clk_en = '1' then
					logic_control_state_next <= BPC_CORE_PROCESSING;
				end if;
			when BPC_CORE_PROCESSING =>
				if BPC_core_done = '1' then
					logic_control_state_next <= BPC_CORE_FLUSHING;
				end if;
			when BPC_CORE_FLUSHING =>
				if BPC_fifo_empty = '1' then
					logic_control_state_next <= BPC_SERIALIZER_PROCESSING;
				end if;
			when BPC_SERIALIZER_PROCESSING =>
				if BPC_serial_idle = '1' then
					logic_control_state_next <= BPC_SERIALIZER_FLUSHING;
				end if;
			when BPC_SERIALIZER_FLUSHING =>
				if CXD_queue_empty = '1' then
					logic_control_state_next <= ENDING_MQ;
				end if;
			when ENDING_MQ =>
				MQcoder_end_coding_en <= '1';
				if MQcoder_finished = '1' then
					logic_control_state_next <= FLUSHING_LAST_BYTES;
				end if;
			--todo insert oxfffe marker
			when FLUSHING_LAST_BYTES =>
				if out_empty_in = '1' then
					logic_control_state_next <= BLOCK_FINISHED;
				end if;
			when BLOCK_FINISHED =>
				done <= '1';
		end case;
	end process;

	




	state_update: process(clk, rst, clk_en, core_control_state_next)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				core_control_state_curr <= WAITING;
				--MQcoder_control_state_curr <= IDLE;
				--out_Control_state_curr <= IDLE;
				--MQcoder_counter_curr <= 0;
				logic_control_state_curr <= IDLE;
			elsif (clk_en = '1') then
				core_control_state_curr <= core_control_state_next;
				--MQcoder_control_state_curr <= MQcoder_control_state_next;
				--out_Control_state_curr <= out_control_state_next;
				--MQcoder_counter_curr <= MQcoder_counter_next;
				logic_control_state_curr <= logic_control_state_next;
			end if;
		end if;
	end process;


	BPC_core: entity work.BPC
		generic map (STRIPS => STRIPS, COLS => COLS, BITPLANES => BITPLANES)
		port map (
			clk => clk, rst => rst, 
			clk_en => BPC_core_enable,
			input => input,
			input_loc => input_loc,
			input_en => input_en,
			out_contexts => BPC_core_out_contexts,
			out_bits => BPC_core_out_bits,
			out_valid => BPC_core_out_valid,
			out_done_next_cycle => BPC_core_done_next_cycle
		);
		
	--BPC_core control process
	BPC_core_control_comb: process(clk_en, core_control_state_curr, BPC_core_done_next_cycle, BPC_fifo_full, BPC_core_out_valid)
	begin
		core_control_state_next <= core_control_state_curr;
		BPC_core_enable <= '0';
		BPC_fifo_wr_en <= '0';
		BPC_core_done <= '0';
	
		case core_control_state_curr is
			when WAITING =>
				if (clk_en = '1') then
					--generate next group of CxD pairs
					BPC_core_enable <= '1';
					core_control_state_next <= STREAM;
				end if;
			when STREAM =>
				if (BPC_fifo_full = '0') then
					--write previous (only if there is something meaningful)
					--TODO: this might be better latched (it adds ~300ns to critical path)
					--so basically latch the outputs of BPC and wait a cycle before sending it to the BPC fifo
					if (BPC_core_out_valid /= "00000000000") then
						BPC_fifo_wr_en <= '1';
					end if;
					--generate next
					BPC_core_enable <= '1';
					if (BPC_core_done_next_cycle = '1') then
						core_control_state_next <= FINISHED;
					end if;
				end if;
			when ENDING =>
				if (BPC_fifo_full = '0') then
					BPC_fifo_wr_en <= '1';
					core_control_state_next <= FINISHED;
				end if;
			when FINISHED =>
				BPC_core_done <= '1';
				--nothing to do. stay until reset
		end case;
	end process;
	
	
	latch_bpc_fifo_input: process(clk, rst)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				BPC_fifo_wr_en_latched <= '0';
			else
				BPC_core_out_contexts_latched <= BPC_core_out_contexts;
				BPC_core_out_bits_latched <= BPC_core_out_bits;
				BPC_core_out_valid_latched <= BPC_core_out_valid;
				BPC_core_done_next_cycle_latched <= BPC_core_done_next_cycle;
				BPC_fifo_wr_en_latched <= BPC_fifo_wr_en;
			end if;
		end if;
	end process;	
		
	BPC_fifo: entity work.BPC_core_fifo
		generic map (QUEUE_SIZE => BPC_OUT_QUEUE_SIZE)
		port map (
			clk => clk, rst => rst,
			--inputs
			wr_en => BPC_fifo_wr_en_latched,
			in_contexts => BPC_core_out_contexts_latched,
			in_bits => BPC_core_out_bits_latched,
			in_valid => BPC_core_out_valid_latched,
			--outputs
			rd_en => BPC_fifo_rd_en,
			out_contexts => BPC_fifo_out_contexts,
			out_bits => BPC_fifo_out_bits,
			out_valid => BPC_fifo_out_valid,
			--flags
			full => BPC_fifo_full,
			empty => BPC_fifo_empty
		);
		
	BPC_serial_in_available <= '1' when BPC_fifo_empty = '0' else '0';
		
	BPC_output_serializer: entity work.BPC_output_controller
		port map (
			clk => clk, rst => rst, --enabled by out_full
			in_contexts => BPC_fifo_out_contexts,
			in_bits => BPC_fifo_out_bits,
			in_valid => BPC_fifo_out_valid,
			in_available => BPC_serial_in_available,
			out_full => CXD_queue_full,
			in_request => BPC_fifo_rd_en,
			out_context => BPC_serial_out_context,
			out_symbol => BPC_serial_out_bit,
			out_valid => BPC_serial_out_valid,
			out_idle => BPC_serial_idle
		);
		
		
	BPC_cxd_queue: entity work.BPC_cxd_fifo
		generic map(QUEUE_SIZE => BPC_CXD_QUEUE_SIZE)
		port map(
			clk => clk, rst => rst,
			wr_en => BPC_serial_out_valid, rd_en => CXD_queue_rd_en,
			full => CXD_queue_full, empty => CXD_queue_empty,
			in_context => BPC_serial_out_context,
			in_bit => BPC_serial_out_bit,
			out_context => CXD_queue_out_context,
			out_bit => CXD_queue_out_bit
		);
		
--	MQcoder_control: process
--	
--	begin
--		case MQcoder_control_state_curr is
--			when IDLE => 
--				if CXD_queue_empty = '0' then
--					CXD_queue_rd_en <= '1';
--					MQcoder_control_state_next <= DATA_READY;
--				
--			when DATA_READY =>
--			
--			when FINISHED =>
--			
--		end case;
--	
--	end process;

	--TODO add some kind of control here for the end_coding_en as it could be fired before ready
--	MQcoder_control: process(MQcoder_control_state_curr, CXD_queue_empty, core_control_state_curr, fifodata_full, mqcoder_counter_curr)
--	begin
--		CXD_queue_rd_en <= '0';
--		MQcoder_control_state_next <= MQcoder_control_state_curr;
--		MQcoder_clk_en <= '0';
--		MQcoder_end_coding_en <= '0';
--		MQcoder_counter_next <= 0;
--		
--		case MQcoder_control_state_curr is
--			when IDLE =>
--				if CXD_queue_empty = '0' then
--					CXD_queue_rd_en <= '1';
--					MQcoder_control_state_next <= DATA_READY;
--				elsif core_control_state_curr = FINISHED then
--					if MQcoder_counter_curr = MQCODER_COUNT - 1 then
--						MQCoder_clk_en <= '1';
--						MQcoder_end_coding_en <= '1';
--						MQcoder_control_state_next <= PIPE_FLUSHED;
--					else
--						MQcoder_counter_next <= MQcoder_counter_curr + 1;
--					end if;
--				end if;
--			when DATA_READY =>
--				if (fifodata_full = '0') then
--					MQCoder_clk_en <= '1';
--					if CXD_queue_empty = '0' then
--						CXD_queue_rd_en <= '1';
--						MQcoder_control_state_next <= DATA_READY;
--					else
--						MQcoder_control_state_next <= IDLE;
--					end if;
--				end if;
--			when PIPE_FLUSHED =>
--				--basically waiting for the MQCODER pipeline to flush out
--				if MQcoder_counter_curr = 0 then
--					MQcoder_counter_next <= MQcoder_counter_curr + 1;
--					MQCoder_clk_en <= '1';
--				elsif MQcoder_counter_curr = MQCODER_COUNT - 1 then
--					MQcoder_control_state_next <= FINISHED;
--				else
--					MQcoder_counter_next <= MQcoder_counter_curr + 1;
--				end if;
--			when FINISHED =>
--				--nothing to do
--		end case;
--	end process;
	
		
--	coder: entity work.MQCoder_fast
--		port map(
--			clk => clk, rst => rst,
--			clk_en => MQcoder_clk_en,
--			in_bit => CXD_queue_out_bit,
--			end_coding_enable => MQcoder_end_coding_en,
--			in_context => CXD_queue_out_context,
--			out_bytes => MQcoder_out_bytes,
--			out_enable => MQcoder_out_enable
--		);

	coder: entity work.MQCoder_piped
		generic map (
			BOUND_UPDATE_FIFO_DEPTH => BOUND_UPDATE_FIFO_DEPTH,
			OUT_FIFO_DEPTH => OUT_FIFO_DEPTH
		)
		port map (
			clk => clk,
			rst => rst,
			in_bit => CXD_queue_out_bit,
			end_coding_enable => MQcoder_end_coding_en,
			in_context => CXD_queue_out_context,
			in_empty => CXD_queue_empty,
			in_request => CXD_queue_rd_en,
			fifo_ob_readen => out_readen,
			fifo_ob_out => out_byte,
			fifo_ob_empty => out_empty_in,
			mq_finished => MQcoder_finished
		);
		
		

		
		
end Behavioral;

