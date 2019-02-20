----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.02.2019 12:54:33
-- Design Name: 
-- Module Name: SEPARATOR_AXI - Behavioral
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

entity SEPARATOR_AXI is
	Generic (
		DATA_WIDTH: integer := 16;
		TO_PORT_ZERO: integer := 1;
		TO_PORT_ONE: integer := 255
	);
	Port ( 
		clk, rst: in std_logic;
		--to input axi port
		input_valid		: in	std_logic;
		input_ready		: out	std_logic;
		input_data		: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		--to output axi ports
		output_valid_0	: out 	std_logic;
		output_ready_0	: in 	std_logic;
		output_data_0	: out	std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_valid_1	: out 	std_logic;
		output_ready_1	: in 	std_logic;
		output_data_1	: out	std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end SEPARATOR_AXI;

architecture Behavioral of SEPARATOR_AXI is
	type separator_state_t is (PORT_ZERO, PORT_ONE);
	signal state_curr, state_next: separator_state_t;
	
	signal counter_zero, counter_zero_next: natural range 0 to TO_PORT_ZERO - 1;
	signal counter_one, counter_one_next: natural range 0 to TO_PORT_ONE - 1;
begin

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= PORT_ZERO;
				counter_zero <= 0;
				counter_one <= 0;
			else
				state_curr <= STATE_NEXT;
				counter_zero <= counter_zero_next;
				counter_one <= counter_one_next;
			end if;
		end if;
	end process;
	
	output_data_0 <= input_data;
	output_data_1 <= input_data;
	
	comb: process(state_curr, output_ready_0, output_ready_1, input_valid, counter_zero, counter_one)
	begin
		state_next <= state_curr;
		counter_zero_next <= counter_zero;
		counter_one_next <= counter_one;
		
		if state_curr = PORT_ZERO then
			input_ready <= output_ready_0;
			output_valid_0 <= input_valid;
			output_valid_1 <= '0';
			--check if a transaction is made
			if input_valid = '1' and output_ready_0 = '1' then
				if counter_zero = TO_PORT_ZERO - 1 then
					counter_zero_next <= 0;
					state_next <= PORT_ONE;
				else
					counter_zero_next <= counter_zero + 1;
				end if;
			end if;
		elsif state_curr = PORT_ONE then
			input_ready <= output_ready_1;
			output_valid_1 <= input_valid;
			output_valid_0 <= '0';
			--check if a transaction is made
			if input_valid = '1' and output_ready_1 = '1' then
				if counter_one = TO_PORT_ONE - 1 then
					counter_one_next <= 0;
					state_next <= PORT_ZERO;
				else
					counter_one_next <= counter_one + 1;
				end if;
			end if;
		end if;
	end process;

end Behavioral;
