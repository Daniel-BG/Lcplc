----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 11.02.2019 15:57:30
-- Design Name: 
-- Module Name: AXIS_LATCHED_CONNECTION - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Connect to axis ports with a latched connection so that propagation
--		of ready signals (backwards) or valid signals (forwards) is stopped and the
--		critical path can be reduced
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
use work.constants.all;

entity AXIS_LATCHED_CONNECTION is
	Generic (
		DATA_WIDTH: integer := 32;
		USER_WIDTH: integer := 1
	);
	Port (
		clk, rst: in std_logic;
		input_ready : out std_logic;
		input_valid : in  std_logic;
		input_data  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_last  : in  std_logic := '0';
		input_user  : in  std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		output_ready: in  std_logic;
		output_valid: out std_logic;
		output_data : out std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_last : out std_logic;
		output_user : out std_logic_vector(USER_WIDTH - 1 downto 0)
	);
end AXIS_LATCHED_CONNECTION;

architecture Behavioral of AXIS_LATCHED_CONNECTION is
	--buffers
	signal buf0, buf1: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal buf0_last, buf1_last: std_logic;
	signal buf0_user, buf1_user: std_logic_vector(USER_WIDTH - 1 downto 0);

	attribute KEEP of buf0_last, buf1_last, buf0_user, buf1_user: signal is KEEP_DEFAULT;

	
	--buffer flags
	signal buf0_full, buf1_full: std_logic;
	
	--inner signals
	signal inner_input_ready, inner_output_valid: std_logic;
begin

	output_data <= buf1;
	output_last <= buf1_last;
	output_user <= buf1_user;

	inner_input_ready	<= not buf0_full;
	inner_output_valid	<=     buf1_full;
	input_ready			<= inner_input_ready;
	output_valid		<= inner_output_valid;

	seq: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				buf0_full <= '0';
				buf1_full <= '0';
				buf0 	  <= (others => '0');
				buf1 	  <= (others => '0');
				buf0_last <= '0';
				buf1_last <= '0';
				buf0_user <= (others => '0');
				buf1_user <= (others => '0');
			else
				if inner_input_ready = '1' and input_valid = '1' and inner_output_valid = '1' and output_ready = '1' then
					--writing and reading (can only happen if one buffer is '1' and the other is '0')
					buf1 <= input_data;
					buf1_last <= input_last;
					buf1_user <= input_user;
					--buf1_full keeps its value of 1
				elsif inner_input_ready = '1' and input_valid = '1' then
					--writing (can happen with one or both buffers free)
					--write to buf1 unless full
					if buf1_full = '0' then
						buf1 <= input_data;
						buf1_last <= input_last;
						buf1_user <= input_user;
						buf1_full <= '1';
					else
						buf0 <= input_data;
						buf0_full <= '1';
						buf0_last <= input_last;
						buf0_user <= input_user;
					end if;
				elsif inner_output_valid = '1' and output_ready = '1' then
					--reading (can happen with one or both buffers full)
					buf1 <= buf0;
					buf1_full <= buf0_full;
					buf1_last <= buf0_last;
					buf1_user <= buf0_user;
					buf0_full <= '0';
				end if;
			end if;
		end if;
	end process;

end Behavioral;
