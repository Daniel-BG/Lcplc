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
		BPC_MQO_QUEUE_SIZE: integer := 32;
		BPC_BYT_QUEUE_SIZE: integer := 32
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
	--BPC core control
	type core_control_state_t is (WAITING, STREAM, ENDING, FINISHED);
	signal core_control_state_curr, core_control_state_next: core_control_state_t;
	signal BPC_core_enable: std_logic;

	--BPC_core signals
	signal BPC_core_out_contexts: BPC_out_contexts_t;
	signal BPC_core_out_bits: BPC_out_bits_t;
	signal BPC_core_out_valid: BPC_out_valid_t;
	signal BPC_core_done_next_cycle: std_logic;

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
	--CXD queue signals
	signal CXD_queue_full, CXD_queue_empty, CXD_queue_rd_en: std_logic;
	signal CXD_queue_out_context: context_label_t;
	signal CXD_queue_out_bit: std_logic;
	
	--arith coder control
	type MQcoder_control_state_t is (IDLE, DATA_READY, PIPE_FLUSHED, FINISHED);
	signal MQcoder_control_state_next, MQcoder_control_state_curr: MQcoder_control_state_t;
	constant MQCODER_COUNT: integer := 4;
	signal MQcoder_clk_en, MQcoder_end_coding_en: std_logic;
	signal MQcoder_out_bytes: std_logic_vector(15 downto 0);
	signal MQcoder_out_enable: std_logic_vector(1 downto 0);
	signal MQcoder_counter_next, MQcoder_counter_curr: natural range 0 to MQCODER_COUNT - 1;
	
	--FIFO FOR RAW arit coded rata
	signal fifodata_wren, fifodata_readen, fifodata_empty, fifodata_full: std_logic;
	signal fifodata_in, fifodata_out: std_logic_vector(17 downto 0);
	
	--controlling raw fifo to serialized fifo
	type output_control_t is (IDLE, OUTPUT_ONE, OUTPUT_TWO);
	signal out_control_state_curr, out_control_state_next: output_control_t;
	signal output_data_curr, output_data_next: std_logic_vector(15 downto 0);
	signal output_data_valid_curr, output_data_valid_next: std_logic_vector(1 downto 0);
	signal outputting: std_logic;
	
		
	--FIFO FOR byte by byte output
	signal fifoout_wren, fifoout_full, fifoout_readen, fifoout_empty: std_logic;
	signal fifoout_in, fifoout_out: std_logic_vector(7 downto 0);

