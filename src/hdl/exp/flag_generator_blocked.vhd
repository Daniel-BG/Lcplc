----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02.04.2019 09:28:54
-- Design Name: 
-- Module Name: flag_generator - Behavioral
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

entity flag_generator_blocked is
	Generic (
		DATA_WIDTH: integer := 16;
		MAX_BLOCK_SAMPLE_LOG: integer := 4;
		MAX_BLOCK_LINE_LOG	: integer := 4;
		MAX_IMAGE_SAMPLE_LOG: integer := 12;
		MAX_IMAGE_LINE_LOG	: integer := 12;
		MAX_IMAGE_BAND_LOG	: integer := 12;
		LATCH_INPUT			: boolean := true;
		LATCH_OUTPUT		: boolean := true
	);
	Port (
		--control signals
		clk, rst: in std_logic;
		--configuration for the counters
		config_block_samples: in  std_logic_vector(MAX_BLOCK_SAMPLE_LOG - 1 downto 0);
		config_block_lines	: in  std_logic_vector(MAX_BLOCK_LINE_LOG - 1 downto 0);
		config_image_samples: in  std_logic_vector(MAX_IMAGE_SAMPLE_LOG - 1 downto 0);
		config_image_lines	: in  std_logic_vector(MAX_IMAGE_LINE_LOG - 1 downto 0);
		config_image_bands	: in  std_logic_vector(MAX_IMAGE_BAND_LOG - 1 downto 0);
		--input data
		raw_input_data		: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		raw_input_ready		: out std_logic;
		raw_input_valid		: in  std_logic;
		--output tagged data
		output_data		: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_last_r	: out std_logic;
		output_last_s	: out std_logic;
		output_last_b	: out std_logic;
		output_last_i	: out std_logic; 
		output_ready	: in  std_logic;
		output_valid	: out std_logic
	);
end flag_generator_blocked;

architecture Behavioral of flag_generator_blocked is
	--for latching input
	signal input_data	: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal input_ready	: std_logic;
	signal input_valid	: std_logic;
	--------------------

	type flag_gen_state_t is (IDLE, GET_BLOCK_DIM_MAX, REDUCE_BLOCK_DIM, REDUCE_BLOCK_DIM_2, PROCESS_BLOCK, END_SLICE, END_BLOCK);
	signal flag_gen_state_curr, flag_gen_state_next: flag_gen_state_t;
	
	--start and end of block
	signal first_block_sample_curr, first_block_sample_next: std_logic_vector(MAX_IMAGE_SAMPLE_LOG - 1 downto 0);
	signal first_block_line_curr, first_block_line_next: std_logic_vector(MAX_IMAGE_LINE_LOG - 1 downto 0);
	signal last_block_sample_curr, last_block_sample_next: std_logic_vector(MAX_IMAGE_SAMPLE_LOG - 1 downto 0);
	signal last_block_line_curr, last_block_line_next: std_logic_vector(MAX_IMAGE_LINE_LOG - 1 downto 0);
	--flag for last block in block row or block column
	signal block_ends_samples_curr, block_ends_samples_next: boolean;
	signal block_ends_lines_curr, block_ends_lines_next: boolean;
	--counter within the block
	signal block_sample_curr, block_sample_next: std_logic_vector(MAX_BLOCK_SAMPLE_LOG - 1 downto 0);
	signal block_line_curr, block_line_next: std_logic_vector(MAX_BLOCK_LINE_LOG - 1 downto 0);
	signal block_band_curr, block_band_next: std_logic_vector(MAX_IMAGE_BAND_LOG - 1 downto 0);
	signal block_max_line_curr, block_max_line_next: std_logic_vector(MAX_BLOCK_LINE_LOG - 1 downto 0);
	signal block_max_sample_curr, block_max_sample_next: std_logic_vector(MAX_BLOCK_SAMPLE_LOG - 1 downto 0);
	signal block_max_band_curr, block_max_band_next: std_logic_vector(MAX_IMAGE_BAND_LOG - 1 downto 0);

	signal flag_last_block_sample_curr, flag_last_block_line_curr, flag_last_block_band_curr: boolean;
	signal flag_last_block_sample_next, flag_last_block_line_next, flag_last_block_band_next: boolean;

	signal reg_block_sample_width, reg_block_sample_width_next: std_logic_vector(MAX_BLOCK_SAMPLE_LOG - 1 downto 0);
	signal reg_block_sample_last, reg_block_sample_last_next: std_logic_vector(MAX_IMAGE_SAMPLE_LOG - 1 downto 0);
	signal reg_block_line_height, reg_block_line_height_next: std_logic_vector(MAX_BLOCK_LINE_LOG - 1 downto 0);
	signal reg_block_line_last, reg_block_line_last_next: std_logic_vector(MAX_IMAGE_LINE_LOG - 1 downto 0);

	--for latching output
	signal raw_output_data	: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal raw_output_last_r: std_logic;
	signal raw_output_last_s: std_logic;
	signal raw_output_last_b: std_logic;
	signal raw_output_last_i: std_logic; 
	signal raw_output_ready	: std_logic;
	signal raw_output_valid	: std_logic;

	signal raw_output_user, output_user: std_logic_vector(3 downto 0);
	---------------------

