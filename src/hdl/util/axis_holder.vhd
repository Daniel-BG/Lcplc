----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 22.02.2019 14:52:10
-- Design Name: 
-- Module Name: AXIS_HOLDER - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Holds a value until the clear signal is issued, then it holds nothing 
-- 		until it can retrieve another value from input
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

entity AXIS_HOLDER is
	Generic (
		DATA_WIDTH: integer := 16
	);
	Port (
		clk, rst		: in  std_logic;
		clear_ready		: out  std_logic;
		clear_valid		: in  std_logic;
		clear_data		: in  std_logic;
		input_ready		: out std_logic;
		input_valid		: in  std_logic;
		input_data		: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_ready	: in  std_logic;
		output_valid	: out std_logic;
		output_data		: out std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end AXIS_HOLDER;

architecture Behavioral of AXIS_HOLDER is
	type state_holder_t is (EMPTY, PRIMED);
	signal state_curr, state_next: state_holder_t;

	signal buf, buf_next: std_logic_vector(DATA_WIDTH - 1 downto 0);
begin

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= EMPTY;
				buf <= (others => '0');
			else
				state_curr <= state_next;
				buf <= buf_next;
			end if;
		end if;
	end process;

	output_data <= buf;

	comb: process(state_curr, input_valid, clear_valid, output_ready, clear_data, buf, input_data)
	begin
		input_ready <= '0';
		buf_next <= buf;
		clear_ready <= '0';
		state_next <= state_curr;
		output_valid <= '0';

		if state_curr = EMPTY then
			input_ready <= '1';
			if input_valid = '1' then
				state_next <= PRIMED;
				buf_next   <= input_data;
			end if;
		elsif state_curr = PRIMED then
			output_valid <= clear_valid;
			clear_ready  <= output_ready;
			--if a transaction is done check it to see
			--if we need to empty buffer
			if clear_valid = '1' and output_ready = '1' then
				if clear_data = '1' then
					input_ready <= '1';
					if input_valid = '1' then
						buf_next <= input_data;
					else
						state_next <= EMPTY;
					end if;
				end if;
			end if;
		end if;
	end process;

end Behavioral;
