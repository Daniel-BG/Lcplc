----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 12.02.2019 15:39:07
-- Design Name: 
-- Module Name: AXIS_ACCUMULATOR - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: An AXI_STREAM accumulator. Starting at zero, it adds values (either
-- 		in a signed or unsigned way) to an internal accumulator. As soon as the tlast
-- 		input goes high, it adds the last value that comes in input_data, and the next 
-- 		cycle it is ready to go in the output. After that value is read, the accumulator
--		restarts. Make sure to leave enough margin between the DATA_WIDTH and the 
--		ACCUMULATOR_WIDTH to not cause overflow, since that is not checked by the module
-- Dependencies: None
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.functions.all;

entity AXIS_ACCUMULATOR is
	Generic (
		DATA_WIDTH			: integer := 36;
		COUNT_LOG			: integer := 8;
		IS_SIGNED			: boolean := true
	);
	Port (
		clk, rst	: in  std_logic;
		input_data	: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_valid	: in  std_logic;
		input_ready	: out std_logic;
		input_last	: in std_logic;
		output_data	: out std_logic_vector(COUNT_LOG + DATA_WIDTH - 1 downto 0);
		output_valid: out std_logic;
		output_ready: in  std_logic
	);
end AXIS_ACCUMULATOR;

architecture Behavioral of AXIS_ACCUMULATOR is
	--counter signals
	type acc_state_t is (READING, OUTPUTTING);
	signal acc_state_curr, acc_state_next: acc_state_t;
	
	constant ACCUMULATOR_WIDTH: integer := DATA_WIDTH + COUNT_LOG;
	signal accumulator, accumulator_next, accumulator_plus_input: std_logic_vector(ACCUMULATOR_WIDTH - 1 downto 0);
begin

	assert COUNT_LOG >= 2 report "Max count should be greater or equal than 2" severity error; 

	gen_acc_plus_signed: if IS_SIGNED generate
		accumulator_plus_input <= std_logic_vector(signed(accumulator) + resize(signed(input_data), ACCUMULATOR_WIDTH));
	end generate;
	gen_acc_plus_unsigned: if not IS_SIGNED generate
		accumulator_plus_input <= std_logic_vector(unsigned(accumulator) + resize(unsigned(input_data), ACCUMULATOR_WIDTH));
	end generate;
	
	seq: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				acc_state_curr <= READING;
				accumulator <= (others => '0');
			else 
				acc_state_curr <= acc_state_next;
				accumulator <= accumulator_next;
			end if;
		end if;
	end process;
	
	comb: process(acc_state_curr, accumulator, accumulator_plus_input, output_ready, input_valid, input_last)
	begin
		acc_state_next <= acc_state_curr;
		accumulator_next <= accumulator;
		input_ready <= '0';
		output_valid <= '0';
	
		if acc_state_curr = READING then
			input_ready <= '1';
			if input_valid = '1' then
				accumulator_next <= accumulator_plus_input;
				if input_last = '1' then
					acc_state_next <= OUTPUTTING;
				end if;
			end if; 
		elsif acc_state_curr = OUTPUTTING then
			output_valid <= '1';
			if output_ready = '1' then
				accumulator_next <= (others => '0');
				acc_state_next <= READING;
			end if;
		end if;
	end process;
	
	output_data <= accumulator;
	
	
	
end Behavioral;
