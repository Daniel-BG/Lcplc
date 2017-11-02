----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02.11.2017 10:38:23
-- Design Name: 
-- Module Name: tb_ebcoder_connectivity - Behavioral
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
use ieee.numeric_std.all;

library std;
use std.textio.all;


entity tb_ebcoder_connectivity is
--  Port ( );
end tb_ebcoder_connectivity;

architecture Behavioral of tb_ebcoder_connectivity is

	signal clk: std_logic := '0';
	signal rst: std_logic := '0';
	signal clk_en: std_logic := '0';
	signal busy: std_logic;
	signal out_bytes: std_logic_vector(23 downto 0);
	signal out_enable: std_logic_vector(2 downto 0);
	
	
	constant clk_period : time := 40 ns;
	
	
	---save output
	file out_file: text is out "out_test.bin";
	shared variable out_line: line; --line number declaration
	constant CYCLES_TO_WRITE: integer := 10000;
	
begin

	uut: entity work.EBCoder
		generic map(
			ROWS => 16,
			COLS => 16,
			BITPLANES => 16
		)
		port map (
			clk => clk,
			rst => rst,
			clk_en => clk_en,
			busy => busy,
			out_bytes => out_bytes,
			out_enable => out_enable
		);
		
		
	-- Clock process definitions
	clk_process: process
	begin
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
		clk <= '0';
	end process;
	
	
	-- Clock process definitions
	save_process: process
	begin
		--write only first 10000 things
		for j in 0 to CYCLES_TO_WRITE loop
			wait for clk_period/2;
			wait for clk_period/2;
			--here we are on the falling edge, save here since signals are stable (only when they are ready and not undefined)
			if (not is_x(out_enable)) then
				for i in 2 downto 0 loop
					if (out_enable(i) = '1') then
						write(out_line, CHARACTER'VAL( to_integer(unsigned(out_bytes(i*8+7 downto i*8)))));
					end if;
				end loop;
			end if;
		end loop;
		writeline(out_file, out_line);
		report "Output file written!!!";
		wait; --do not write again
	end process;


	ctrl: process
	begin
		rst <= '1';
		wait for clk_period*4;
		rst <= '0';
		clk_en <= '1';
		wait;
	end process;

end Behavioral;
