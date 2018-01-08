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

use work.JypecConstants.all;


entity tb_ebcoder_connectivity is
	generic (
		ROWS: integer := 64;
		COLS: integer := 64;
		BITPLANES: integer := 16
	);
end tb_ebcoder_connectivity;

architecture Behavioral of tb_ebcoder_connectivity is

	signal clk: std_logic := '0';
	signal rst: std_logic := '0';
	signal clk_en: std_logic := '0';
	signal data_in: std_logic_vector(BITPLANES - 1 downto 0) := (others => '0');
	signal data_in_en: std_logic := '0';
	signal busy: std_logic;
	signal out_bytes: std_logic_vector(23 downto 0);
	signal valid: std_logic_vector(2 downto 0);
	
	
	constant clk_period : time := 40 ns;
	
	
	---save output
	type data_file_t is file of character;
	file out_file : data_file_t open write_mode is "out_test.bin";
--	file out_file_context : data_file_t open write_mode is "out_test_context.bin";
	constant CYCLES_TO_WRITE: integer := 10000;
	
	signal finished: boolean := false;
	
	
	--inner signals
	--alias mqcoder_enable is <<signal .tb_ebcoder_connectivity.uut.mqcoder_enable : std_logic>>;
	
--	signal debug_enable: std_logic;
--	signal debug_context: context_label_t;
--	signal debug_bit: std_logic;
	
begin

	uut: entity work.EBCoder
		generic map(
			ROWS => ROWS,
			COLS => COLS,
			BITPLANES => BITPLANES
		)
		port map (
			clk => clk,
			rst => rst,
			clk_en => clk_en,
			data_in => data_in,
			data_in_en => data_in_en,
			busy => busy,
			out_bytes => out_bytes,
			valid => valid
--			debug_enable => debug_enable,
--			debug_context => debug_context,
--			debug_bit => debug_bit
		);
		
		
	-- Clock process definitions
	clk_process: process
	begin
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
		clk <= '0';
	end process;
	
	
--	save_context: process
--	begin
--		--write until finished
--		while true loop
--			wait for clk_period;
--			if (finished) then
--				exit;
--			end if;
--			--here we are on the falling edge, save here since signals are stable (only when they are ready and not undefined)
--			if (debug_enable = '1') then	
--				if (debug_bit = '0') then
--					write(out_file_context, CHARACTER'VAL(128));
--				else
--					write(out_file_context, CHARACTER'VAL(192));
--				end if;
				
--				write(out_file_context, CHARACTER'VAL(debug_context));
				
--				--debug_context => debug_context,
--				--debug_bit => debug_bit
--			end if;
--			if (rst = '1') then
--				write(out_file_context, CHARACTER'VAL(255));
--			end if;
--		end loop;
--		report "Output file written!!!";
--		wait; --do not write again
--	end process;
	
		
	
	-- Clock process definitions
	save_process: process
		variable busy_up: boolean := false;
	begin
		--write until finished
		while true loop
			wait for clk_period/2;
			wait for clk_period/2;
			--check for busy indicator starting up
			if (busy = '1' and not busy_up) then
				busy_up := true;
			end if;	
			--if busy falls then end 
			if (busy_up and not busy = '1') then
			--if (finished) then
				exit;
			end if;
			--here we are on the falling edge, save here since signals are stable (only when they are ready and not undefined)
			if (not is_x(valid)) then
				for i in 2 downto 0 loop
					if (valid(i) = '1' and clk_en = '1') then
						write(out_file, CHARACTER'VAL( to_integer(unsigned(out_bytes(i*8+7 downto i*8)))));
						--report "Writing stuff: " & integer'image(to_integer(unsigned(out_bytes(i*8+7 downto i*8)))) &  "(" & integer'image(i) & ")" & LF;
					end if;
				end loop;
			end if;
			if (rst = '1') then
				write(out_file, CHARACTER'VAL(0));
			end if;
		end loop;
		report "Output file written!!!";
		wait; --do not write again
	end process;

	input: process
		variable i: integer := 0;
		variable PRIME: integer := 9973;
		
		--code that repeats
		procedure send(quantity : in integer) is begin
			i := 0;
			while i <= quantity loop
				data_in <= std_logic_vector(to_unsigned((i*PRIME) mod (2**BITPLANES), BITPLANES));
				data_in_en <= '1';
				wait for clk_period;
				data_in_en <= '0';
				wait for clk_period*10;
				i := i + 1;
			end loop;
		end send;
		
		procedure reset is begin
			rst <= '1';
			wait for clk_period*4;
			rst <= '0';
		end reset;
		
		procedure wait_for_clk(quantity: in integer) is begin
			wait for clk_period*quantity;
		end wait_for_clk;
		
	begin
		reset;
		clk_en <= '1';
	
		wait for clk_period*20;
		
		send(8192);
		wait_for_clk(100000);
--		reset;
--		send(100);
--		wait_for_clk(100);
--		reset;
--		send(100);
--		wait_for_clk(100);
--		reset;
--		send(100);
--		wait_for_clk(100);
--		reset;
--		send(100);
--		wait_for_clk(100);
--		reset;
--		send(100);
--		wait_for_clk(100);
--		reset;
--		send(100);
--		wait_for_clk(100);
		
		finished <= true;
		wait;
		
	end process;
	


end Behavioral;
