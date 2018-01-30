----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 21.12.2017 16:27:33
-- Design Name: 
-- Module Name: tb_logic - Behavioral
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


entity tb_logic is
	generic (
		ROWS: integer := 64;
		COLS: integer := 64;
		BITPLANES: integer := 16;
		QUEUE_SIZE: integer := 32
	);
end tb_logic;

architecture Behavioral of tb_logic is

	constant clk_period : time := 40 ns;
	
	signal clk, rst: std_logic;
	signal fifoin_wren:	std_logic; 
	signal fifoin_in: std_logic_vector(7 downto 0); 
	signal fifoout_empty: std_logic; 
	signal fifoout_out:	std_logic_vector(7 downto 0); 
	signal fifoout_readen: std_logic;
	signal busy: std_logic;
	
	type data_file_t is file of character;
	file out_file : data_file_t open write_mode is "out_test.bin";


begin

	uut: entity work.logic 
	generic map (
		ROWS => ROWS,
		COLS => COLS,
		BITPLANES => BITPLANES,
		QUEUE_SIZE => QUEUE_SIZE
	)
	port map (
		clk => clk, 
		rst => rst,
		fifoin_wren => fifoin_wren,
		fifoin_in => fifoin_in,
		fifoin_full => open,
		fifoout_empty => fifoout_empty, 
		fifoout_out => fifoout_out, 
		fifoout_readen => fifoout_readen, 
		ebcoder_busy => busy,
		debug => open
	);
	
	
				
	-- Clock process definitions
	clk_process: process
	begin
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
		clk <= '0';
	end process;
	
	input: process
		variable i: integer := 0;
		variable PRIME: integer := 9973;
		
		
		
		--code that repeats
		procedure send(quantity : in integer) is begin
			i := 0;
			while i <= quantity loop
				fifoin_in <= std_logic_vector(to_unsigned(((i*PRIME) / (2**8)) mod (2**8), 8));
				fifoin_wren <= '1';
				wait for clk_period;
				fifoin_in <= std_logic_vector(to_unsigned((i*PRIME) mod (2**8), 8));
				wait for clk_period;
				fifoin_wren <= '0';
				wait for clk_period*2;
				i := i + 1;
			end loop;
		end send;
		
		procedure reset is begin
			rst <= '1';
			--fifoout_readen <= '0';
			wait for clk_period*4;
			rst <= '0';
			--fifoout_readen <= '1';
		end reset;
		
		procedure wait_for_clk(quantity: in integer) is begin
			wait for clk_period*quantity;
		end wait_for_clk;
		
	begin
		reset;
	
		wait for clk_period*20;
		
		send(8192);
		wait_for_clk(100000);
		
		wait;
		
	end process;
	
	
		-- Clock process definitions
	save_process: process
		variable busy_up: boolean := false;
		variable idlecount: integer := 0;
		variable idlemax: integer := 200;
	begin
		fifoout_readen <= '0';
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
				idlecount := idlecount + 1;
				if (idlecount > idlemax) then
					exit; --wait for the queue to empty
				end if;
			end if;
			--here we are on the falling edge, save here since signals are stable (only when they are ready and not undefined)
			
			if (fifoout_empty = '0') then
				fifoout_readen <= '1';
				wait for clk_period;
				fifoout_readen <= '0';
				write(out_file, CHARACTER'VAL( to_integer(unsigned(fifoout_out))));
			end if;
			
			if (rst = '1') then
				write(out_file, CHARACTER'VAL(0));
			end if;
		end loop;
		report "Output file written!!!";
		wait; --do not write again
	end process;


end Behavioral;
