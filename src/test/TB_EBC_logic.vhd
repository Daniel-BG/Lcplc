----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:19:22 06/13/2018 
-- Design Name: 
-- Module Name:    TB_EBC_logic - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
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


entity TB_EBC_logic is
	generic (
		COLS: integer := 64;
		STRIPS: integer := 16;
		BITPLANES: integer := 16;
		QUEUE_SIZE: integer := 32
	);
end TB_EBC_logic;

architecture Behavioral of TB_EBC_logic is

	constant clk_period : time := 40 ns;
	
	signal clk, rst, clk_en: std_logic;
	signal input: std_logic_vector((BITPLANES)*4 - 1 downto 0);
	signal input_loc: natural range 0 to COLS*STRIPS - 1;
	signal input_en: std_logic;
	signal fifoout_empty: std_logic; 
	signal fifoout_out:	std_logic_vector(7 downto 0); 
	signal fifoout_readen: std_logic;
	signal done: std_logic;
	
	type data_file_t is file of character;
	file out_file : data_file_t open write_mode is "out_test.bin";


begin

	uut: entity work.BPC_logic
		generic map (
			STRIPS => STRIPS,
			COLS => COLS,
			BITPLANES => BITPLANES - 1
			--OTHERS BY DEFAULT (QUEUE SIZE=32)
		)
		port map (
			clk => clk,
			rst => rst,
			clk_en => clk_en,
			--inputs
			input => input,
			input_loc => input_loc,
			input_en => input_en,
			--outputs
			out_empty => fifoout_empty,
			out_byte => fifoout_out,
			out_readen => fifoout_readen,
			done => done
		);	
	
				
	-- Clock process definitions
	clk_process: process
	begin
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
		clk <= '0';
	end process;
	
	feeding: process	
		--send a block generated with a given prime number
		procedure send_block(prime: in integer) is 
			variable i: integer := 0;
		begin
			while (i < COLS*STRIPS) loop
				input <= std_logic_vector(to_unsigned(((i*4+0)*PRIME) mod (2**BITPLANES), BITPLANES))
						&	std_logic_vector(to_unsigned(((i*4+1)*PRIME) mod (2**BITPLANES), BITPLANES))
						&	std_logic_vector(to_unsigned(((i*4+2)*PRIME) mod (2**BITPLANES), BITPLANES))
						&	std_logic_vector(to_unsigned(((i*4+3)*PRIME) mod (2**BITPLANES), BITPLANES));
				input_loc <= i;
				input_en <= '1';
				wait for clk_period;
				i := i + 1;
			end loop;
		end send_block;
		
		
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
	
		wait for clk_period*20;
		
		send_block(9973);
		--send_block(7);
		clk_en <= '1';
		
		wait_for_clk(100000);
		
		wait;
		
	end process;
	
	
		-- Clock process definitions
	save_process: process
	begin
		--always read
		fifoout_readen <= '1';
		--write until finished
		while true loop
			if (fifoout_empty = '0') then
				wait for clk_period;
				write(out_file, CHARACTER'VAL( to_integer(unsigned(fifoout_out))));
			else
				wait for clk_period;
				if (rst = '1') then
					write(out_file, CHARACTER'VAL(0));
				end if;
				
				if (done = '1') then
					exit;
				end if;
			end if;
		end loop;
		report "Output file written!!!";
		wait; --do not write again
	end process;


end Behavioral;

