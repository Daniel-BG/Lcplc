----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.02.2019 10:11:24
-- Design Name: 
-- Module Name: data_repeater_axi - Behavioral
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

entity DATA_REPEATER_AXI is
	Generic (
		DATA_WIDTH: integer := 16;
		NUMBER_OF_REPETITIONS: integer := 256
	);
	Port (
		clk, rst: in std_logic;
		input_ready:	out	std_logic;
		input_valid:	in	std_logic;
		input_data:		in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_ready:	in	std_logic;
		output_valid:	out std_logic;
		output_data:	out	std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end DATA_REPEATER_AXI;

architecture Behavioral of DATA_REPEATER_AXI is
	type repeater_state_t is (READING, REPEATING);
	signal state_curr, state_next: repeater_state_t;
	
	signal buf, buf_next: std_logic_vector(DATA_WIDTH - 1 downto 0);

	signal counter, counter_next: natural range 0 to NUMBER_OF_REPETITIONS - 1;
begin

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				counter <= 0;
				state_curr <= READING;
				buf <= (others => '0');
			else
				counter <= counter_next;
				state_curr <= state_next;
				buf <= buf_next;
			end if;
		end if;
	end process;
	
	comb: process(state_curr, input_valid, buf, input_data, output_ready, counter)
	begin
		input_ready <= '0';
		buf_next <= buf;
		state_next <= state_curr;
		output_valid <= '0';
		counter_next <= counter;
	
		if state_curr = READING then
			input_ready <= '1';
			if input_valid = '1' then
				buf_next <= input_data;
				state_next <= REPEATING;
			end if;	
		elsif state_curr = REPEATING then
			output_valid <= '1';
			if output_ready = '1' then
				if counter = NUMBER_OF_REPETITIONS - 1 then
					counter_next <= 0;
					state_next <= READING;
				else
					counter_next <= counter + 1;
				end if;
			end if;
		end if;
	end process;
	
	output_data <= buf;


end Behavioral;
