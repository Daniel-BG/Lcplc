----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:50:20 06/06/2018 
-- Design Name: 
-- Module Name:    BPC - Behavioral 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity BPC is
	generic (
		--number of strips
		STRIPS: integer := 16;
		--number of stripes
		COLS: integer := 64;
		--number of bitplanes (excluding sign plane)
		BITPLANES: integer := 15
	);
	port (
		clk, rst, clk_en: in std_logic;
		input: in std_logic_vector((BITPLANES+1)*4 - 1 downto 0);
		input_loc: in natural range 0 to COLS*STRIPS - 1;
		input_en: in std_logic;
		out_contexts: out BPC_out_contexts_t;
		--in SIGNIFICANCE CxD pairs can occupy the first 8 positions
		--in REF only 4
		--in CLEANUP up to 10
		out_bits: out BPC_out_bits_t;
		out_valid: out BPC_out_valid_t;
		out_done_next_cycle: out std_logic
	);
end BPC;

architecture Behavioral of BPC is
	--constants
	constant subband: subband_t := LL;
	
	--metasignals
	signal enabled, clk_en_except_first: std_logic;
	
	
	--sample signals
	signal s0, s1, s2, s3: std_logic_vector(BITPLANES downto 0); --one extra for sign
	signal sign_bit, magnitude_bit: bit_strip;

	--coord gen signals
	signal curr_strip: natural range 0 to STRIPS - 1;
	signal curr_col: natural range 0 to COLS - 1;
	signal curr_bitplane: natural range 0 to BITPLANES - 1;
	signal curr_pass: encoder_pass_t;
	signal last_coord: std_logic;
	
	--significance signals
	signal raw_neighborhood, full_neighborhood: run_length_neighborhood_t;
	signal full_neighborhood_matrix: significance_matrix; --just an easier way to deal with full_neigh
	signal next_significance: significance_strip;
	
	--context generation signals
	signal neighborhood: neigh_strip;
	signal magnitude_refinement_context, sign_bit_decoding_context, significance_propagation_context: context_strip;
	signal sign_bit_xor: bit_strip;
	
	--filter signals
	signal first_cleanup_pass_flag: std_logic;
	
	--iscoded signals
	signal iscoded_flag_raw, iscoded_flag_out, iscoded_flag_in: std_logic_vector(3 downto 0);
	
	--first refinement signals
	signal first_refinement_vector_in: std_logic_vector(3 downto 0);
	signal first_refinement_vector_out: std_logic_vector(3 downto 0);
	
	--significance coded flags
	signal significance_coded_flag: bit_strip;
	signal significance_coded_flag_significance, significance_aquired_flag_significance, significance_aquired_flag_cleanup: bit_strip;
	signal significance_aquired_significance, significance_aquired_cleanup: significance_strip;
	
	--cleanup signals
	signal all_bits_zero_flag: std_logic;
	signal first_nonzero: natural range 0 to 3;
	--signal strip_zero_context_flag: std_logic;
	--signal strip_all_uncoded_flag: std_logic;
	signal run_length_flag: std_logic;
	
	
	--output for all passes, which will be multiplexed
	signal out_contexts_significance, out_contexts_refinement, out_contexts_cleanup: BPC_out_contexts_t;
	signal out_bits_significance, out_bits_refinement, out_bits_cleanup: BPC_out_bits_t;
	signal out_valid_significance, out_valid_refinement, out_valid_cleanup: BPC_out_valid_t;
		
