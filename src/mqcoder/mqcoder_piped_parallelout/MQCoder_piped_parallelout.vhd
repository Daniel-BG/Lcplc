----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:30:50 07/05/2018 
-- Design Name: 
-- Module Name:    MQCoder_piped_parallelout - Behavioral 
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

entity MQCoder_piped_parallelout is
	generic (
		MQOUT_FIFO_DEPTH: positive := 32; --fifo depth for the mqcoder output (3 bytes + 3 bits)
		BYTEOUT_FIFO_DEPTH: positive := 32
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
end MQCoder_piped_parallelout;

architecture Behavioral of MQCoder_piped_parallelout is
	type MQCODER_STATE_T is (IDLE, FLUSH_PARALLEL_PIPE, END_SERIALIZING, FINISHED);
	signal mqcoder_state_curr, mqcoder_state_next: MQCODER_STATE_T;

	type MQ_IN_STATE_T is (IDLE, REQUESTED, END_CODING, FLUSH_1, FLUSH_2, FINISHED);
	signal state_mq_in_curr, state_mq_in_next: MQ_IN_STATE_T;
	
	type SERIALIZER_STATE_T is (IDLE, OUTPUT_FIRST, OUTPUT_SECOND, OUTPUT_THIRD, INSERT_FE, FINISHED);
	signal serializer_state_curr, serializer_state_next: SERIALIZER_STATE_T;
	
	
	
	
	--mq core signals
	signal mq_in_end_coding: std_logic;
	signal mq_in_enable: std_logic;
	signal mq_out_bytes: std_logic_vector(23 downto 0);
	signal mq_out_enable: std_logic_vector(2 downto 0);
	signal core_done: std_logic;
	
	--fifo mqout signals
	signal fifo_mqout_wren, fifo_mqout_readen: std_logic;
	signal fifo_mqout_in, fifo_mqout_out: std_logic_vector(26 downto 0);
	signal fifo_mqout_empty, fifo_mqout_lah_full: std_logic;
	signal fifo_mqout_byte_1, fifo_mqout_byte_2, fifo_mqout_byte_3: std_logic_vector(7 downto 0);
	signal fifo_mqout_byteen_1, fifo_mqout_byteen_2, fifo_mqout_byteen_3: std_logic;


	--fifo byteout signals
	signal fifo_byteout_wren, fifo_byteout_readen: std_logic;
	signal fifo_byteout_in, fifo_byteout_out: std_logic_vector(7 downto 0);
	signal fifo_byteout_empty, fifo_byteout_full: std_logic;
	
	
	--serializer signals
	signal first_serial_byte, second_serial_byte, third_serial_byte: std_logic_vector(7 downto 0);
	signal serial_byte_count_1, serial_byte_count_2, serial_byte_count_3: natural range 0 to 1;
	signal serial_byte_count: natural range 0 to 3;
	
	--output byte burner
	signal fifo_byteout_true_wren, first_byte_burned, second_byte_burned: std_logic;
	
begin

	update_states: process(clk)
	begin
		if (rising_edge(clk)) then
			mqcoder_state_curr <= mqcoder_state_next;
			state_mq_in_curr <= state_mq_in_next;
			serializer_state_curr <= serializer_state_next;
		end if;
	end process;
	
	
	

	mqcoder_state_ctrl: process(mqcoder_state_curr, core_done, fifo_mqout_empty, serializer_state_curr)
	begin
		mqcoder_state_next <= mqcoder_state_curr;
	
		case mqcoder_state_curr is
			when IDLE =>
				if core_done = '1' then
					mqcoder_state_next <= FLUSH_PARALLEL_PIPE;
				end if;
			when FLUSH_PARALLEL_PIPE =>
				if fifo_mqout_empty = '0' then
					mqcoder_state_next <= END_SERIALIZING;
				end if;
			when END_SERIALIZING =>
				if serializer_state_curr = IDLE then
					mqcoder_state_next <= FINISHED;
				end if;
			when FINISHED =>
				--wait for serializer to raise mq_finished
		end case;
	
	end process;



	interval_update_ctrl: process(in_empty, fifo_mqout_lah_full, state_mq_in_curr, end_coding_enable)
	begin	
		--dont request anything by default, go back to idle state
		in_request <= '0';
		state_mq_in_next <= state_mq_in_curr;
		mq_in_end_coding <= '0';
		core_done <= '0';
		
		case state_mq_in_curr is
			when IDLE =>
				--if fifo is almost full to the lookahead value just wait on reading more
				if (in_empty = '0' and fifo_mqout_lah_full = '0') then
					in_request <= '1';
					state_mq_in_next <= REQUESTED;
				end if;
				--detect end coding and flush the pipeline
				if (in_empty = '1' and end_coding_enable = '1' and fifo_mqout_lah_full = '0') then
					state_mq_in_next <= END_CODING;
				end if;
				
			when REQUESTED =>
				--if fifo is almost full to the lookahead value just wait on reading more
				if (in_empty = '0' and fifo_mqout_lah_full = '0') then
					in_request <= '1';
				else
					state_mq_in_next <= IDLE;
				end if;
					
			when END_CODING =>
				mq_in_end_coding <= '1';
				state_mq_in_next <= FLUSH_1;
			when FLUSH_1 =>
				state_mq_in_next <= FLUSH_2;
			when FLUSH_2 =>
				state_mq_in_next <= FINISHED;
			when FINISHED =>
				core_done <= '1';
		end case;
	end process;


	mq_in_enable <= '1' when state_mq_in_curr = REQUESTED or state_mq_in_curr = END_CODING else '0';


	mqcoder_core: entity work.MQCoder_fast_comb 
		port map (
			clk => clk, rst => rst,
			clk_en => mq_in_enable,
			in_bit => in_bit,
			end_coding_enable => mq_in_end_coding,
			in_context => in_context,
			out_bytes => mq_out_bytes,
			out_enable => mq_out_enable
		);
		
		
	fifo_mqout_in <= mq_out_bytes & mq_out_enable;
	--if its full we never get here since the interval_update_ctrl prevents it
	fifo_mqout_wren <= '1' when mq_out_enable /= "000" else '0';
		
		
	mqout_fifo: entity work.LOOKAHEAD_FIFO
		generic map (
			DATA_WIDTH => 24+3,
			FIFO_DEPTH => MQOUT_FIFO_DEPTH,
			LOOK_AHEAD => 3
		)
		port map (
			clk => clk, 
			rst => rst,
			wren => fifo_mqout_wren,
			datain => fifo_mqout_in,
			readen => fifo_mqout_readen,
			dataout => fifo_mqout_out,
			empty => fifo_mqout_empty,
			full => open,
			lah_empty => open,
			lah_full => fifo_mqout_lah_full
		);
		
		
	fifo_mqout_byte_1 <= fifo_mqout_out(26 downto 19);
	fifo_mqout_byte_2 <= fifo_mqout_out(18 downto 11);
	fifo_mqout_byte_3 <= fifo_mqout_out(10 downto 3);
	fifo_mqout_byteen_1 <= fifo_mqout_out(2);
	fifo_mqout_byteen_2 <= fifo_mqout_out(1);
	fifo_mqout_byteen_3 <= fifo_mqout_out(0);
	
	
	first_serial_byte <= fifo_mqout_byte_1 when fifo_mqout_byteen_1 = '1' else
								fifo_mqout_byte_2 when fifo_mqout_byteen_2 = '1' else
								fifo_mqout_byte_3;
								
	second_serial_byte <= fifo_mqout_byte_2 when fifo_mqout_byteen_1 = '1' and fifo_mqout_byteen_2 = '1' else
								 fifo_mqout_byte_3;
								 
	third_serial_byte <= fifo_mqout_byte_3;
	
	
	serial_byte_count_1 <= 1 when fifo_mqout_byteen_1 = '1' else 0;
	serial_byte_count_2 <= 1 when fifo_mqout_byteen_2 = '1' else 0;
	serial_byte_count_3 <= 1 when fifo_mqout_byteen_3 = '1' else 0;
	serial_byte_count <= serial_byte_count_1 + serial_byte_count_2 + serial_byte_count_3;
		
		
	serialize: process(serializer_state_curr, fifo_mqout_empty, fifo_byteout_full, 
		first_serial_byte, second_serial_byte, third_serial_byte, serial_byte_count, mqcoder_state_curr)
	begin
		fifo_mqout_readen <= '0';
		fifo_byteout_wren <= '0';
		fifo_byteout_in <= (others => '0');
		serializer_state_next <= serializer_state_curr;
		mq_finished <= '0';
	
		case serializer_state_curr is
			when IDLE =>
				if fifo_mqout_empty = '0' then
					fifo_mqout_readen <= '1';
					serializer_state_next <= OUTPUT_FIRST;
				elsif mqcoder_state_curr = FINISHED then
					if fifo_byteout_full = '0' then
						fifo_byteout_wren <= '1';
						fifo_byteout_in <= "11111111";
						serializer_state_next <= INSERT_FE;
					end if;
				end if;
			when OUTPUT_FIRST =>
				if fifo_byteout_full = '0' then
					fifo_byteout_in <= first_serial_byte;
					fifo_byteout_wren <= '1';
					if (serial_byte_count = 1) then
						if fifo_mqout_empty = '0' then
							fifo_mqout_readen <= '1';
							serializer_state_next <= OUTPUT_FIRST;
						else
							serializer_state_next <= IDLE;
						end if;
					else
						serializer_state_next <= OUTPUT_SECOND;
					end if;
				end if;
			when OUTPUT_SECOND => 
				if fifo_byteout_full = '0' then
					fifo_byteout_in <= second_serial_byte;
					fifo_byteout_wren <= '1';
					if (serial_byte_count = 2) then
						if fifo_mqout_empty = '0' then
							fifo_mqout_readen <= '1';
							serializer_state_next <= OUTPUT_FIRST;
						else
							serializer_state_next <= IDLE;
						end if;
					else
						serializer_state_next <= OUTPUT_THIRD;
					end if;
				end if;
			when OUTPUT_THIRD =>
				if fifo_byteout_full = '0' then
					fifo_byteout_in <= third_serial_byte;
					fifo_byteout_wren <= '1';
					if fifo_mqout_empty = '0' then
						fifo_mqout_readen <= '1';
						serializer_state_next <= OUTPUT_FIRST;
					else
						serializer_state_next <= IDLE;
					end if;
				end if;
			when INSERT_FE =>
				if fifo_byteout_full = '0' then
					fifo_byteout_wren <= '1';
					fifo_byteout_in <= "11111110";
					serializer_state_next <= FINISHED;
				end if;
			when FINISHED =>
				mq_finished <= '1';
		end case;
	end process;
		
	
	burn_bytes: process (clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				first_byte_burned <= '0';
				second_byte_burned <= '0';
			else
				if (fifo_byteout_wren = '1') then
					if (first_byte_burned = '0') then
						first_byte_burned <= '1';
					end if;
					if (first_byte_burned = '1' and second_byte_burned = '0') then
						second_byte_burned <= '1';
					end if;
				end if;
			end if;
		end if;
	end process;
		
	fifo_byteout_true_wren <= fifo_byteout_wren when first_byte_burned = '1' and second_byte_burned = '1' else '0';
		
	byteout_fifo: entity work.LOOKAHEAD_FIFO
		generic map (
			DATA_WIDTH => 8,
			FIFO_DEPTH => BYTEOUT_FIFO_DEPTH,
			LOOK_AHEAD => 0
		)
		port map (
			clk => clk, 
			rst => rst,
			wren => fifo_byteout_true_wren,
			datain => fifo_byteout_in,
			readen => fifo_byteout_readen,
			dataout => fifo_byteout_out,
			empty => fifo_byteout_empty,
			full => fifo_byteout_full,
			lah_empty => open,
			lah_full => open
		);

		fifo_byteout_readen <= fifo_ob_readen;
		fifo_ob_out <= fifo_byteout_out;
		fifo_ob_empty <= fifo_byteout_empty;


end Behavioral;