begin

	state_update: process(clk, rst, clk_en, core_control_state_next)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				core_control_state_curr <= WAITING;
				MQcoder_control_state_curr <= IDLE;
				out_Control_state_curr <= IDLE;
				MQcoder_counter_curr <= 0;
			elsif (clk_en = '1') then
				core_control_state_curr <= core_control_state_next;
				MQcoder_control_state_curr <= MQcoder_control_state_next;
				out_Control_state_curr <= out_control_state_next;
				MQcoder_counter_curr <= MQcoder_counter_next;
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
	BPC_core_control_comb: process(clk_en, core_control_state_curr, BPC_core_done_next_cycle, BPC_fifo_full)
	begin
		core_control_state_next <= core_control_state_curr;
		BPC_core_enable <= '0';
		BPC_fifo_wr_en <= '0';
	
		case core_control_state_curr is
			when WAITING =>
				if (clk_en = '1') then
					--generate next group of CxD pairs
					BPC_core_enable <= '1';
					core_control_state_next <= STREAM;
				end if;
			when STREAM =>
				if (BPC_fifo_full = '0') then
					--write previous
					BPC_fifo_wr_en <= '1';
					--generate next
					BPC_core_enable <= '1';
					if (BPC_core_done_next_cycle = '1') then
						core_control_state_next <= ENDING;
					end if;
				end if;
			when ENDING =>
				if (BPC_fifo_full = '0') then
					BPC_fifo_wr_en <= '1';
					core_control_state_next <= FINISHED;
				end if;
			when FINISHED =>
				--nothing to do. stay until reset
		end case;
	end process;
		
	BPC_fifo: entity work.BPC_core_fifo
		generic map (QUEUE_SIZE => BPC_OUT_QUEUE_SIZE)
		port map (
			clk => clk, rst => rst,
			--inputs
			wr_en => BPC_fifo_wr_en,
			in_contexts => BPC_core_out_contexts,
			in_bits => BPC_core_out_bits,
			in_valid => BPC_core_out_valid,
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
			clk => clk, rst => rst, clk_en => '1',
			in_contexts => BPC_fifo_out_contexts,
			in_bits => BPC_fifo_out_bits,
			in_valid => BPC_fifo_out_valid,
			in_available => BPC_serial_in_available,
			out_full => CXD_queue_full,
			in_request => BPC_fifo_rd_en,
			out_context => BPC_serial_out_context,
			out_symbol => BPC_serial_out_bit,
			out_valid => BPC_serial_out_valid
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

	--TODO add some kind of control here for the end_coding_en as it could be fired before ready
	MQcoder_control: process(MQcoder_control_state_curr, CXD_queue_empty, core_control_state_curr, fifodata_full, mqcoder_counter_curr)
	begin
		CXD_queue_rd_en <= '0';
		MQcoder_control_state_next <= MQcoder_control_state_curr;
		MQcoder_clk_en <= '0';
		MQcoder_end_coding_en <= '0';
		MQcoder_counter_next <= 0;
		
		case MQcoder_control_state_curr is
			when IDLE =>
				if CXD_queue_empty = '0' then
					CXD_queue_rd_en <= '1';
					MQcoder_control_state_next <= DATA_READY;
				elsif core_control_state_curr = FINISHED then
					if MQcoder_counter_curr = MQCODER_COUNT - 1 then
						MQcoder_control_state_next <= PIPE_FLUSHED;
					else
						MQcoder_counter_next <= MQcoder_counter_curr + 1;
					end if;
				end if;
			when DATA_READY =>
				if (fifodata_full = '0') then
					MQCoder_clk_en <= '1';
					if CXD_queue_empty = '0' then
						CXD_queue_rd_en <= '1';
						MQcoder_control_state_next <= DATA_READY;
					else
						MQcoder_control_state_next <= IDLE;
					end if;
				end if;
			when PIPE_FLUSHED =>
				MQcoder_end_coding_en <= '1';
				MQcoder_control_state_next <= FINISHED;
			when FINISHED =>
				--nothing to do
		end case;
	end process;
	
		
	coder: entity work.MQCoder_fast
		port map(
			clk => clk, rst => rst,
			clk_en => MQcoder_clk_en,
			in_bit => CXD_queue_out_bit,
			end_coding_enable => MQcoder_end_coding_en,
			in_context => CXD_queue_out_context,
			out_bytes => MQcoder_out_bytes,
			out_enable => MQcoder_out_enable
		);


	
	--should only be active when a space was available in FIFO_DATA and MQ_core_control_comb triggered an action
	fifodata_in <= MQcoder_out_enable & MQcoder_out_bytes;
	fifodata_wren <= MQcoder_out_enable(0) or MQcoder_out_enable(1);

	--store arith coder output to serialize it
	FIFO_DATA: entity work.STD_FIFO
		generic map (DATA_WIDTH => 18, FIFO_DEPTH => BPC_MQO_QUEUE_SIZE)
		port map (
			clk => clk,
			rst => rst,
			WriteEn	=> fifodata_wren,
			datain	=> fifodata_in,
			ReadEn	=> fifodata_readen,
			dataout	=> fifodata_out,
			Empty		=> fifodata_empty,
			Full		=> fifodata_full
		);
		
	--coder output control
	take_out: process (out_control_state_curr, fifodata_empty, fifodata_out, fifoout_full)
	begin
		out_control_state_next <= out_control_state_curr;
		fifodata_readen <= '0';
		fifoout_wren <= '0';
		fifoout_in <= (others => '0');
	
		case (out_control_state_curr) is
			when IDLE =>
				if (fifodata_empty = '0') then
					out_control_state_next <= OUTPUT_ONE;
					fifodata_readen <= '1';
				end if;
			when OUTPUT_ONE =>
				if (fifodata_out(17) = '1') then
					if (fifoout_full = '0') then
						fifoout_wren <= '1';
						fifoout_in <= fifodata_out(15 downto 8);
						out_control_state_next <= OUTPUT_TWO;
					end if;
				else
					out_control_state_next <= OUTPUT_TWO;
				end if;
			when OUTPUT_TWO =>
				if (fifodata_out(16) = '1') then
					if (fifoout_full = '0') then
						fifoout_wren <= '1';
						fifoout_in <= fifodata_out(7 downto 0);
						if (fifodata_empty = '0') then
							out_control_state_next <= OUTPUT_ONE;
							fifodata_readen <= '1';
						else
							out_control_state_next <= IDLE;
						end if;
					end if;
				else
					if (fifodata_empty = '0') then
						out_control_state_next <= OUTPUT_ONE;
						fifodata_readen <= '1';
					else
						out_control_state_next <= IDLE;
					end if;
				end if;
		end case;
	end process;

	
	--FIFO for storing the data that has to be sent back
	FIFO_OUT: entity work.STD_FIFO
		generic map (
			DATA_WIDTH => 8, FIFO_DEPTH => BPC_BYT_QUEUE_SIZE
		)
		port map (
			clk => clk, rst => rst,
			WriteEn	=> fifoout_wren,
			datain	=> fifoout_in,
			ReadEn	=> fifoout_readen,
			dataout	=> fifoout_out,
			Empty		=> fifoout_empty,
			Full		=> fifoout_full
		);
		
	
	--Map final outputs
	out_empty <= fifoout_empty;
	out_byte <= fifoout_out;
	fifoout_readen <= out_readen; 
	--done when there is nothing left in queues and control units are idle
	done <= '1' when out_control_state_curr = IDLE and MQcoder_control_state_curr = FINISHED and fifoout_empty = '1' and fifodata_empty = '1' else '0';	
		
end Behavioral;

