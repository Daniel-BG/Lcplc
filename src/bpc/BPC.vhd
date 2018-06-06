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
		clk, rst, clk_en: in std_logic
	);
end BPC;

architecture Behavioral of BPC is
	--constants
	constant subband: subband_t := LL;
	
	--sample signals
	signal s0, s1, s2, s3: std_logic_vector(BITPLANES downto 0); --one extra for sign
	signal sign_bit_0, sign_bit_1, sign_bit_2, sign_bit_3: std_logic;

	--coord gen signals
	signal curr_strip: natural range 0 to STRIPS - 1;
	signal curr_col: natural range 0 to COLS - 1;
	signal curr_bitplane: natural range 0 to BITPLANES - 1;
	signal curr_pass: encoder_pass_t;
	signal last_coord: std_logic;
	
	--significance signals
	signal raw_neighborhood, full_neighborhood: run_length_neighborhood_t;
	signal significance_next_0, significance_next_1, significance_next_2, significance_next_3: significance_state_t;
	
	--context generation signals
	signal neighborhood_0, neighborhood_1, neighborhood_2, neighborhood_3: neighborhood_3x3_t;
	signal first_refinement_0, first_refinement_1, first_refinement_2, first_refinement_3: std_logic;
	signal 	magnitude_refinement_context_0, magnitude_refinement_context_1, magnitude_refinement_context_2, magnitude_refinement_context_3,
				sign_bit_decoding_context_0, sign_bit_decoding_context_1, sign_bit_decoding_context_2, sign_bit_decoding_context_3,
				significance_propagation_context_0, significance_propagation_context_1, significance_propagation_context_2, significance_propagation_context_3
		: context_label_t;		
	signal sign_bit_xor_0, sign_bit_xor_1, sign_bit_xor_2, sign_bit_xor_3: std_logic;
	
	
	
	--filter signals
	signal first_cleanup_pass_flag: std_logic;
	
	--iscoded signals
	signal iscoded_vector_out: std_logic_vector(3 downto 0);
	
	--first refinement signals
	signal first_refinement_vector_out: std_logic_vector(3 downto 0);

