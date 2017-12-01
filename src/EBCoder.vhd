----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel B�scones
-- 
-- Create Date: 24.10.2017 17:33:38
-- Design Name: 
-- Module Name: EBCoder - Behavioral
-- Project Name: Vypec
-- Target Devices: 
-- Tool Versions: 
-- Description: Module that encapsulates the full Block Coding 
-- 		functionality of the JPEG2000 standard.
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


-- Coder entity. Receives control signal, outputs the generated bytes
-- and corresponding flags for each if they are to be read. Note that
-- outputs can range from 0 to 3 bytes.
entity EBCoder is
	generic (
		--number of rows in this block. Must be multiple of 4
		ROWS: integer := 64;		
		--number of columns in this block. Must be greater than 4
		COLS: integer := 64;		
		--number of bitplanes (depth) of the input data, which format is sign-magnitude
		BITPLANES: integer := 16
	);
	port (
		--control signals
		clk, rst, clk_en: in std_logic;					
		--input data
		data_in: in std_logic_vector(BITPLANES - 1 downto 0);
		data_in_en: in std_logic;
		--active if the module has not processed the current block yet
		busy: out std_logic;						
		--current output (valid only if out_enable is active)
		out_bytes: out std_logic_vector(23 downto 0);	
		--if set, the corresponding byte of out_bytes must be read in the next clk edge or it will be lost
		valid: out std_logic_vector(2 downto 0)	
	);
end EBCoder;

architecture Behavioral of EBCoder is
	
	--inner state of the coder
	type ebcoder_state_t is (
		--first thing the coder has to do is read four samples from memory since 
		--it needs to look ahead that many. These initial states ensure that
		LOADING_4, 
		LOADING_3, 
		LOADING_2, 
		LOADING_1, 
		--default state when coding. this codes any pass (significance, refinement
		--or cleanup). If a spetial case of coding is found (sing codign, run length
		--etc) then the state changes to one of the states below)
		CODING_DEFAULT, 
		--after the first magnitude bit of a sample is coded, we code its sign bit 
		CODING_SIGN, 
		--when coding a run of zeros, we might have to jump over some samples, these
		--states allow that. They differ from the LOADING states in that SKIP states
		--update the coordinate counter, while LOADING states do not.
		--after a skip_thensign state, the sign bit of the current sample is coded
		SKIP_3_THEN_SIGN, 
		SKIP_2_THEN_SIGN, 
		SKIP_1_THEN_SIGN, 
		--after a skip state, coding resumes as usual
		SKIP_3,
		SKIP_2,
		SKIP_1,
		--if a run length coding is interrupted, UNIFORM states code the pointer to the
		--sample that interrupted it
		UNIFORM_2, 
		UNIFORM_1, 
		--after coding the whole block, this state ensures the last bits remaining in the 
		--buffers are output
		DUMPING_REMAINING, 
		--marks the end of the stream with a spetial ending code that, by design,
		--can not appear inside the coded stream. In this state the MQCODER is 
		--sent a flag to terminate.
		MARKING_END, 
		--now the MQCODER has terminated, and the end of stream marker is output
		FINISHED,
		--IDLE state, waiting for a reset, after which it is assumed that the
		--coding block is loaded with new information to be coded, and coding starts
		IDLE);
		
	--current state and combinatorial next state
	signal state_current, state_next: ebcoder_state_t;
	
	--indicates the significant state of the neighbors of the current coordinate
	signal raw_neighborhood: sign_neighborhood_t;
	--stores the next significant state for the current coordinate. This will be
	--passed to the neighborhood above
	signal significance_state_next, significance_state_curr: significance_state_t;
	signal neighborhood: neighborhood_3x3_t;
	signal run_length_neighborhood: sign_neighborhood_t;
	
	--flag that indicates if the current coordinate is being refined for the first
	--time or not
	signal first_refinement_flag_curr, first_refinement_flag_curr_mem: std_logic;
	signal first_refinement_flag_next: std_logic; --unused as output
	
	--flag indicating if the current coordinate has already been coded or not
	--we also have the full strip for when run_length coding
	signal iscoded_flag_curr: std_logic; --unused as input
	signal iscoded_flag_strip_mem, iscoded_flag_strip: std_logic_vector(3 downto 0);
	signal iscoded_flag_next: std_logic; --unused as output
	signal full_strip_uncoded: std_logic;
	
	--raw data for the current strip
	signal data_available: std_logic;
	signal data_strip_raw: std_logic_vector(BITPLANES * 4 - 1 downto 0);
	signal current_data, next_p3_data, next_p1_data, next_p2_data: std_logic_vector(BITPLANES - 1 downto 0);

	--context gen outputs
	constant subband: subband_t := LL;
	signal magnitude_refinement_context, sign_bit_decoding_context, significance_propagation_context: context_label_t; --unused as input
	signal sign_bit_xor: std_logic; --unused as input
	signal is_strip_zero_context: std_logic; --unused as input
	signal strip_first_nonzero: integer range -1 to 3; -- -1 if there is no nonzero, 0-1-2-3 indicate the index of the first nonzero 
	
	--coord gen outputs
	signal row: natural range 0 to ROWS - 1;
	signal col: natural range 0 to COLS - 1;
	signal bitplane: natural range 0 to BITPLANES - 2; -- -2 since one is for sign, rest for magnitude, and we are only interested in sign here
	signal pass: encoder_pass_t; 
	signal coord_gen_done: std_logic;
	signal first_cleanup_pass: std_logic;
	
	--MQCoder stuff
	signal mqcoder_in: std_logic;
	signal mqcoder_context_in: context_label_t; --unused as output
	signal mqcoder_enable: std_logic;
	signal mqcoder_end_coding: std_logic;
	signal mqcoder_bytes: std_logic_vector(23 downto 0);
	signal mqcoder_bytes_enable, out_enable: std_logic_vector(2 downto 0);
	
	----shared and other stuff
	--enable coordinate generation. this guides the coding process, and is used
	--to advance it or not depending on the state
	signal coordinate_gen_enable, coordinate_gen_force_disable: std_logic;
	--if set enables all memories and coordinate generator to continue shifting stuff
	signal memory_shift_enable: std_logic; 
	--bits from the current sample and four ahead for run length coding
	signal current_bit, next_p3_bit, next_p1_bit, next_p2_bit: std_logic; 
	--sign bit of the current sample
	signal current_sign_bit: std_logic;
	
