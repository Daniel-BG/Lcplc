----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 24.10.2017 17:33:38
-- Design Name: 
-- Module Name: EBCoder - Behavioral
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
use work.JypecConstants.all;


-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity EBCoder is
	generic (
		ROWS: integer := 64;
		COLS: integer := 64;
		BITPLANES: integer := 16
	);
	port (
		clk, rst, clk_en: in std_logic;
		busy: out std_logic;
		out_bytes: out std_logic_vector(23 downto 0);
		out_enable: out std_logic_vector(2 downto 0)
	);
end EBCoder;

architecture Behavioral of EBCoder is
	
	type ebcoder_state_t is (
		LOADING_4, LOADING_3, LOADING_2, LOADING_1, 
		CODING_DEFAULT, CODING_SIGN, 
		BURN_3, BURN_2, BURN_1, 
		UNIFORM_2, UNIFORM_1, 
		DUMPING_REMAINING, MARKING_END, FINISHED,
		IDLE);
	signal state_current, state_next: ebcoder_state_t;
	
	--significance storage stuff
	signal raw_neighborhood: sign_neighborhood_t;
	signal significance_state_next: significance_state_t;
	
	--first refinement flag storage stuff
	signal first_refinement_flag_curr: std_logic;
	signal first_refinement_flag_next: std_logic; --unused as output
	
	--iscoded flag stuff
	signal iscoded_flag_curr: std_logic; --unused as input
	signal iscoded_flag_stripe: std_logic_vector(3 downto 0);
	signal iscoded_flag_next: std_logic; --unused as output
	signal full_strip_uncoded: std_logic;
	
	--data stuff
	signal data_stripe_raw: std_logic_vector(BITPLANES * 4 - 1 downto 0);
	signal current_data, next_p3_data, next_p1_data, next_p2_data: std_logic_vector(BITPLANES - 1 downto 0);
	

	--context gen outputs
	signal subband: subband_t;
	signal magnitude_refinement_context, sign_bit_decoding_context, significance_propagation_context: context_label_t; --unused as input
	signal sign_bit_xor: std_logic; --unused as input
	signal is_strip_zero_context: std_logic; --unused as input
	signal strip_first_nonzero: integer range -1 to 3; -- -1 if there is no nonzero, 0-1-2-3 indicate the index of the first nonzero 
	
	--coord gen outputs
	signal row: natural range 0 to ROWS - 1;
	signal col: natural range 0 to COLS - 1;
	signal bitplane: natural range 0 to BITPLANES - 1;
	signal pass: encoder_pass_t; --unsued as input
	signal coord_gen_done: std_logic; --unused as input
	
	--MQCoder stuff
	signal mqcoder_in: std_logic;
	signal mqcoder_context_in: context_label_t; --unused as output
	signal mqcoder_enable: std_logic;
	signal mqcoder_end_coding: std_logic;
	signal mqcoder_bytes: std_logic_vector(23 downto 0);
	signal mqcoder_bytes_enable: std_logic_vector(2 downto 0);
	
	--shared and other stuff
	signal coordinate_gen_enable, coordinate_gen_force_disable: std_logic;
	signal memory_shift_enable: std_logic; --if set enables all memories and coordinate generator to continue shifting stuff
	signal current_bit, next_p3_bit, next_p1_bit, next_p2_bit: std_logic; --unused as output
	signal current_sign_bit: std_logic;
	
