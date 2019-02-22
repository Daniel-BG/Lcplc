----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 12.02.2019 19:01:39
-- Design Name: 
-- Module Name: AXIS_SYNCHRONIZER_2 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Synchronize two axis streams into only one. Data outputs are kept separate for ease of use
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

entity AXIS_SYNCHRONIZER_2 is
	Generic (
		DATA_WIDTH_0: integer := 32;
		DATA_WIDTH_1: integer := 32
	);
	Port (
		clk, rst: in std_logic;
		--to input axi port
		input_0_valid: in  std_logic;
		input_0_ready: out std_logic;
		input_0_data : in  std_logic_vector(DATA_WIDTH_0 - 1 downto 0);
		input_1_valid: in  std_logic;
		input_1_ready: out std_logic; 
		input_1_data : in  std_logic_vector(DATA_WIDTH_1 - 1 downto 0);
		--to output axi ports
		output_valid	: out 	STD_LOGIC;
		output_ready	: in 	STD_LOGIC;
		output_data_0	: out std_logic_vector(DATA_WIDTH_0 - 1 downto 0);
		output_data_1	: out std_logic_vector(DATA_WIDTH_1 - 1 downto 0)
	);
end AXIS_SYNCHRONIZER_2;

architecture Behavioral of AXIS_SYNCHRONIZER_2 is
	signal input_valid: std_logic_vector(1 downto 0);

	signal buf0_i0, buf1_i0: std_logic_vector(DATA_WIDTH_0 - 1 downto 0);
	signal buf0_i1, buf1_i1: std_logic_vector(DATA_WIDTH_1 - 1 downto 0);

	signal buf0_full, buf0_filled: std_logic_vector(1 downto 0);
	signal buf1_full: std_logic;
	
	--inner signals
	signal input_0_ready_in, input_1_ready_in, output_valid_in: std_logic;
	
begin
	input_0_ready_in <= '1' when buf1_full = '0' or buf0_full(0) = '0' else '0';
	input_1_ready_in <= '1' when buf1_full = '0' or buf0_full(1) = '0' else '0';	
	output_valid_in <= buf1_full;
	
	buf0_filled(0) <= '1' when buf0_full(0) = '1' or (input_0_valid = '1' and input_0_ready_in = '1') else '0';
	buf0_filled(1) <= '1' when buf0_full(1) = '1' or (input_1_valid = '1' and input_1_ready_in = '1') else '0';
	
	input_0_ready <= input_0_ready_in;
	input_1_ready <= input_1_ready_in;
	output_valid  <= output_valid_in;

	output_data_0 <= buf1_i0;
	output_data_1 <= buf1_i1;
	
	seq: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				buf0_i0 <= (others => '0');
				buf0_i1 <= (others => '0');
				buf0_full <= (others => '0');
				buf1_i0 <= (others => '0');
				buf1_i1 <= (others => '0');
				buf1_full <= '0';
			else
				--sending
				if output_valid_in = '1' and output_ready = '1' then
					--receiving from both ports
					if input_0_ready_in = '1' and input_0_valid = '1' and input_1_ready_in = '1' and input_1_valid = '1' then
						buf1_full <= '1';
						buf1_i0 <= input_0_data;
						buf1_i1 <= input_1_data;	
					else
						--bypass to end
						if buf0_filled = (buf0_filled'range => '1') then
							buf1_full <= '1';
							buf0_full <= (others => '0');
							if buf0_full(0) = '1' then
								buf1_i0 <= buf0_i0;
							else
								buf1_i0 <= input_0_data;
							end if;
							if buf0_full(1) = '1' then
								buf1_i1 <= buf0_i1;
							else
								buf1_i1 <= input_1_data;
							end if;
						else
							buf1_full <= '0';
							--write to whatever ports have signals, we are not complete yet
							if input_0_ready_in = '1' and input_0_valid = '1' then
								buf0_full(0) <= '1';
								buf0_i0 <= input_0_data;
							end if;
							if input_1_ready_in = '1' and input_1_valid = '1' then
								buf0_full(1) <= '1';
								buf0_i1 <= input_1_data;
							end if;
						end if;
					end if;
				--not sending
				else
					--bypass to end if end is not full
					if buf1_full = '0' and buf0_filled = (buf0_filled'range => '1') then
						buf1_full <= '1';
						buf0_full <= (others => '0');
						if buf0_full(0) = '1' then
							buf1_i0 <= buf0_i0;
						else
							buf1_i0 <= input_0_data;
						end if;
						if buf0_full(1) = '1' then
							buf1_i1 <= buf0_i1;
						else
							buf1_i1 <= input_1_data;
						end if;
					else
						buf1_full <= '0';
						--write to whatever ports have signals, we are not complete yet
						if input_0_ready_in = '1' and input_0_valid = '1' then
							buf0_full(0) <= '1';
							buf0_i0 <= input_0_data;
						end if;
						if input_1_ready_in = '1' and input_1_valid = '1' then
							buf0_full(1) <= '1';
							buf0_i1 <= input_1_data;
						end if;
				end if;
				end if;
			end if;
		end if;
	end process;
	
	
end Behavioral;
