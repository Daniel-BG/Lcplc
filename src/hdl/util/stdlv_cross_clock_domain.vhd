----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 30.04.2019 12:15:51
-- Design Name: 
-- Module Name: stdlv_cross_clock_domain - Behavioral
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

entity stdlv_cross_clock_domain is
	Generic (
		SUSTAIN_SIGNAL: boolean := true;
		SYNC_STAGES: integer := 2;
		SIGNAL_WIDTH: integer := 8
	);
	Port (
		clk_a, rst_a: in std_logic;
		signal_a: in std_logic_vector(SIGNAL_WIDTH - 1 downto 0);
		clk_b, rst_b: in std_logic;
		signal_b: out std_logic_vector(SIGNAL_WIDTH - 1 downto 0)
	);
end stdlv_cross_clock_domain;

architecture Behavioral of stdlv_cross_clock_domain is
begin
	gen_bit_crossing: for i in 0 to SIGNAL_WIDTH - 1 generate
		individual_bit_ccd: entity work.flag_cross_clock_domain
			Generic map (
				SUSTAIN_SIGNAL => SUSTAIN_SIGNAL,
				SYNC_STAGES => SYNC_STAGES
			)
			Port map (
				clk_a => clk_a, rst_a => rst_a,
				flag_a => signal_a(i),
				clk_b => clk_b, rst_b => rst_b,
				flag_b => signal_b(i)
			);
	end generate;
end Behavioral;