begin
	out_done_next_cycle <= last_coord;
	
	delay_clk_en: process(clk, clk_en, rst)
	begin
		if rising_edge(clk) then
			if (rst = '1') then
				enabled <= '0';
			elsif (clk_en = '1') then
				enabled <= '1';
			end if;
		end if;
	end process;
	clk_en_except_first <= '0' when enabled = '0' else clk_en;
	
	--ALIASES
	----------------------------------
	--(0) (1) (2) ---(pm1)(pp3)(pp7)--
	--(3) (4) (5) ---(cm4)(c_c)(cp4)--
	--(6) (7) (8) ---(cm3)(cp1)(cp5)--
	--(9) (10)(11)---(cm2)(cp2)(cp6)--
	--(12)(13)(14)---(cm1)(cp3)(cp7)--
	--(15)(16)(17)---(nm4)(n_c)(np4)--
	----------------------------------
	full_neighborhood_matrix(0)	<= full_neighborhood.prev_m1;
	full_neighborhood_matrix(1)	<= full_neighborhood.prev_p3;
	full_neighborhood_matrix(2)	<= full_neighborhood.prev_p7;
	full_neighborhood_matrix(3)	<= full_neighborhood.curr_m4;
	full_neighborhood_matrix(4)	<= full_neighborhood.curr_c;
	full_neighborhood_matrix(5)	<= full_neighborhood.curr_p4;
	full_neighborhood_matrix(6)	<= full_neighborhood.curr_m3;
	full_neighborhood_matrix(7)	<= full_neighborhood.curr_p1;
	full_neighborhood_matrix(8)	<= full_neighborhood.curr_p5;
	full_neighborhood_matrix(9)	<= full_neighborhood.curr_m2;
	full_neighborhood_matrix(10)<= full_neighborhood.curr_p2;
	full_neighborhood_matrix(11)<= full_neighborhood.curr_p6;
	full_neighborhood_matrix(12)<= full_neighborhood.curr_m1;
	full_neighborhood_matrix(13)<= full_neighborhood.curr_p3;
	full_neighborhood_matrix(14)<= full_neighborhood.curr_p7;
	full_neighborhood_matrix(15)<= full_neighborhood.next_m4;
	full_neighborhood_matrix(16)<= full_neighborhood.next_c;
	full_neighborhood_matrix(17)<= full_neighborhood.next_p4;
	
	
	sign_bit(0) <= s0(BITPLANES);
	sign_bit(1) <= s1(BITPLANES);
	sign_bit(2) <= s2(BITPLANES);
	sign_bit(3) <= s3(BITPLANES);
	magnitude_bit(0) <= shift_left(unsigned(s0), curr_bitplane + 1)(BITPLANES);
	magnitude_bit(1) <= shift_left(unsigned(s1), curr_bitplane + 1)(BITPLANES);
	magnitude_bit(2) <= shift_left(unsigned(s2), curr_bitplane + 1)(BITPLANES);
	magnitude_bit(3) <= shift_left(unsigned(s3), curr_bitplane + 1)(BITPLANES);
	
	sample_mem: entity work.BPC_mem
	generic map (WIDTH => COLS, STRIPS => STRIPS, BIT_DEPTH => BITPLANES + 1)
	port map (
		rst => rst, clk => clk, clk_en => clk_en,
		input => input,
		input_loc => input_loc,
		input_en => input_en,
		s0 => s0, s1 => s1, s2 => s2, s3 => s3
	);

	coordinate_gen: entity work.BPC_coord_gen
		generic map(
			STRIPS => STRIPS, COLS => COLS, BITPLANES => BITPLANES
		)
		port map(
			clk => clk, rst => rst, clk_en => clk_en_except_first,
			strip_out => curr_strip,
			col_out => curr_col,
			bitplane_out => curr_bitplane,
			pass_out => curr_pass,
			last_coord => last_coord
		);


	significance_storage: entity work.BPC_significance_storage
		generic map(
			STRIPS => STRIPS, COLS => COLS
		)
		port map(
			clk => clk, rst => rst, clk_en => clk_en,
			in_value_0 => next_significance(0),
			in_value_1 => next_significance(1),
			in_value_2 => next_significance(2),
			in_value_3 => next_significance(3),
			out_value  => raw_neighborhood
		);
		
	first_cleanup_pass_flag <= '1' when curr_pass = CLEANUP and curr_bitplane = 0 else '0';
		
	significance_filter: entity work.BPC_sign_filter
		generic map(
			STRIPS => STRIPS, COLS => COLS
		)
		port map (
			raw_neighborhood => raw_neighborhood,
			strip => curr_strip,
			col => curr_col,
			first_cleanup_pass_flag => first_cleanup_pass_flag,
			run_length_neighborhood => full_neighborhood
		);
		
	iscoded_flag_matrix: entity work.BPC_flag_matrix
		generic map(SIZE => COLS * STRIPS, WIDTH => 4)
		port map (
			clk => clk, rst => rst, clk_en => clk_en,
			in_value => iscoded_flag_in,
			out_value => iscoded_flag_raw
		);	
		
	first_refinement_flag_matrix: entity work.BPC_flag_matrix
		generic map(SIZE => COLS * STRIPS, WIDTH => 4)
		port map (
			clk => clk, rst => rst, clk_en => clk_en,
			in_value => first_refinement_vector_in,
			out_value => first_refinement_vector_out
		);	
		
	fast_sign_change_predictor: entity work.BPC_fast_significance_change_prediction
		port map (
			neighborhood => full_neighborhood_matrix,
			bits => magnitude_bit,
			sign => sign_bit,
			is_significance_coded => significance_coded_flag_significance,
			becomes_significant => significance_aquired_flag_significance, --maybe tell which ones are enabled? (e.g: significance => all, cleanup => from jth)
			significance => significance_aquired_significance
		);
		
	fast_sign_cleanup: entity work.BPC_fast_significance_cleanup
		port map (
			neighborhood => full_neighborhood_matrix,
			bits => magnitude_bit,
			sign => sign_bit,
			first_nonzero => first_nonzero,
			all_bits_zero => all_bits_zero_flag,
			iscoded_flag => iscoded_flag_out,
			becomes_significant => significance_aquired_flag_cleanup,
			significance => significance_aquired_cleanup
		);
		
	
	--SIGNIFICANCE AND REFINEMENT PASSES CALCULATIONS
	gen_context_formation: for i in 0 to 3 generate
		--iscoded 
		iscoded_flag_out(i) <= '0' when curr_bitplane = 0 else iscoded_flag_raw(i);
		--top case is cascaded and cannot be directly connected
		first_case: if i = 0 generate
			neighborhood(0).top	<= full_neighborhood.prev_p3;
		end generate;
		
		general_case: if i /= 0 generate
			neighborhood(i).top	<= next_significance(i-1);
		end generate;
		--the rest will not change even after emmiting CxD pairs
		neighborhood(i).top_left		<= full_neighborhood_matrix(0+i*3);
		neighborhood(i).top_right		<= full_neighborhood_matrix(2+i*3);
		neighborhood(i).left				<= full_neighborhood_matrix(3+i*3);
		neighborhood(i).right			<= full_neighborhood_matrix(5+i*3);
		neighborhood(i).bottom_left	<= full_neighborhood_matrix(6+i*3);
		neighborhood(i).bottom			<= full_neighborhood_matrix(7+i*3);
		neighborhood(i).bottom_right	<= full_neighborhood_matrix(8+i*3);
		
		ctx_gen_i: entity work.BPC_3x3_context_gen
			port map(
				neighborhood => neighborhood(i),
				subband => subband,
				first_refinement_in => first_refinement_vector_out(i),
				magnitude_refinement_context => magnitude_refinement_context(i),
				sign_bit_decoding_context => sign_bit_decoding_context(i),
				significance_propagation_context => significance_propagation_context(i),
				sign_bit_xor => sign_bit_xor(i)
			);

		--this flag means that significance coding is to be applied to the i-th sample. This DOES mean the sample becomes significant
		significance_coded_flag(i) <= '1' when (curr_pass = SIGNIFICANCE and significance_coded_flag_significance(i) = '1')
														or	(curr_pass = CLEANUP and (run_length_flag = '0' or (run_length_flag = '1' and significance_aquired_flag_cleanup(i) = '1')))
												else '0';
			
		--significance value of the i-th sample after the current cycle is done processing. 
		--This is also used for cascading significance down the strip
		--avoid updating when in refinement
		next_significance(i) <= significance_aquired_significance(i) when curr_pass = SIGNIFICANCE else
										full_neighborhood_matrix(4+3*i) when curr_pass = REFINEMENT else
										significance_aquired_cleanup(i); 
			
		--flag indicating that the i-th bit is being coded, and no further passes should code it. CLEANUP pass resets this flag to recycle the flag matrix
		iscoded_flag_in(i) <= '1' when (curr_pass = SIGNIFICANCE and significance_coded_flag(i) = '1')
										  or   (curr_pass = REFINEMENT and (iscoded_flag_out(i) = '1' or full_neighborhood_matrix(4+3*i) /= INSIGNIFICANT))
										  else '0';
		
		--flag indicating it is the first time this position is refined
		first_refinement_vector_in(i) <= '1' when curr_pass = CLEANUP and curr_bitplane = 0 else
													'0' when curr_pass = REFINEMENT and full_neighborhood_matrix(4+3*i) /= INSIGNIFICANT and iscoded_flag_out(i) = '0' else
													first_refinement_vector_out(i);
	
	end generate;
	
	--CLEANUP CALCULATIONS
	
	all_bits_zero_flag <= '1' when magnitude_bit(0) = '0' and magnitude_bit(1) = '0' and magnitude_bit(2) = '0' and magnitude_bit(3) = '0' 
									  else '0';
	--strip_all_uncoded_flag <= '1' when iscoded_flag_out(0) = '0' and iscoded_flag_out(1) = '0' and iscoded_flag_out(2) = '0' and iscoded_flag_out(3) = '0'
	--										else '0';
									  
	--note that this is 3 even when all are zeroes, that is what the all_bits_zero_flag is for
	first_nonzero <=	0 when magnitude_bit(0) = '1' else
							1 when magnitude_bit(1) = '1' else
							2 when magnitude_bit(2) = '1' else
							3;
							
	--this will assume a strip even if we are in the middle of one
	strip_zero_context: process(full_neighborhood, iscoded_flag_out)
	begin
		--this is basically a 6x3 rectangle in which all samples are checked for significance
		--if all are insignificant, then the whole strip is
		if (	full_neighborhood.curr_m4 = INSIGNIFICANT and full_neighborhood.curr_m3 = INSIGNIFICANT and
				full_neighborhood.curr_m2 = INSIGNIFICANT and full_neighborhood.curr_m1 = INSIGNIFICANT and
				full_neighborhood.curr_c  = INSIGNIFICANT and full_neighborhood.curr_p1 = INSIGNIFICANT and
				full_neighborhood.curr_p2 = INSIGNIFICANT and full_neighborhood.curr_p3 = INSIGNIFICANT and
				full_neighborhood.curr_p4 = INSIGNIFICANT and full_neighborhood.curr_p5 = INSIGNIFICANT and
				full_neighborhood.curr_p6 = INSIGNIFICANT and full_neighborhood.curr_p7 = INSIGNIFICANT and
				full_neighborhood.prev_m1 = INSIGNIFICANT and full_neighborhood.prev_p3 = INSIGNIFICANT and
				full_neighborhood.prev_p7 = INSIGNIFICANT and full_neighborhood.next_m4 = INSIGNIFICANT and
				full_neighborhood.next_c  = INSIGNIFICANT and full_neighborhood.next_p4 = INSIGNIFICANT and
				iscoded_flag_out(0) = '0' and iscoded_flag_out(1) = '0' and iscoded_flag_out(2) = '0' and iscoded_flag_out(3) = '0') then
			run_length_flag <= '1';
		else
			run_length_flag <= '0';
		end if;
	end process;
	
	--run_length_flag <= '1' when strip_all_uncoded_flag = '1' and strip_zero_context_flag = '1' else '0';
							
							
							
							
	--OUTPUT CALCULATIONS

	gen_output: for i in 0 to 3 generate
		--SIGNIFICANCE
			--magnitude
			out_contexts_significance(i*2)	<= significance_propagation_context(i);
			out_bits_significance(i*2) 	 	<= magnitude_bit(i);
			out_valid_significance(i*2)	 	<= significance_coded_flag_significance(i);
			
			--sign
			out_contexts_significance(i*2+1)	<= sign_bit_decoding_context(i);
			out_bits_significance(i*2+1) 		<= sign_bit(i) xor sign_bit_xor(i);
			out_valid_significance(i*2+1)		<= '1' when magnitude_bit(i) = '1' and significance_coded_flag_significance(i) = '1' else '0';
			
		--REFINEMENT
			out_contexts_refinement(i)		<= magnitude_refinement_context(i);
			out_bits_refinement(i)			<= magnitude_bit(i);
			out_valid_refinement(i) 		<= '1' when iscoded_flag_out(i) = '0' and full_neighborhood_matrix(4+3*i) /= INSIGNIFICANT else '0';
		
		--CLEANUP
			--magnitude
			out_contexts_cleanup(3+i*2)	<= significance_propagation_context(i);
			out_bits_cleanup(3+i*2) 	 	<= magnitude_bit(i);
			out_valid_cleanup(3+i*2)		<= '0' when iscoded_flag_out(i) = '1' else
														'1' when run_length_flag = '0' or (all_bits_zero_flag = '0' and first_nonzero <  i) else '0';
			
			--sign
			out_contexts_cleanup(4+i*2)<= sign_bit_decoding_context(i);
			out_bits_cleanup(4+i*2) 	<= sign_bit(i) xor sign_bit_xor(i);
			out_valid_cleanup(4+i*2)	<= '0' when iscoded_flag_out(i) = '1' or magnitude_bit(i) = '0' else --can probably be simplified
													'1' when run_length_flag = '0' or (all_bits_zero_flag = '0' and first_nonzero <= i) else '0';		
	end generate;
	
	--special flags
		--run len
		out_contexts_cleanup(0) <= CONTEXT_RUN_LENGTH;
		out_bits_cleanup(0)		<= not all_bits_zero_flag;
		out_valid_cleanup(0)		<= run_length_flag;
		--position
		out_contexts_cleanup(1) <= CONTEXT_UNIFORM;
		out_bits_cleanup(1)		<= '1' when first_nonzero = 2 or first_nonzero = 3 else '0';
		out_valid_cleanup(1)		<= '1' when run_length_flag = '1' and all_bits_zero_flag = '0' else '0';
		out_contexts_cleanup(2)	<= CONTEXT_UNIFORM;
		out_bits_cleanup(2)		<= '1' when first_nonzero = 1 or first_nonzero = 3 else '0';
		out_valid_cleanup(2)		<= run_length_flag and not all_bits_zero_flag;
		
	--default values 
	gen_default_significance: for i in 8 to 10 generate
		out_contexts_significance(i) <= CONTEXT_ZERO;
		out_bits_significance(i) <= '0';
		out_valid_significance(i) <= '0';
	end generate;
	gen_default_refinement: for i in 4 to 10 generate
		out_contexts_refinement(i) <= CONTEXT_ZERO;
		out_bits_refinement(i) <= '0';
		out_valid_refinement(i) <= '0';
	end generate;
		
	
	--OUTPUT MAPPING DEPENDING ON PASS
	out_contexts <= 	out_contexts_significance when curr_pass = SIGNIFICANCE else
							out_contexts_refinement when curr_pass = REFINEMENT else
							out_contexts_cleanup;
	out_bits <= out_bits_significance when curr_pass = SIGNIFICANCE else
					out_bits_refinement when curr_pass = REFINEMENT else
					out_bits_cleanup;
	out_valid <=	out_valid_significance when curr_pass = SIGNIFICANCE else
						out_valid_refinement when curr_pass = REFINEMENT else
						out_valid_cleanup;
	
end Behavioral;