begin

	sample_mem: entity work.BPC_mem
	generic map (WIDTH => COLS, STRIPS => STRIPS, BIT_DEPTH => BITPLANES + 1)
	port map (
		rst => rst, clk => clk, clk_en => clk_en,
		input => open,
		input_loc => open,
		input_en => open,
		s0 => s0, s1 => s1, s2 => s2, s3 => s3
	);

	sign_bit_0 <= s0(BITPLANES);
	sign_bit_1 <= s1(BITPLANES);
	sign_bit_2 <= s2(BITPLANES);
	sign_bit_3 <= s3(BITPLANES);

	coordinate_gen: entity work.BPC_coord_gen
		generic map(
			STRIPS => STRIPS, COLS => COLS, BITPLANES => BITPLANES
		)
		port map(
			clk => clk, rst => rst, clk_en => clk_en,
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
			in_value_0 => next_significance_0,
			in_value_1 => next_significance_1,
			in_value_2 => next_significance_2,
			in_value_3 => next_significance_3,
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
			run_length_neihgborhood => full_neighborhood
		);
		
	iscoded_flag_matrix: entity work.BPC_flag_matrix
		generic map(SIZE => COLS * STRIPS, WIDTH => 4)
		port map (
			clk => clk, rst => rst, clk_en => clk_en,
			in_value => open,
			out_value => iscoded_vector_out
		);	
		
	first_refinement_flag_matrix: entity work.BPC_flag_matrix
		generic map(SIZE => COLS * STRIPS, WIDTH => 4)
		port map (
			clk => clk, rst => rst, clk_en => clk_en,
			in_value => open,
			out_value => first_refinement_vector_out
		);	


	--ZERO STUFF
	neighborhood_0.top_left		<= full_neighborhood.prev_m1;
	neighborhood_0.top			<= full_neighborhood.prev_p3;
	neighborhood_0.top_right	<= full_neighborhood.prev_p7;
	neighborhood_0.left			<= full_neighborhood.curr_m4;
	neighborhood_0.right			<= full_neighborhood.curr_p4;
	neighborhood_0.bottom_left	<= full_neighborhood.curr_m3;
	neighborhood_0.bottom		<= full_neighborhood.curr_p1;
	neighborhood_0.bottom_right<= full_neighborhood.curr_p5;

	ctx_gen_0: entity work.BPC_3x3_context_gen
		port map(
			neighborhood => neighborhood_0,
			subband => subband,
			first_refinement_in => first_refinement_0,
			magnitude_refinement_context => magnitude_refinement_context_0,
			sign_bit_decoding_context => sign_bit_decoding_context_0,
			significance_propagation_context => significance_propagation_context_0,
			sign_bit_xor => sign_bit_xor_0
		);
		
	next_sign_calc_0: entity work.BPC_next_significance_calc
		port map(
			curr_pass => curr_pass, 
			curr_significance => full_neighborhood.curr_c, 
			curr_context => significance_propagation_context_0, 
			curr_sign_bit => sign_bit_0,
			next_significance => next_significance_0
		);
	
	--ONE STUFF
	neighborhood_1.top_left		<= full_neighborhood.curr_m4;
	neighborhood_1.top			<= next_significance_0;	--state depends on previous ctx_gen
	neighborhood_1.top_right	<= full_neighborhood.curr_p4;
	neighborhood_1.left			<= full_neighborhood.curr_m3;
	neighborhood_1.right			<= full_neighborhood.curr_p5;
	neighborhood_1.bottom_left	<= full_neighborhood.curr_m2;
	neighborhood_1.bottom		<= full_neighborhood.curr_p2;
	neighborhood_1.bottom_right<= full_neighborhood.curr_p6;

	ctx_gen_1: entity work.BPC_3x3_context_gen
		port map(
			neighborhood => neighborhood_1,
			subband => subband,
			first_refinement_in => first_refinement_1,
			magnitude_refinement_context => magnitude_refinement_context_1,
			sign_bit_decoding_context => sign_bit_decoding_context_1,
			significance_propagation_context => significance_propagation_context_1,
			sign_bit_xor => sign_bit_xor_1
		);
		
	next_sign_calc_1: entity work.BPC_next_significance_calc
		port map(
			curr_pass => curr_pass, 
			curr_significance => full_neighborhood.curr_p1, 
			curr_context => significance_propagation_context_1, 
			curr_sign_bit => sign_bit_1,
			next_significance => next_significance_1
		);
	
	--TWO STUFF		
	neighborhood_2.top_left		<= full_neighborhood.curr_m3;
	neighborhood_2.top			<= next_significance_1; --state depends on previous ctx_gen
	neighborhood_2.top_right	<= full_neighborhood.curr_p5;
	neighborhood_2.left			<= full_neighborhood.curr_m2;
	neighborhood_2.right			<= full_neighborhood.curr_p6;
	neighborhood_2.bottom_left	<= full_neighborhood.curr_m1;
	neighborhood_2.bottom		<= full_neighborhood.curr_p3;
	neighborhood_2.bottom_right<= full_neighborhood.curr_p7;

	ctx_gen_2: entity work.BPC_3x3_context_gen
		port map(
			neighborhood => neighborhood_2,
			subband => subband,
			first_refinement_in => first_refinement_2,
			magnitude_refinement_context => magnitude_refinement_context_2,
			sign_bit_decoding_context => sign_bit_decoding_context_2,
			significance_propagation_context => significance_propagation_context_2,
			sign_bit_xor => sign_bit_xor_2
		);
		
	next_sign_calc_2: entity work.BPC_next_significance_calc
		port map(
			curr_pass => curr_pass, 
			curr_significance => full_neighborhood.curr_p2, 
			curr_context => significance_propagation_context_2, 
			curr_sign_bit => sign_bit_2,
			next_significance => next_significance_2
		);
	
	--THREE STUFF
	neighborhood_3.top_left		<= full_neighborhood.curr_m2;
	neighborhood_3.top			<= next_significance_2; --state depends on previous ctx_gen
	neighborhood_3.top_right	<= full_neighborhood.curr_p6;
	neighborhood_3.left			<= full_neighborhood.curr_m1;
	neighborhood_3.right			<= full_neighborhood.curr_p7;
	neighborhood_3.bottom_left	<= full_neighborhood.next_m4;
	neighborhood_3.bottom		<= full_neighborhood.next_c;
	neighborhood_3.bottom_right<= full_neighborhood.next_p4;

	ctx_gen_3: entity work.BPC_3x3_context_gen
		port map(
			neighborhood => neighborhood_3,
			subband => subband,
			first_refinement_in => first_refinement_3,
			magnitude_refinement_context => magnitude_refinement_context_3,
			sign_bit_decoding_context => sign_bit_decoding_context_3,
			significance_propagation_context => significance_propagation_context_3,
			sign_bit_xor => sign_bit_xor_3
		);

	next_sign_calc_3: entity work.BPC_next_significance_calc
		port map(
			curr_pass => curr_pass, 
			curr_significance => full_neighborhood.curr_p3, 
			curr_context => significance_propagation_context_3, 
			curr_sign_bit => sign_bit_3,
			next_significance => next_significance_3
		);
	


end Behavioral;

