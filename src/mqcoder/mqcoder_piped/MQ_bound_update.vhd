----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:39:14 07/02/2018 
-- Design Name: 
-- Module Name:    MQ_bound_update - Behavioral 
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

use STD.textio.all;
use ieee.std_logic_textio.all;


entity MQ_bound_update is
	generic(
		DEBUG: boolean := false;
		OUT_FIFO_DEPTH: positive := 32
	);
	port(
		--control signals
		clk, rst: in std_logic;
		--inputs & inputs control
		end_coding_enable: in std_logic;
		fifonorm_empty: in std_logic;
		fifonorm_readen: out std_logic;
		fifonorm_out_hit: in std_logic;
		fifonorm_out_prob: in unsigned(15 downto 0);
		fifonorm_out_shift: in unsigned(3 downto 0);
		--output & output control
		fifo_ob_readen: in std_logic;
		fifo_ob_out: out std_logic_vector(7 downto 0);
		fifo_ob_empty: out std_logic;
		bound_update_idle: out std_logic;
		bound_update_finished: out std_logic
	);
end MQ_bound_update;

architecture Behavioral of MQ_bound_update is

	signal clk_en: std_logic;

	type BOUND_UPDATE_STATE_T is (IDLE, VALUES_READ, PIPELINE, STARTING_TERMINATION, TERMINATING, INSERT_FF, INSERT_FE, FINISHED);
	signal output_state_curr, output_state_next: BOUND_UPDATE_STATE_T;
	
	signal shifting_ending: std_logic; --flag indicating that shifting ends this cycle and we need a new shift value
	signal update_byte: std_logic; --flag indicating that a new byte will be output this cycle
	signal curr_probability: unsigned(15 downto 0); --current value to be added to the norm_lower_bound
	--current shift value (can come from fifo or from previous shift), previous shift, and next shift
	signal curr_shift, shifts_to_perform,  last_shift, next_shift: natural range 0 to 15; 
	
	signal normalized_lower_bound, normalized_lower_bound_add, shifted_normalized_lower_bound, normalized_lower_bound_mask, next_normalized_lower_bound: unsigned(27 downto 0);
	
	subtype countdown_timer_t is natural range 0 to 12;
	signal countdown_timer, next_countdown_timer, next_countdown_timer_emit, next_countdown_timer_substract: countdown_timer_t;
	
	
	signal temp_byte_buffer, next_temp_byte_buffer, next_temp_byte_buffer_emit: unsigned(7 downto 0);
	signal buffer_is_FF, buffer_becomes_FF: std_logic;
	
	--finishing signals
	signal n_bits_curr, n_bits_next: integer range -7 to 12 := 0;
	
	--input fifo signals
	signal fifonorm_readen_intent: std_logic;
	
	
	--output byte fifo input & ctrl signals
	signal first_byte_output, second_byte_output: std_logic;
	signal fifo_ob_wren, fifo_ob_wren_latched, fifo_ob_wren_input: std_logic;
	signal fifo_ob_in, fifo_ob_in_latched, fifo_ob_in_default: std_logic_vector(7 downto 0);
	signal fifo_ob_lah_full: std_logic;
	
	
	--debug purposes
	file out_file : text;
	constant out_file_name: string := "out_probhit_bpc.bin";
	
	constant empty_string: character := ' ';
		
