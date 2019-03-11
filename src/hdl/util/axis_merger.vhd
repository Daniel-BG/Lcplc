----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 14.02.2019 12:54:33
-- Design Name: 
-- Module Name: merger_axi - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Module that connects the input buses for the given amount of times
--		with the outputs. The last input is left connected until clear or rst is
--		brought up. As long as clear is held up, the first axis bus is connected so 
--		transactions will be made through it!
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

entity AXIS_MERGER is
	Generic (
		DATA_WIDTH: integer := 16;
		START_ON_PORT: integer := 0
	);
	Port ( 
		clk, rst: in std_logic;
		--to input axi port
		input_0_valid	: in	std_logic;
		input_0_ready	: out	std_logic;
		input_0_data	: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_0_last	: in	std_logic;
		input_1_valid	: in	std_logic;
		input_1_ready	: out	std_logic;
		input_1_data	: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_1_last	: in 	std_logic;
		input_2_valid	: in	std_logic;
		input_2_ready	: out	std_logic;
		input_2_data	: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_2_last	: in 	std_logic;
		input_3_valid	: in	std_logic;
		input_3_ready	: out	std_logic;
		input_3_data	: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_3_last	: in 	std_logic;
		--to output axi ports
		output_valid	: out 	std_logic;
		output_ready	: in 	std_logic;
		output_data		: out	std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end AXIS_MERGER;

architecture Behavioral of AXIS_MERGER is
	type merger_state_t is (READING_PORT_ZERO, READING_PORT_ONE, READING_PORT_TWO, READING_PORT_THREE);
	signal state_curr, state_next: merger_state_t;
	
begin


	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				if START_ON_PORT <= 0 then
					state_curr <= READING_PORT_ZERO;
				elsif START_ON_PORT = 1 then
					state_curr <= READING_PORT_ONE;
				elsif START_ON_PORT = 2 then
					state_curr <= READING_PORT_TWO;
				elsif START_ON_PORT >= 3 then
					state_curr <= READING_PORT_THREE;					
				end if;
			else
				state_curr <= state_next;
			end if;
		end if;
	end process;

	comb: process(state_curr, 
		input_0_valid, input_1_valid, input_2_valid, input_3_valid,
		input_0_data, input_1_data, input_2_data, input_3_data,
		input_0_last, input_1_last, input_2_last, input_3_last,
		output_ready)
	begin
		state_next <= state_curr;

		input_0_ready <= '0';
		input_1_ready <= '0';
		input_2_ready <= '0';
		input_3_ready <= '0';
		output_valid  <= '0';
		output_data   <= (others => '0');

		if state_curr = READING_PORT_ZERO then
			input_0_ready <= output_ready;
			output_valid  <= input_0_valid;
			output_data   <= input_0_data;
			if input_0_valid = '1' and output_ready = '1' then
				if input_0_last = '1' then
					state_next <= READING_PORT_ONE;
				end if;
			end if;
		elsif state_curr = READING_PORT_ONE then
			input_1_ready <= output_ready;
			output_valid  <= input_1_valid;
			output_data   <= input_1_data;
			if input_1_valid = '1' and output_ready = '1' then
				if input_1_last = '1' then
					state_next <= READING_PORT_TWO;
				end if;
			end if;
		elsif state_curr = READING_PORT_TWO then
			--stay here
			input_2_ready <= output_ready;
			output_valid  <= input_2_valid;
			output_data   <= input_2_data;
			if input_2_valid = '1' and output_ready = '1' then
				if input_2_last = '1' then
					state_next <= READING_PORT_THREE;
				end if;
			end if;
		elsif state_curr = READING_PORT_THREE then
			--stay here
			input_3_ready <= output_ready;
			output_valid  <= input_3_valid;
			output_data   <= input_3_data;
			if input_3_valid = '1' and output_ready = '1' then
				if input_3_last = '1' then
					state_next <= READING_PORT_ZERO;
				end if;
			end if;
		end if;
 	end process;


end Behavioral;
