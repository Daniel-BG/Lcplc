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

entity filter_axi is
	Generic (
		DATA_WIDTH: integer := 32;
		VALID_TRANSACTIONS: integer := 255;
		INVALID_TRANSACTIONS: integer := 1;
		START_VALID: boolean := true
	);
	Port (
		clk, rst: in std_logic;
		input_ready:	out	std_logic;
		input_valid:	in	std_logic;
		input_data: 	in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_ready:	in 	std_logic;
		output_valid:	out	std_logic;
		output_data:	out	std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end filter_axi;

architecture Behavioral of filter_axi is
	type filter_state_t is (VALID, INVALID);
	signal state_curr, state_next, state_first: filter_state_t;

	signal valid_counter, valid_counter_next: natural range 0 to VALID_TRANSACTIONS - 1;
	signal invalid_counter, invalid_counter_next: natural range 0 to INVALID_TRANSACTIONS - 1;

begin

	output_data <= input_data;

	--first state
	gen_state_first_valid: if START_VALID generate
		state_first <= VALID;
	end generate;
	gen_state_first_invalid: if not START_VALID generate
		state_first <= INVALID;
	end generate;

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				valid_counter <= 0;
				invalid_counter <= 0;
				if START_VALID then
					state_curr <= VALID;
				else
					state_curr <= INVALID;
				end if;
			else
				state_curr <= state_next;
				valid_counter <= valid_counter_next;
				invalid_counter <= invalid_counter_next;
			end if;
		end if;
	end process;
	
	comb: process(state_curr, output_ready, input_valid, valid_counter, invalid_counter)
	begin
		state_next <= state_curr;
		valid_counter_next <= valid_counter;
		invalid_counter_next <= invalid_counter;
		
		if state_curr = VALID then
			input_ready <= output_ready;
			output_valid <= input_valid;
			--check for transaction
			if output_ready = '1' and input_valid = '1' then
				if valid_counter = VALID_TRANSACTIONS - 1 then
					valid_counter_next <= 0;
					state_next <= INVALID;
				else
					valid_counter_next <= valid_counter + 1;
				end if;
			end if;
		elsif state_curr = INVALID then
			input_ready <= '1';
			output_valid <= '0';
			--check for transaction (only on input, output is disconnected)
			if input_valid = '1' then
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