begin	

	--enable this circuit only if the output queue is not full (leaving one space as a buffer since we are latching the output and would
	--thus lose a byte if two were generated one after another with the queue having only one space left. The cost is that the queue will 
	--usually have one space open but thats ok
	clk_en <= '1' when fifo_ob_lah_full = '0' else '0';

	--only read if clk_en is up
	fifonorm_readen <= fifonorm_readen_intent when clk_en = '1' else '0';
	
	
	update_bounds: process(output_state_curr, fifonorm_empty, 
		shifting_ending, end_coding_enable, countdown_timer, n_bits_curr)
	begin
	
		output_state_next <= output_state_curr;
		fifonorm_readen_intent <= '0';
		n_bits_next <= 0;
		bound_update_finished <= '0';
		bound_update_idle <= '0';
	
		case output_state_curr is
			when IDLE => 
				bound_update_idle <= '1';
				if fifonorm_empty = '0' then
					output_state_next <= VALUES_READ;
					fifonorm_readen_intent <= '1';
				elsif end_coding_enable = '1' then
					output_state_next <= STARTING_TERMINATION;
				end if;
			--EVEN THOUGH BOTH STATES ARE THE SAME, THEY ARE NEEDED TO SEE WHERE
			--THE NEW SHIFT COMES FROM (FIFO OR LOCAL)
			when VALUES_READ =>
				if shifting_ending = '1' then
					--in this case we can read the next value
					if fifonorm_empty = '0' then
						fifonorm_readen_intent <= '1';
						output_state_next <= VALUES_READ;
					else --nothing available, back to idle
						output_state_next <= IDLE;
					end if;
				else --still shifts to do, but from memory now
					output_state_next <= PIPELINE;
				end if;
			when PIPELINE =>
				if shifting_ending = '1' then
					--in this case we can read the next value
					if fifonorm_empty = '0' then
						fifonorm_readen_intent <= '1';
						output_state_next <= VALUES_READ;
					else --nothing available, back to idle
						output_state_next <= IDLE;
					end if;
				else --still shifts to do, but from memory now
					output_state_next <= PIPELINE;
				end if;
			when STARTING_TERMINATION =>
				n_bits_next <= 12 - countdown_timer;
				output_state_next <= TERMINATING;
			when TERMINATING =>
				n_bits_next <= n_bits_curr - countdown_timer;
				if (n_bits_curr - countdown_timer <= 0) then
					output_state_next <= INSERT_FF;
				end if;
			when INSERT_FF =>
				output_state_next <= INSERT_FE;
			when INSERT_FE =>
				output_state_next <= FINISHED;
			when FINISHED =>
				bound_update_finished <= '1';
				--do nothign
		end case;
	end process;
	
	curr_probability <= fifonorm_out_prob when output_state_curr = VALUES_READ and fifonorm_out_hit = '1' else (others => '0');
	curr_shift <= to_integer(fifonorm_out_shift) when output_state_curr = VALUES_READ --when just read, shift by the input amount
						else countdown_timer when output_state_curr = TERMINATING 			 --when finishing, output the whole byte
							or output_state_curr = STARTING_TERMINATION
						else last_shift;																	 --otherwise, shift by the previous amount
	shifting_ending <= '0' when curr_shift > countdown_timer else '1';

	normalized_lower_bound_add <= normalized_lower_bound + curr_probability;
	shifts_to_perform <= countdown_timer when curr_shift > countdown_timer else curr_shift;
	next_countdown_timer_substract <= 0 when curr_shift >= countdown_timer else countdown_timer - curr_shift;
	next_shift <= 0 when curr_shift <= countdown_timer else curr_shift - countdown_timer;
	--can be cut down to 8 only if countdown_timer is reset to 4
	shifted_normalized_lower_bound <=normalized_lower_bound_add when shifts_to_perform = 0 else
												normalized_lower_bound_add(26 downto 0)&"0" when shifts_to_perform = 1 else
												normalized_lower_bound_add(25 downto 0)&"00" when shifts_to_perform = 2 else
												normalized_lower_bound_add(24 downto 0)&"000" when shifts_to_perform = 3 else
												normalized_lower_bound_add(23 downto 0)&"0000" when shifts_to_perform = 4 else
												normalized_lower_bound_add(22 downto 0)&"00000" when shifts_to_perform = 5 else
												normalized_lower_bound_add(21 downto 0)&"000000" when shifts_to_perform = 6 else
												normalized_lower_bound_add(20 downto 0)&"0000000" when shifts_to_perform = 7 else
												normalized_lower_bound_add(19 downto 0)&"00000000";-- when shifts_to_perform = 8 else
--												normalized_lower_bound_add(18 downto 0)&"000000000" when shifts_to_perform = 9 else
--												normalized_lower_bound_add(17 downto 0)&"0000000000" when shifts_to_perform = 10 else
--												normalized_lower_bound_add(16 downto 0)&"00000000000" when shifts_to_perform = 11 else
--												normalized_lower_bound_add(15 downto 0)&"000000000000" when shifts_to_perform = 12 else
--												normalized_lower_bound_add(14 downto 0)&"0000000000000" when shifts_to_perform = 13 else
--												normalized_lower_bound_add(13 downto 0)&"00000000000000" when shifts_to_perform = 14 else
--												normalized_lower_bound_add(12 downto 0)&"000000000000000";-- when num_shifts = 15;
												
												
	update_byte <= '1' when curr_shift >= countdown_timer else '0';
	buffer_is_FF <= '1' when temp_byte_buffer = "11111111" else '0';
	buffer_becomes_FF <= '1' when temp_byte_buffer = "11111110" and shifted_normalized_lower_bound(27) = '1' else '0';
	
	transfer_byte: process(buffer_is_FF, temp_byte_buffer, shifted_normalized_lower_bound, buffer_becomes_FF)
	begin
		
		if buffer_is_FF = '1' then
			fifo_ob_in_default <= std_logic_vector(temp_byte_buffer);
			next_temp_byte_buffer_emit <= shifted_normalized_lower_bound(27 downto 20);
			normalized_lower_bound_mask <= "1111111100000000000000000000";
			next_countdown_timer_emit <= 7;
		else
			fifo_ob_in_default <= std_logic_vector(temp_byte_buffer + ("0000000" & shifted_normalized_lower_bound(27)));
			if buffer_becomes_FF = '1' then
				next_temp_byte_buffer_emit <= "0" & shifted_normalized_lower_bound(26 downto 20);
				normalized_lower_bound_mask <= "1111111100000000000000000000";
				next_countdown_timer_emit <= 7;
			else
				next_temp_byte_buffer_emit <= shifted_normalized_lower_bound(26 downto 19);
				normalized_lower_bound_mask <= "1111111110000000000000000000";
				next_countdown_timer_emit <= 8;
			end if;
		end if;
	end process;
	
	next_normalized_lower_bound <= shifted_normalized_lower_bound when update_byte = '0' else shifted_normalized_lower_bound and (not normalized_lower_bound_mask);
	next_countdown_timer <= next_countdown_timer_emit when update_byte = '1' else next_countdown_timer_substract;
	next_temp_byte_buffer <= next_temp_byte_buffer_emit when update_byte = '1' else temp_byte_buffer;
	
	
	
	clk_update: process(clk)
	
	begin
		--TODO
		if rising_edge(clk) then
			if (rst = '1') then
				last_shift <= 0;
				normalized_lower_bound <= (others => '0');
				temp_byte_buffer <= (others => '0');
				countdown_timer <= 4;
				output_state_curr <= IDLE;
				n_bits_curr <= 12;
			elsif (clk_en = '1') then
				last_shift <= next_shift;
				normalized_lower_bound <= next_normalized_lower_bound;
				temp_byte_buffer <= next_temp_byte_buffer;
				countdown_timer <= next_countdown_timer;
				output_state_curr <= output_state_next;
				n_bits_curr <= n_bits_next;
			end if;
		end if;
	end process;
	
	fifo_ob_wren <= '1' when clk_en = '1' and (update_byte = '1' or output_state_curr = INSERT_FF or output_state_curr = INSERT_FE) else '0';
	
	
	fifo_ob_in <=  "11111111" when output_state_curr = INSERT_FF else
						"11111110" when output_state_curr = INSERT_FE else
						fifo_ob_in_default;
						
	--improves a tiny lil bit with latching, also allows us to easily remove first two bytes which are emitted and not needed
	latch_fifo_input: process(clk)
	begin
		if rising_edge(clk) then	
			if rst = '1' then
				fifo_ob_wren_latched <= '0';
				fifo_ob_in_latched <= (others => '0');
			else
				fifo_ob_wren_latched <= fifo_ob_wren;
				fifo_ob_in_latched <= fifo_ob_in;
			end if;
		end if;
		if rising_edge(clk) then
			if rst = '1' then
				first_byte_output <= '0';
				second_byte_output <= '0';
			elsif fifo_ob_wren_latched = '1' then
				--load first and second byte output flags
				if first_byte_output = '0' then
					first_byte_output <= '1';
				elsif second_byte_output = '0' then
					second_byte_output <= '1';
				end if;
			end if;
		end if;
	end process;
	fifo_ob_wren_input <= fifo_ob_wren_latched when second_byte_output = '1' else '0'; --enable after burning two bytes
	
	assert OUT_FIFO_DEPTH > 2 report "Output fifo depth should be greater than two to avoid instability" severity warning;
	
	out_bytes_fifo: entity work.LOOKAHEAD_FIFO
		generic map (
			DATA_WIDTH => 8,
			FIFO_DEPTH => OUT_FIFO_DEPTH,
			LOOK_AHEAD => 1
		)
		port map (
			clk => clk, 
			rst => rst,
			wren => fifo_ob_wren_input, --fifo_ob_wren, --
			datain => fifo_ob_in_latched, --fifo_ob_in, --
			readen => fifo_ob_readen,
			dataout => fifo_ob_out,
			empty => fifo_ob_empty,
			full => open,
			lah_empty => open,
			lah_full => fifo_ob_lah_full
		);
		
		
	gen_debug: if DEBUG generate
		debug_process: process
			variable out_line: line;
		begin
			file_open(out_file, out_file_name, write_mode);
			--write until finished
			while true loop
				wait until rising_edge(clk);
				if (output_state_curr = VALUES_READ) then
					write(out_line, std_logic_vector(curr_probability), right, 16);
					write(out_line, empty_string, right, 1);
					write(out_line, std_logic_vector(to_unsigned(curr_shift, 4)), right, 4);
					write(out_line, empty_string, right, 1);
					write(out_line, fifonorm_out_hit, right, 1);
					writeline(out_file, out_line);
				end if;
			end loop;
		end process;
	end generate;

	
end Behavioral;

