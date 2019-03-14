----------------------------------------------------------------------------------
-- Company: UCM 
-- Engineer: Daniel Báscones
-- 
-- Create Date: 12.02.2019 18:26:18
-- Design Name: 
-- Module Name: splitter_axiAXIS_SPLITTER_BASE - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Split an input AXIS bus into multiple output AXIS buses
-- 
-- Dependencies: None
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.constants.all;

entity AXIS_SPLITTER_BASE is
	Generic (
		DATA_WIDTH: positive := 32;
		OUTPUT_PORTS: positive := 2;
		USER_WIDTH: integer := 1
	);
	Port (
		clk, rst		: in 	std_logic;
		--to input axi port
		input_valid		: in	std_logic;
		input_data		: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_ready		: out	std_logic;
		input_last		: in    std_logic;
		input_user		: in 	std_logic_vector(USER_WIDTH - 1 downto 0);
		--to output axi ports
		output_valid	: out 	std_logic_vector(OUTPUT_PORTS - 1 downto 0);
		output_data		: out 	std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_ready	: in 	std_logic_vector(OUTPUT_PORTS - 1 downto 0);
		output_last     : out   std_logic;
		output_user		: out 	std_logic_vector(USER_WIDTH - 1 downto 0)
	);
end AXIS_SPLITTER_BASE;

architecture Behavioral of AXIS_SPLITTER_BASE is	
	--buffers
	signal buf0, buf1: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal buf0_last, buf1_last: std_logic;
	signal buf0_user, buf1_user: std_logic_vector(USER_WIDTH - 1 downto 0);
	
	attribute KEEP of buf0_last, buf1_last: signal is KEEP_DEFAULT;
	attribute KEEP of buf0_user, buf1_user: signal is KEEP_DEFAULT;
	
	--buffer flags
	signal buf0_full: std_logic;
	signal buf1_full: std_logic_vector(OUTPUT_PORTS - 1 downto 0);
	signal buf1_full_next: std_logic_vector(OUTPUT_PORTS - 1 downto 0);
	
	--inner signals
	signal inner_in_ready: std_logic;
	signal inner_out_valid: std_logic_vector(OUTPUT_PORTS - 1 downto 0);
begin
	output_data <= buf1;

	inner_in_ready	<= not buf0_full;
	inner_out_valid	<=     buf1_full;
	input_ready		<= inner_in_ready;
	output_valid	<= inner_out_valid;
	output_last		<= buf1_last;
	output_user		<= buf1_user;
	
	gen_next_full_flag: for i in OUTPUT_PORTS - 1 downto 0 generate
		buf1_full_next(i) <= '0' when buf1_full(i) = '0' or (inner_out_valid(i) = '1' and output_ready(i) = '1') else '1';
	end generate;
	
	seq: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				buf0_full <= '0';
				buf1_full <= (others => '0');
				buf0 	  <= (others => '0');
				buf0_last <= '0';
				buf0_user <= (others => '0');
				buf1 	  <= (others => '0');
				buf1_last <= '0';
				buf1_user <= (others => '0');
			else
				--is writing a value, now decide where
				if inner_in_ready = '1' and input_valid = '1' then
					if buf1_full_next = (buf1_full_next'range => '0') then
						buf1 <= input_data;
						buf1_last <= input_last;
						buf1_user <= input_user;
						buf1_full <= (buf1_full'range => '1');
					else
						buf0 <= input_data;
						buf0_last <= input_last;
						buf0_user <= input_user;
						buf0_full <= '1';
						buf1_full <= buf1_full_next;
					end if;
				--not writing anything
				else 
					if buf1_full_next = (buf1_full_next'range => '0') then
						--shift value
						buf0_full <= '0';
						buf1_full <= (buf1_full'range => buf0_full);
						buf1 <= buf0;
						buf1_last <= buf0_last;
						buf1_user <= buf0_user;
					else
						buf1_full <= buf1_full_next; --maybe reading some values, maybe not
					end if;
				end if;
			end if;
		end if;
	end process;
	
	
	
end Behavioral;