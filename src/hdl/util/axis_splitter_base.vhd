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

entity AXIS_SPLITTER_BASE is
	Generic (
		DATA_WIDTH: positive := 32;
		OUTPUT_PORTS: positive := 2
	);
	Port (
		clk, rst		: in 	std_logic;
		--to input axi port
		input_valid		: in	STD_LOGIC;
		input_data		: in	STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		input_ready		: out	STD_LOGIC;
		input_last		: in    STD_LOGIC;
		--to output axi ports
		output_valid	: out 	STD_LOGIC_VECTOR(OUTPUT_PORTS - 1 downto 0);
		output_data		: out 	STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
		output_ready	: in 	STD_LOGIC_VECTOR(OUTPUT_PORTS - 1 downto 0);
		output_last     : out   STD_LOGIC
	);
end AXIS_SPLITTER_BASE;

architecture Behavioral of AXIS_SPLITTER_BASE is	
	--buffers
	signal buf0, buf1: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal buf0_last, buf1_last: std_logic;
	
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
				buf1 	  <= (others => '0');
				buf1_last <= '0';
			else
				--is writing a value, now decide where
				if inner_in_ready = '1' and input_valid = '1' then
					if buf1_full_next = (buf1_full_next'range => '0') then
						buf1 <= input_data;
						buf1_last <= input_last;
						buf1_full <= (buf1_full'range => '1');
					else
						buf0 <= input_data;
						buf0_last <= input_last;
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
					else
						buf1_full <= buf1_full_next; --maybe reading some values, maybe not
					end if;
				end if;
			end if;
		end if;
	end process;
	
	
	
end Behavioral;
