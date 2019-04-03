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

entity flag_generator is
	Generic (
		DATA_WIDTH: integer := 16;
		MAX_BLOCK_SAMPLE_LOG: integer := 4;
		MAX_BLOCK_LINE_LOG	: integer := 4;
		MAX_IMAGE_SAMPLE_LOG: integer := 12;
		MAX_IMAGE_LINE_LOG	: integer := 12;
		MAX_IMAGE_BAND_LOG	: integer := 12; --same as block band
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
end flag_generator;

architecture Behavioral of flag_generator is
	--for latching input
	signal input_data	: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal input_ready	: std_logic;
	signal input_valid	: std_logic;
	--------------------

	signal count_enable: std_logic;

	signal current_block_sample	, incr_block_sample	: std_logic_vector(MAX_BLOCK_SAMPLE_LOG - 1 downto 0);
	signal current_block_line	, incr_block_line	: std_logic_vector(MAX_BLOCK_LINE_LOG - 1 downto 0);
	signal current_image_sample	, incr_image_sample	, last_image_sample_boundary: std_logic_vector(MAX_IMAGE_SAMPLE_LOG - 1 downto 0);
	signal current_image_line	, incr_image_line	, last_image_line_boundary	: std_logic_vector(MAX_IMAGE_LINE_LOG - 1 downto 0);
	signal current_block_band	, incr_block_band	: std_logic_vector(MAX_IMAGE_BAND_LOG - 1 downto 0);

	signal flag_last_block_sample	: boolean;
	signal flag_last_block_line		: boolean;
	signal flag_last_image_sample	: boolean;
	signal flag_last_image_line		: boolean;
	signal flag_last_block_band		: boolean;

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



	--flag generation
	flag_last_block_sample	<= current_block_sample = config_block_samples;
	flag_last_block_line	<= current_block_line 	= config_block_lines;
	flag_last_image_sample	<= current_image_sample = config_image_samples;
	flag_last_image_line	<= current_image_line	= config_image_lines;
	flag_last_block_band	<= current_block_band	= config_image_bands;
	--next counter generation
	incr_block_sample	<= std_logic_vector(unsigned(current_block_sample)	+ to_unsigned(1, current_block_sample'length));	
	incr_block_line		<= std_logic_vector(unsigned(current_block_line)	+ to_unsigned(1, current_block_line'length));	
	incr_image_sample	<= std_logic_vector(unsigned(current_image_sample)	+ to_unsigned(1, current_image_sample'length));	
	incr_image_line		<= std_logic_vector(unsigned(current_image_line)	+ to_unsigned(1, current_image_line'length));	
	incr_block_band		<= std_logic_vector(unsigned(current_block_band)	+ to_unsigned(1, current_block_band'length));	

	count: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				current_block_sample		<= (others => '0');
				current_block_line			<= (others => '0');
				current_image_sample 		<= (others => '0');
				current_image_line			<= (others => '0');
				current_block_band			<= (others => '0');
				last_image_sample_boundary	<= (others => '0');
				last_image_line_boundary	<= (others => '0');
			elsif count_enable = '1' then
				--update current block sample
				if flag_last_block_sample or flag_last_image_sample then
					current_block_sample <= (others => '0');
				else
					current_block_sample <= incr_block_sample;	
				end if;
				--update current block line
				if flag_last_block_sample or flag_last_image_sample then
					if flag_last_block_line or flag_last_image_line then
						current_block_line 	 <= (others => '0');
					else
						current_block_line 	 <= incr_block_line;
					end if;
				end if;
				--update local band
				if flag_last_block_sample or flag_last_image_sample then
					if flag_last_block_line or flag_last_image_line then
						if flag_last_block_band then
							current_block_band <= (others => '0');
						else
							current_block_band <= incr_block_band;
						end if;
					end if;
				end if;
				--update global image sample
				if flag_last_block_sample or flag_last_image_sample then
					if flag_last_block_line or flag_last_image_line then
						if flag_last_block_band then
							if flag_last_image_sample then
								current_image_sample		<= (others => '0'); --reset to beginning
								last_image_sample_boundary	<= (others => '0');
							else
								current_image_sample 		<= incr_image_sample;
								last_image_sample_boundary	<= incr_image_sample;
							end if;
						else
							current_image_sample <= last_image_sample_boundary;	
						end if;
					else
						current_image_sample <= last_image_sample_boundary;
					end if;
				else
					current_image_sample <= incr_image_sample;
				end if;
				--update global image line
				if flag_last_block_sample or flag_last_image_sample then
					if flag_last_block_line or flag_last_image_line then
						if flag_last_block_band then
							if flag_last_image_sample then
								if flag_last_image_line then
									current_image_line			<= (others => '0');	
									last_image_line_boundary	<= (others => '0');	
								else
									current_image_line			<= incr_image_line;	
									last_image_line_boundary	<= incr_image_line;		
								end if;
							else
								current_image_line <= last_image_line_boundary;	
							end if;
						else
							current_image_line <= last_image_line_boundary;
						end if;
					else
						current_image_line <= incr_image_line;
					end if;
				end if;
			end if;
		end if; 
	end process;

	--output/input connection
	raw_output_valid<= input_valid;
	input_ready 	<= raw_output_ready;
	count_enable 	<= '1' when input_valid = '1' and raw_output_ready = '1' else '0';
	raw_output_data		<= input_data;
	raw_output_last_r	<= '1' when flag_last_block_sample or flag_last_image_sample else '0';
	raw_output_last_s	<= '1' when (flag_last_block_sample or flag_last_image_sample) and (flag_last_block_line or flag_last_image_line) else '0';
	raw_output_last_b 	<= '1' when (flag_last_block_sample or flag_last_image_sample) and (flag_last_block_line or flag_last_image_line) and (flag_last_block_band) else '0';
	raw_output_last_i	<= '1' when flag_last_image_sample and flag_last_image_line and flag_last_block_band else '0';

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
