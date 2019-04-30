----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 30.04.2019 10:28:36
-- Design Name: 
-- Module Name: flag_cross_clock_domain - Behavioral
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

entity flag_cross_clock_domain is
	Generic (
		SUSTAIN_SIGNAL: boolean := true;
		SYNC_STAGES: integer := 2
	);
	Port (
		clk_a, rst_a: in std_logic;
		flag_a: in std_logic;
		clk_b, rst_b: in std_logic;
		flag_b: out std_logic
	);
end flag_cross_clock_domain;

architecture Behavioral of flag_cross_clock_domain is
	signal flag_a_toggle: std_logic;
	signal flag_b_sync: std_logic_vector(SYNC_STAGES downto 0);
begin
	
	not_sustained: if not SUSTAIN_SIGNAL generate
		input_flag_a: process(clk_a)
		begin
			if rising_edge(clk_a) then
				if rst_a = '1' then
					flag_a_toggle <= '0';
				else
					flag_a_toggle <= flag_a_toggle xor flag_a;
				end if;
			end if;
		end process;
		
		update_sync_b: process(clk_b)
		begin
			if rising_edge(clk_b) then
				if rst_b = '1' then
					flag_b_sync <= (others => '0');
				else
					flag_b_sync <= flag_b_sync(SYNC_STAGES-1 downto 0) & flag_a_toggle;
				end if;
			end if;
		end process;
	
		flag_b <= flag_b_sync(SYNC_STAGES) xor flag_b_sync(SYNC_STAGES - 1);
	end generate;
	
	sustained: if SUSTAIN_SIGNAL generate
		update_sync_b: process(clk_b)
		begin
			if rising_edge(clk_b) then
				if rst_b = '1' then
					flag_b_sync <= (others => '0');
				else
					flag_b_sync <= flag_b_sync(SYNC_STAGES - 1 downto 0) & flag_a;
				end if;
			end if;
		end process;
		
		flag_b <= flag_b_sync(SYNC_STAGES);
	end generate;

end Behavioral;