begin

	
	sign_filter: entity work.SignificanceNeighFilter
		generic map (ROWS => ROWS, COLS => COLS)
		port map (
			raw_neighborhood => raw_neighborhood,
			row => row, col => col, first_cleanup_pass_flag => first_cleanup_pass,
			current_significance => significance_state_curr,
			neighborhood => neighborhood,
			run_length_neighborhood => run_length_neighborhood
		);
	

	--context generator
	--generates the different contexts using the neighborhood of the current sample
	--plus other useful flags
	context_gen: entity work.ContextGenerator
		generic map (ROWS => ROWS, COLS => COLS)
		port map (
			neighborhood => neighborhood,
			run_length_neighborhood => run_length_neighborhood,
			subband => subband,
			first_refinement_in => first_refinement_flag_curr,
			magnitude_refinement_context => magnitude_refinement_context, 
			sign_bit_decoding_context => sign_bit_decoding_context, 
			significance_propagation_context => significance_propagation_context,			
			sign_bit_xor => sign_bit_xor, is_strip_zero_context => is_strip_zero_context
		);
	
	--coordinate generator
	--generates the current position and passes through the block to guide the coding process
	coordinate_gen: entity work.CoordinateGenerator
		generic map (
			ROWS => ROWS, 
			COLS => COLS, 
			-- -1 since the first bitplane is the sign plane and is encoded differently
			BITPLANES => BITPLANES - 1) 
		port map (
			clk => clk, rst => rst, clk_en => coordinate_gen_enable,
			row_out => row, col_out => col, bitplane_out => bitplane,
			pass_out => pass, last_coord => coord_gen_done
		);
		
	first_cleanup_pass <= '1' when bitplane = 0 and pass = CLEANUP else '0';
		
	--significance matrix storage
	--stores significance states of all the block samples
	significance_storage: entity work.SignificanceMatrix
		generic map(ROWS => ROWS, COLS => COLS)
		port map (
			clk => clk, rst => rst, clk_en => memory_shift_enable,
			in_value => significance_state_next,
			out_value => raw_neighborhood
		);
			
	--first refinement matrix storage
	--stores flags for all positions indicanting if the value behind it
	--is being refined for the first time or not
	first_refinement_flag_matrix: entity work.BooleanMatrix
		generic map (SIZE => ROWS * COLS)
		port map (
			clk => clk, rst => rst, clk_en => memory_shift_enable,
			in_value => first_refinement_flag_next,
			out_value => first_refinement_flag_curr_mem
		);
		
	first_refinement_flag_curr <= first_refinement_flag_curr_mem when bitplane /= 0 else '1';
		
	--is coded flag matrix storage
	--stores flags indicating, for each position, if it is coded already in this pass
	iscoded_flag_matrix: entity work.BooleanMatrixLookAhead
		generic map (SIZE => ROWS * COLS, LOOKAHEAD => 3)
		port map (
			clk => clk, rst => rst, clk_en => memory_shift_enable,
			in_value => iscoded_flag_next,
			out_values => iscoded_flag_strip_mem
		);
		
	--on the first bitplane set as zero by default, otherwise use stored values
	iscoded_flag_strip <= iscoded_flag_strip_mem when bitplane /= 0 else "0000";
	iscoded_flag_curr <= iscoded_flag_strip(3);
	full_strip_uncoded <= '1' when iscoded_flag_strip = "0000" else '0';
		
	--aritmetic coder
	--holds internal states with probabilities for each coding context.
	--arithmetically codes the required bits, generating up to 3 bytes 
	--at the same time (though usually this number will be zero or one)						
	arithcoder: entity work.MQCoder
		port map (
			clk => clk, rst => rst, clk_en => mqcoder_enable,
			in_bit => mqcoder_in,
			end_coding_enable => mqcoder_end_coding,
			in_context => mqcoder_context_in,
			out_bytes => mqcoder_bytes,
			out_enable => mqcoder_bytes_enable
		);
		
	--data block storage
	--holds the data to be coded. 
	data_block: entity work.DataBlock
		generic map (ROWS => ROWS, COLS => COLS, BIT_DEPTH => BITPLANES)
		port map (
			clk => clk, rst => rst, 
			data_in => data_in,
			data_in_en => data_in_en,
			data_out_en => memory_shift_enable,
			data_out => data_strip_raw,
			data_out_available => data_available
		);
		
		
	current_data <= data_strip_raw(BITPLANES * 4 - 1 downto BITPLANES * 3);
	next_p1_data <= data_strip_raw(BITPLANES * 3 - 1 downto BITPLANES * 2);
	next_p2_data <= data_strip_raw(BITPLANES * 2 - 1 downto BITPLANES * 1);
	next_p3_data <= data_strip_raw(BITPLANES - 1 downto 0);
		
		
	--static calculations
	current_bit <= shift_left(unsigned(current_data), bitplane + 1)(BITPLANES - 1);
	next_p1_bit <= shift_left(unsigned(next_p1_data), bitplane + 1)(BITPLANES - 1);
	next_p2_bit <= shift_left(unsigned(next_p2_data), bitplane + 1)(BITPLANES - 1);
	next_p3_bit <= shift_left(unsigned(next_p3_data), bitplane + 1)(BITPLANES - 1);
	strip_first_nonzero <= 0 when current_bit = '1' else
						   1 when next_p1_bit = '1' else
						   2 when next_p2_bit = '1' else
						   3 when next_p3_bit = '1' else
						   -1;
	current_sign_bit <= current_data(BITPLANES - 1);
	valid <= out_enable 
				when mqcoder_enable = '1' 
				or state_current = DUMPING_REMAINING 
				or state_current = MARKING_END 
				or state_current = FINISHED 
			else 
				(others => '0');

		
	--FSM update process
	state_seq: process(clk, clk_en, rst) begin
		--debug
