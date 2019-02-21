----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.02.2019 09:23:30
-- Design Name: 
-- Module Name: filter_axi - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity SUBSTITUTER_AXI is
	Generic (
		DATA_WIDTH: integer := 32;
		INVALID_TRANSACTIONS: integer := 1
	);
	Port (
		clk, rst: in std_logic;
		input_ready:	out	std_logic;
		input_valid:	in	std_logic;
		input_data: 	in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_sub:		in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_ready:	in 	std_logic;
		output_valid:	out	std_logic;
		output_data:	out	std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end SUBSTITUTER_AXI;

architecture Behavioral of SUBSTITUTER_AXI is
	type filter_state_t is (VALID, INVALID);
	signal state_curr, state_next: filter_state_t;

	signal invalid_counter, invalid_counter_next: natural range 0 to INVALID_TRANSACTIONS - 1;

begin

	


	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				invalid_counter <= 0;
				state_curr <= INVALID;
			else
				state_curr <= state_next;
				invalid_counter <= invalid_counter_next;
			end if;
		end if;
	end process;
	
	input_ready <= output_ready;
	output_valid <= input_valid;
	
	comb: process(state_curr, output_ready, input_valid, invalid_counter)
	begin
		state_next <= state_curr;
		invalid_counter_next <= invalid_counter;
		
		if state_curr = VALID then
			output_data <= input_data;
		elsif state_curr = INVALID then
			output_data <= input_sub;
			--check for transaction (only on input, output is disconnected)
			if input_valid = '1' and output_ready = '1' then
				if invalid_counter = INVALID_TRANSACTIONS - 1 then
					invalid_counter_next <= 0;
					state_next <= VALID;
				else
					invalid_counter_next <= invalid_counter + 1;
				end if;
			end if;
		end if;
	end process;


end Behavioral;