begin

	--input_latch
	gen_input_latched: if LATCH_INPUT generate
		input_latch: entity work.AXIS_LATCHED_CONNECTION
			generic map (DATA_WIDTH => DATA_WIDTH)
			port map (
				clk => clk, rst => rst,
				input_data   => raw_input_data,
				input_valid  => raw_input_valid,
				input_ready  => raw_input_ready,
				output_data  => input_data,
				output_ready => input_ready,
				output_valid => input_valid
			);
	end generate;
	gen_input_unlatched: if not LATCH_INPUT generate
		input_data 		<= raw_input_data;
		raw_input_ready <= input_ready;
		input_valid 	<= raw_input_valid;
	end generate;


	flag_gen_seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				flag_gen_state_curr <= IDLE;
			else
				flag_gen_state_curr <= flag_gen_state_next;
				--start and end of block
				first_block_sample_curr <= first_block_sample_next;
				first_block_line_curr	<= first_block_line_next;
				last_block_sample_curr 	<= last_block_sample_next;
				last_block_line_curr	<= last_block_line_next;
				--flag for last block in block row or block column
				block_ends_samples_curr <= block_ends_samples_next;
				block_ends_lines_curr   <= block_ends_lines_next;
				--counter within the block
				block_sample_curr 		<= block_sample_next;
				block_line_curr 		<= block_line_next;
				block_band_curr 		<= block_band_next;
				block_max_line_curr		<= block_max_line_next;
				block_max_sample_curr	<= block_max_sample_next;
				block_max_band_curr 	<= block_max_band_next;
				--
				--flag_last_block_sample_curr <= flag_last_block_sample_next;
				--flag_last_block_line_curr   <= flag_last_block_line_next;
				--flag_last_block_band_curr   <= flag_last_block_band_next;
				--
				reg_block_sample_width <= reg_block_sample_width_next;
				reg_block_sample_last  <= reg_block_sample_last_next;
				reg_block_line_height  <= reg_block_line_height_next;
				reg_block_line_last    <= reg_block_line_last_next;
			end if;
		end if;
	end process;

	flag_gen_comb: process(flag_gen_state_curr,
		first_block_sample_curr, first_block_line_curr, last_block_sample_curr, last_block_line_curr,
		block_ends_samples_curr, block_ends_lines_curr,
		block_sample_curr, block_line_curr, block_band_curr, block_max_line_curr, block_max_sample_curr,
		config_image_samples, config_image_lines, 
		first_block_sample_next, config_block_samples, first_block_line_next, config_block_lines,
		input_valid, raw_output_ready,
		flag_last_block_sample_curr, flag_last_block_line_curr, flag_last_block_band_curr)
	begin
		flag_gen_state_next <= flag_gen_state_curr;
		first_block_sample_next <= first_block_sample_curr;
		first_block_line_next	<= first_block_line_curr;
		last_block_sample_next  <= last_block_sample_curr;
		last_block_line_next 	<= last_block_line_curr;
		block_ends_samples_next <= block_ends_samples_curr;
		block_ends_lines_next   <= block_ends_lines_curr;
		block_sample_next  		<= block_sample_curr;
		block_line_next 		<= block_line_curr;
		block_band_next			<= block_band_curr;
		block_max_line_next		<= block_max_line_curr;
		block_max_sample_next 	<= block_max_sample_curr;
		block_max_band_next		<= block_max_band_curr;
		reg_block_sample_width_next <= reg_block_sample_width;
		reg_block_sample_last_next  <= reg_block_sample_last;
		reg_block_line_height_next  <= reg_block_line_height;
		reg_block_line_last_next    <= reg_block_line_last;

		raw_output_valid 	<= '0';
		input_ready 		<= '0';

		if flag_gen_state_curr = IDLE then
			flag_gen_state_next <= GET_BLOCK_DIM_MAX;
			first_block_sample_next <= (others => '0');
			first_block_line_next	<= (others => '0');
		--by default get block size as up to the image border
		elsif flag_gen_state_curr = GET_BLOCK_DIM_MAX then
			last_block_sample_next	<= config_image_samples;
			last_block_line_next	<= config_image_lines;
			flag_gen_state_next 	<= REDUCE_BLOCK_DIM;
		--keep it only if the block overflows the image size, otherwise get it as
		--the increase in block size from the block's origin
		--not that the block goes from origin to ending BOTH INCLUDED
		elsif flag_gen_state_curr = REDUCE_BLOCK_DIM then
			reg_block_sample_width_next <= std_logic_vector(resize(unsigned(last_block_sample_curr) - unsigned(first_block_sample_curr), reg_block_sample_width_next'length));
			reg_block_sample_last_next  <= std_logic_vector(unsigned(first_block_sample_curr) + unsigned(config_block_samples));
			reg_block_line_height_next  <= std_logic_vector(resize(unsigned(last_block_line_curr) - unsigned(first_block_line_curr),reg_block_line_height_next'length));
			reg_block_line_last_next    <= std_logic_vector(unsigned(first_block_line_curr) + unsigned(config_block_lines));
			flag_gen_state_next <= REDUCE_BLOCK_DIM_2;
			--max block band is max image band, 
		elsif flag_gen_state_curr = REDUCE_BLOCK_DIM_2 then
			block_sample_next 	<= (others => '0');
			if unsigned(reg_block_sample_width) < unsigned(config_block_samples) then
				last_block_sample_next <= reg_block_sample_last;
				block_max_sample_next  <= config_block_samples;
			else
				block_ends_samples_next <= true;
				block_max_sample_next  <= reg_block_sample_width;
			end if;
			block_line_next  	<= (others => '0');
			if unsigned(reg_block_line_height) < unsigned(config_block_lines) then
				last_block_line_next <= reg_block_line_last;
				block_max_line_next	<= config_block_lines;
			else
				block_ends_lines_next <= true;
				block_max_line_next	<= reg_block_line_height;
			end if;
			flag_gen_state_next <= PROCESS_BLOCK;
			block_band_next 	<= (others => '0');
			block_max_band_next <= config_image_bands;
		elsif flag_gen_state_curr = PROCESS_BLOCK then
			--connect latches
			raw_output_valid 	<= input_valid;
			input_ready 		<= raw_output_ready;
			--todo process block, enable things
			if input_valid = '1' and raw_output_ready = '1' then
				if flag_last_block_sample_curr then
					block_sample_next <= (others => '0');
					if flag_last_block_line_curr then
						block_line_next <= (others => '0');
						if flag_last_block_band_curr then
							block_band_next <= (others => '0');
							flag_gen_state_next <= END_BLOCK;
						else
							block_band_next <= std_logic_vector(unsigned(block_band_curr) + to_unsigned(1, block_band_curr'length));
						end if;
					else
						block_line_next <= std_logic_vector(unsigned(block_line_curr) + to_unsigned(1, block_line_curr'length));
					end if;
				else
					block_sample_next <= std_logic_vector(unsigned(block_sample_curr) + to_unsigned(1, block_sample_curr'length));
				end if;
			end if;
		elsif flag_gen_state_curr = END_SLICE then

		elsif flag_gen_state_curr = END_BLOCK then
			--calculate next block coordinates
			if block_ends_samples_curr then
				first_block_sample_next <= (others => '0');
				if block_ends_lines_curr then
					first_block_line_next <= (others => '0');
					flag_gen_state_next <= IDLE;
				else
					first_block_line_next <= std_logic_vector(unsigned(last_block_line_curr) + to_unsigned(1, last_block_line_curr'length));
					flag_gen_state_next <= GET_BLOCK_DIM_MAX; 
				end if;
			else
				first_block_sample_next <= std_logic_vector(unsigned(last_block_sample_curr) + to_unsigned(1, first_block_sample_curr'length));
				flag_gen_state_next <= GET_BLOCK_DIM_MAX; 
			end if;
		end if;
	end process;

	--directly connect this thing
	raw_output_data  <= input_data;
	--TODO generate flags roli, rolb, rols, rolr
	--flag_last_block_sample_next	<= block_sample_next= block_max_sample_curr;
	--flag_last_block_line_next	<= block_line_next 	= block_max_line_curr;
	--flag_last_block_band_next	<= block_band_next	= config_image_bands;
	flag_last_block_sample_curr	<= block_sample_curr= block_max_sample_curr;
	flag_last_block_line_curr	<= block_line_curr 	= block_max_line_curr;
	flag_last_block_band_curr	<= block_band_curr	= config_image_bands;
	--flag gen
	raw_output_last_r <= '1' when flag_last_block_sample_curr else '0';
	raw_output_last_s <= '1' when flag_last_block_sample_curr and flag_last_block_line_curr else '0';
	raw_output_last_b <= '1' when flag_last_block_sample_curr and flag_last_block_line_curr and flag_last_block_band_curr else '0';
	raw_output_last_i <= '1' when flag_last_block_sample_curr and flag_last_block_line_curr and flag_last_block_band_curr and block_ends_samples_curr and block_ends_lines_curr else '0';

	--generate output latch
	raw_output_user <= raw_output_last_i & raw_output_last_b & raw_output_last_s & raw_output_last_r;
	output_last_i <= output_user(3);
	output_last_b <= output_user(2);
	output_last_s <= output_user(1);
	output_last_r <= output_user(0);
	gen_output_latched: if LATCH_OUTPUT generate
		input_latch: entity work.AXIS_LATCHED_CONNECTION
			generic map (
				DATA_WIDTH => DATA_WIDTH,
				USER_WIDTH => 4
			)
			port map (
				clk => clk, rst => rst,
				input_data   => raw_output_data,
				input_valid  => raw_output_valid,
				input_ready  => raw_output_ready,
				input_user	 => raw_output_user,
				output_data  => output_data,
				output_ready => output_ready,
				output_valid => output_valid,
				output_user  => output_user
			);
	end generate;
	gen_output_unlatched: if not LATCH_OUTPUT generate
		output_data		<= raw_output_data;
		output_user 	<= raw_output_user; --these are the flags
		raw_output_ready<= output_ready;
		output_valid	<= raw_output_valid;
	end generate;
end Behavioral;