begin

	--context-gen
	-------------
	context_gen: entity work.ContextGenerator
		generic map (ROWS => ROWS, COLS => COLS)
		port map (
			raw_neighborhood => raw_neighborhood,
			subband => subband, row => row, col => col, 
			first_refinement_in => first_refinement_flag_curr,
			magnitude_refinement_context => magnitude_refinement_context, 
			sign_bit_decoding_context => sign_bit_decoding_context, 
			significance_propagation_context => significance_propagation_context,			
			sign_bit_xor => sign_bit_xor, is_strip_zero_context => is_strip_zero_context
		);
			
	coordinate_gen: entity work.CoordinateGenerator
		generic map (ROWS => ROWS, COLS => COLS, BITPLANES => BITPLANES - 1) -- -1 since the first bitplane is the sign plane and is encoded differently
		port map (
			clk => clk, rst => rst, clk_en => coordinate_gen_enable,
			row_out => row, col_out => col, bitplane_out => bitplane,
			pass_out => pass, done_out => coord_gen_done
		);
		
		
	significance_storage: entity work.SignificanceMatrix
		generic map(ROWS => ROWS, COLS => COLS)
		port map (
			clk => clk, rst => rst, clk_en => memory_shift_enable,
			in_value => significance_state_next,
			out_value => raw_neighborhood
		);
			
		
	first_refinement_flag_matrix: entity work.BooleanMatrix
		generic map (SIZE => ROWS * COLS)
		port map (
			clk => clk, rst => rst, clk_en => memory_shift_enable,
			in_value => first_refinement_flag_next,
			out_value => first_refinement_flag_curr
		);
		

		
	iscoded_flag_matrix: entity work.BooleanMatrixLookAhead
		generic map (SIZE => ROWS * COLS, LOOKAHEAD => 3)
		port map (
			clk => clk, rst => rst, clk_en => memory_shift_enable,
			in_value => iscoded_flag_next,
			out_values => iscoded_flag_stripe
		);
		
	iscoded_flag_curr <= iscoded_flag_stripe(3);
	full_strip_uncoded <= '1' when iscoded_flag_stripe = "0000" else '0';
		
									
	arithcoder: entity work.MQCoder
		port map (
			clk => clk, rst => rst, clk_en => mqcoder_enable,
			in_bit => mqcoder_in,
			end_coding_enable => mqcoder_end_coding,
			in_context => mqcoder_context_in,
			out_bytes => mqcoder_bytes,
			out_enable => mqcoder_bytes_enable
		);
		

		
	data_block: entity work.DataBlock
		generic map (ROWS => ROWS, COLS => COLS, BIT_DEPTH => BITPLANES)
		port map (
			clk => clk, rst => rst, clk_en => memory_shift_enable,
			data => data_stripe_raw
		);
		
	current_data <= data_stripe_raw(BITPLANES * 4 - 1 downto BITPLANES * 3);
	next_p1_data <= data_stripe_raw(BITPLANES * 3 - 1 downto BITPLANES * 2);
	next_p2_data <= data_stripe_raw(BITPLANES * 2 - 1 downto BITPLANES * 1);
	next_p3_data <= data_stripe_raw(BITPLANES - 1 downto 0);
		
		
	--static calculations
	current_bit <= shift_left(unsigned(current_data), bitplane + 1)(0);
	next_p1_bit <= shift_left(unsigned(next_p1_data), bitplane + 1)(0);
	next_p2_bit <= shift_left(unsigned(next_p2_data), bitplane + 1)(0);
	next_p3_bit <= shift_left(unsigned(next_p3_data), bitplane + 1)(0);
	strip_first_nonzero <= 0 when current_bit = '1' else
						   1 when next_p1_bit = '1' else
						   2 when next_p2_bit = '1' else
						   3 when next_p3_bit = '1' else
						   -1;
	current_sign_bit <= current_data(BITPLANES - 1);
		
	
	state_seq: process(clk, clk_en, rst) begin
		if (rst = '1') then
			state_current <= LOADING_4;
		elsif(rising_edge(clk) and clk_en = '1') then
			state_current <= state_next;
		end if;
	end process;
	
	
	state_comb: process(state_current, pass, iscoded_flag_curr, bitplane, 
			raw_neighborhood, mqcoder_bytes, mqcoder_bytes_enable, strip_first_nonzero,
			row, current_bit, significance_propagation_context, full_strip_uncoded,
			is_strip_zero_context, magnitude_refinement_context, col,
			current_sign_bit, sign_bit_decoding_context, sign_bit_xor,
			first_refinement_flag_curr, coordinate_gen_force_disable) begin
		--by default do not shift memories. Set if necessary
		memory_shift_enable <= '0';
		coordinate_gen_force_disable <= '0';
		--keep on same state unless otherwise specified
		state_next <= state_current;
		--mqcoder defaults
		mqcoder_in <= '0';
		mqcoder_context_in <= CONTEXT_UNIFORM;
		mqcoder_enable <= '0';
		mqcoder_end_coding <= '0';
		--default to clearing if on cleanup
		if (pass = CLEANUP) then
			iscoded_flag_next <= '0'; --reset iscoded flag
			first_refinement_flag_next <= '1'; --reset first refinement flag
		else --maintain previous
			iscoded_flag_next <= iscoded_flag_curr;
			first_refinement_flag_next <= first_refinement_flag_curr;
		end if;
		--default to clearing if on first cleanup pass. will be overriden if coding sign
		if (pass = CLEANUP and bitplane = 0) then
			significance_state_next <= INSIGNIFICANT;
		else
			significance_state_next <= raw_neighborhood.curr_c; --otherwise maintain existent
		end if;
		--default outputs
		out_bytes <= mqcoder_bytes;
		out_enable <= mqcoder_bytes_enable;
		busy <= '1';
		--first ref
		
		
		case (state_current) is
			when IDLE => --state for when this is finished until it is reset
				state_next <= IDLE;
				busy <= '0'; --al others do not set this and thus leave it at default ('1')
				
			when LOADING_4 =>
				coordinate_gen_force_disable <= '1';
				memory_shift_enable <= '1';
				state_next <= LOADING_3;
			when LOADING_3 =>
				coordinate_gen_force_disable <= '1';
				memory_shift_enable <= '1';
				state_next <= LOADING_2;
			when LOADING_2 =>
				coordinate_gen_force_disable <= '1';
				memory_shift_enable <= '1';
				state_next <= LOADING_1;
			when LOADING_1 =>
				coordinate_gen_force_disable <= '1';
				memory_shift_enable <= '1';
				state_next <= CODING_DEFAULT; 

			--burn states for when we need to advance the shifting memory
			--but do not need to do anything else
			when BURN_3 =>
				state_next <= BURN_2;
				memory_shift_enable <= '1';
			when BURN_2 =>
				state_next <= BURN_1;
				memory_shift_enable <= '1';
			when BURN_1 =>
				state_next <= CODING_DEFAULT;
				memory_shift_enable <= '1';
				
			--uniform states for coding the stripe stuff
			when UNIFORM_2 =>
				state_next <= UNIFORM_1;
				mqcoder_enable <= '1';
				if (strip_first_nonzero >= 2) then
					mqcoder_in <= '1';
				else
					mqcoder_in <= '0';
				end if;
				mqcoder_context_in <= CONTEXT_UNIFORM;
			when UNIFORM_1 =>
				memory_shift_enable <= '1'; --burn one here
				case (strip_first_nonzero) is
					when 0 => state_next <= CODING_DEFAULT;
					when 1 => state_next <= BURN_1;
					when 2 => state_next <= BURN_2;
					when 3 => state_next <= BURN_3;
					when others => state_next <= IDLE; --should not get here, but just in case to detect errors
				end case;

				mqcoder_enable <= '1';
				if (strip_first_nonzero mod 2 = 0) then
					mqcoder_in <= '0';
				else
					mqcoder_in <= '1';
				end if;
				mqcoder_context_in <= CONTEXT_UNIFORM;
				
			--default state, from this spawn the other branches
			when CODING_DEFAULT => 
				if (pass = CLEANUP) then
					if (row mod 4 /= 0) then
						if (iscoded_flag_curr = '0') then
							mqcoder_enable <= '1';
							mqcoder_in <= current_bit;
							mqcoder_context_in <= significance_propagation_context;
							if (current_bit = '1') then
								--if the sign bit is to be coded, just enable the coder, and then in the
								--sign bit coding step update memory values
								state_next <= CODING_SIGN;
							else
								--if no sign bit is to be encoded, set as coded, and shift memory
								state_next <= CODING_DEFAULT;
								memory_shift_enable <= '1';
							end if;
						end if;
					elsif (full_strip_uncoded = '1' and is_strip_zero_context = '1') then
						if (strip_first_nonzero = -1) then
							state_next <= BURN_3;
							memory_shift_enable <= '1';
							mqcoder_enable <= '1';
							mqcoder_in <= '0';
							mqcoder_context_in <= CONTEXT_RUN_LENGTH;
						else
							mqcoder_enable <= '1';
							mqcoder_in <= '1';
							mqcoder_context_in <= CONTEXT_RUN_LENGTH;
							state_next <= UNIFORM_2;
						end if;
					end if;
					
				elsif (pass = SIGNIFICANCE) then
					if (significance_propagation_context /= CONTEXT_ZERO) then
						mqcoder_enable <= '1';
						mqcoder_in <= current_bit;
						mqcoder_context_in <= significance_propagation_context;
						if (current_bit = '1') then
							--if the sign bit is to be coded, just enable the coder, and then in the
							--sign bit coding step update memory values
							state_next <= CODING_SIGN;
						else
							--if no sign bit is to be encoded, set as coded, and shift memory
							state_next <= CODING_DEFAULT;
							iscoded_flag_next <= '1';
							memory_shift_enable <= '1';
						end if;
					end if;
				else --refinement
					state_next <= CODING_DEFAULT;
					memory_shift_enable <= '1';
					first_refinement_flag_next <= '0';
					if (iscoded_flag_curr = '0' and raw_neighborhood.curr_c /= INSIGNIFICANT) then
						iscoded_flag_next <= '1';
						mqcoder_enable <= '1';
						mqcoder_in <= current_bit;
						mqcoder_context_in <= magnitude_refinement_context;
					end if;
				end if;
				--check for end of bounds and go to next state
				if (row = ROWS - 1 and col = COLS - 1 and pass = CLEANUP and bitplane = BITPLANES - 2) then -- -2 since there are BITPLANES - 1 planes (plus the sign plane)
					state_next <= DUMPING_REMAINING; --TODO this is not idle, we need to DUMP bits and MARK STREAM before
				end if;
			
			--code sign. can come here from significance or cleanup passes
			when CODING_SIGN =>
				state_next <= CODING_DEFAULT;
				memory_shift_enable <= '1';
				mqcoder_enable <= '1';
				if (current_sign_bit = '1') then
					significance_state_next <= SIGNIFICANT_NEGATIVE;
				else
					significance_state_next <= SIGNIFICANT_POSITIVE;
				end if;
				mqcoder_context_in <= sign_bit_decoding_context;
				mqcoder_in <= current_sign_bit xor sign_bit_xor;
				--if on cleanup pass, clear iscoded flag for next round. If not, set it for further passes
				if (pass /= CLEANUP) then --set as coded if on significance (refinement does not come here)
					iscoded_flag_next <= '1';
				end if;
				
				
			when DUMPING_REMAINING =>
				state_next <= MARKING_END; --
				mqcoder_end_coding <= '1';
				
			when MARKING_END => --need one extra state since the MQCODER is delayed by one clock cycle
				state_next <= FINISHED;
				
			when FINISHED =>
				--just raw output the end of stream (EOS) marker
				out_bytes <= "000000001111111111111110";
				out_enable <= "011";
				state_next <= IDLE;
				
		end case;
	end process;	
	
	coordinate_gen_ctrl: process(coordinate_gen_force_disable, memory_shift_enable) begin
		--disable coordinate gen if shifting data to have first four samples
		if (coordinate_gen_force_disable = '1') then
			coordinate_gen_enable <= '0';
		else
			coordinate_gen_enable <= memory_shift_enable;
		end if;
	end process;
		
end Behavioral;