--		if (rising_edge(clk)) then
--			report "Current state: " & ebcoder_state_t'image(state_current) & " -> " & ebcoder_state_t'image(state_next) & LF
--				& "Flags: (frf, if, fsu, szc) -> " 
--					& std_logic'image(first_refinement_flag_curr) & "," 
--					& std_logic'image(iscoded_flag_curr) & "," 
--					& std_logic'image(full_strip_uncoded) & ","
--					& std_logic'image(is_strip_zero_context) & "," & LF
--				& "Data: (c, p1, p2, p3) -> "
--					& integer'image(to_integer(unsigned(current_data))) & ","											   
--					& integer'image(to_integer(unsigned(next_p1_data))) & ","		
--					& integer'image(to_integer(unsigned(next_p2_data))) & ","		
--					& integer'image(to_integer(unsigned(next_p3_data))) & "," & LF
--				& "Coords: (row, col, fnz) -> "
--					& integer'image(row) & ","
--					& integer'image(col) & ","
--					& integer'image(strip_first_nonzero) & "," & LF
--				& "Coder: (bin, cin, enable) -> "
--					& std_logic'image(mqcoder_in) & "," 
--					& context_label_t'image(mqcoder_context_in) & "," 
--					& std_logic'image(mqcoder_enable) & "," & LF;
--		end if;
		if (rst = '1') then
			state_current <= LOADING_4;
		elsif(rising_edge(clk) and clk_en = '1') then
			state_current <= state_next;
		end if;
	end process;
	

	
	--this process ties all modules together, generating flags
	--and state transitions
	state_comb: process(state_current, pass, iscoded_flag_curr, bitplane, 
			raw_neighborhood, mqcoder_bytes, mqcoder_bytes_enable, strip_first_nonzero,
			row, current_bit, significance_propagation_context, full_strip_uncoded,
			is_strip_zero_context, magnitude_refinement_context, col,
			current_sign_bit, sign_bit_decoding_context, sign_bit_xor,
			first_refinement_flag_curr, coordinate_gen_force_disable, data_available, coord_gen_done) begin
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
			significance_state_next <= significance_state_curr; --otherwise maintain existent
		end if;
		--default outputs
		out_bytes <= mqcoder_bytes;
		out_enable <= mqcoder_bytes_enable;
		busy <= '1';
		--first ref
		
		--only perform stuff if data is available, otherwise don't (obviously)
		if (data_available = '1') then
			case (state_current) is
				when IDLE => --state for when this is finished until it is reset
					state_next <= IDLE;
					busy <= '0'; --al others do not set this and thus leave it at default ('1')
					
				--Loading states so that when the coder starts, it can load the first strip 
				--(needed for looking ahead and knowing if it can be runlength coded)
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
	
				--skip states for when we need to advance the shifting memory
				--and after that code the sign of the current sample
				when SKIP_3_THEN_SIGN =>
					state_next <= SKIP_2_THEN_SIGN;
					memory_shift_enable <= '1';
				when SKIP_2_THEN_SIGN =>
					state_next <= SKIP_1_THEN_SIGN;
					memory_shift_enable <= '1';
				when SKIP_1_THEN_SIGN =>
					state_next <= CODING_SIGN;
					memory_shift_enable <= '1';
					
				--skip states for just skipping over, then proceeding as usual
				when SKIP_3 =>
					state_next <= SKIP_2;
					memory_shift_enable <= '1';
				when SKIP_2 =>
					state_next <= SKIP_1;
					memory_shift_enable <= '1';
				when SKIP_1 =>
					memory_shift_enable <= '1';
					--check for end of bounds and go to next state
					if (coord_gen_done = '1') then 
						state_next <= DUMPING_REMAINING;
					else
						state_next <= CODING_DEFAULT;
					end if;
					
					
				--uniform states for coding the strip stuff
				when UNIFORM_2 =>
					state_next <= UNIFORM_1;
					--code the MSB of the nonzero index
					mqcoder_enable <= '1';
					if (strip_first_nonzero >= 2) then
						mqcoder_in <= '1';
					else
						mqcoder_in <= '0';
					end if;
					mqcoder_context_in <= CONTEXT_UNIFORM;
				when UNIFORM_1 =>
					--code current sign, or jump to failed position and code its sign
					--after which we can continue as usual
					case (strip_first_nonzero) is
						when 0 => state_next <= CODING_SIGN;
						when 1 => state_next <= SKIP_1_THEN_SIGN;
						when 2 => state_next <= SKIP_2_THEN_SIGN;
						when 3 => state_next <= SKIP_3_THEN_SIGN;
						when others => state_next <= IDLE; --should not get here, but just in case to detect errors
					end case;
					
					--code the LSB of the nonzero index
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
						if (row mod 4 = 0 and full_strip_uncoded = '1' and is_strip_zero_context = '1') then
							if (strip_first_nonzero = -1) then
								--skip one sample (current) then skip 3 more
								--so that we are right on the next strip
								memory_shift_enable <= '1';
								state_next <= SKIP_3;
								--run length code these 4 zero bits
								mqcoder_enable <= '1';
								mqcoder_in <= '0';
								mqcoder_context_in <= CONTEXT_RUN_LENGTH;
							else
								--if the strip has a nonzero bit, code a fail in the run length context
								mqcoder_enable <= '1';
								mqcoder_in <= '1';
								mqcoder_context_in <= CONTEXT_RUN_LENGTH;
								--jump to uniform state so that the pointer to the nonzero bit is coded, 
								--and then the algorithm proceeds as usual
								state_next <= UNIFORM_2;
							end if;
						else 
							if (iscoded_flag_curr = '0') then
								mqcoder_enable <= '1';
								mqcoder_in <= current_bit;
								mqcoder_context_in <= significance_propagation_context;
								if (current_bit = '1') then
									--if the sign bit is to be coded, just enable the coder, and then in the
									--sign bit coding step update memory values
									state_next <= CODING_SIGN;
								else
									--if no sign bit is to be encoded, set as coded (already done by default), and shift memory
									memory_shift_enable <= '1';
									if (coord_gen_done = '1') then 
										state_next <= DUMPING_REMAINING;
									end if;
								end if;
							else --no coding to be done, shift memory
								memory_shift_enable <= '1';
								if (coord_gen_done = '1') then 
									state_next <= DUMPING_REMAINING;
								end if;
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
						else	--no coding to be done, shift memory
							memory_shift_enable <= '1';
						end if;
					else --refinement
						state_next <= CODING_DEFAULT;
						memory_shift_enable <= '1';
						first_refinement_flag_next <= '0';
						if (iscoded_flag_curr = '0' and significance_state_curr /= INSIGNIFICANT) then
							iscoded_flag_next <= '1';
							mqcoder_enable <= '1';
							mqcoder_in <= current_bit;
							mqcoder_context_in <= magnitude_refinement_context;
						end if;
					end if;
	
				
				--code sign. can come here from significance or cleanup passes
				when CODING_SIGN =>
					--check for end of bounds and go to next state
					if (coord_gen_done = '1') then 
						state_next <= DUMPING_REMAINING;
					else
						state_next <= CODING_DEFAULT;
					end if;
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
					mqcoder_enable <= '1';
					
				when MARKING_END => --need one extra state since the MQCODER is delayed by one clock cycle
					state_next <= FINISHED;
					
				when FINISHED =>
					--just raw output the end of stream (EOS) marker
					out_bytes <= "000000001111111111111110";
					out_enable <= "011";
					state_next <= IDLE;
					
			end case;
		end if;
	end process;	
	
	--coordinate generation control
	coordinate_gen_ctrl: process(coordinate_gen_force_disable, memory_shift_enable) begin
		--disable coordinate gen if shifting data to have first four samples
		if (coordinate_gen_force_disable = '1') then
			coordinate_gen_enable <= '0';
		else
			coordinate_gen_enable <= memory_shift_enable;
		end if;
	end process;
		
end Behavioral;
