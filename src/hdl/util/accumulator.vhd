----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12.02.2019 15:39:07
-- Design Name: 
-- Module Name: accumulator - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ACCUMULATOR is
	Generic (
		DATA_WIDTH: integer := 36;
		ACC_LOG: integer := 8;
		IS_SIGNED: boolean := true
	);
	Port (
		clk, rst: in std_logic;
		input: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_valid: in std_logic;
		input_ready: out std_logic;
		output_data: out std_logic_vector(DATA_WIDTH + ACC_LOG - 1 downto 0);
		output_valid: out std_logic;
		output_ready: in std_logic
	);
end ACCUMULATOR;

architecture Behavioral of ACCUMULATOR is
	type acc_state_t is (READING, OUTPUTTING);
	signal acc_state_curr, acc_state_next: acc_state_t;
	
	signal counter, counter_next: natural range 0 to 2**ACC_LOG - 1;
	
	signal accumulator, accumulator_next, accumulator_plus_input: std_logic_vector(DATA_WIDTH + ACC_LOG - 1 downto 0);
begin

	gen_acc_plus_signed: if IS_SIGNED generate
		accumulator_plus_input <= std_logic_vector(signed(accumulator) + signed((ACC_LOG - 1 downto 0 => '0') & input));
	end generate;
	gen_acc_plus_unsigned: if not IS_SIGNED generate
		accumulator_plus_input <= std_logic_vector(unsigned(accumulator) + unsigned((ACC_LOG - 1 downto 0 => '0') & input));
	end generate;
	
	seq: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				acc_state_curr <= READING;
				counter <= 0;
				accumulator <= (others => '0');
			else 
				acc_state_curr <= acc_state_next;
				counter <= counter_next;
				accumulator <= accumulator_next;
			end if;
		end if;
	end process;
	
	comb: process(acc_state_curr, counter, accumulator, accumulator_plus_input, output_ready, input_valid)
	begin
		acc_state_next <= acc_state_curr;
		counter_next <= counter;
		accumulator_next <= accumulator;
		input_ready <= '0';
		output_valid <= '0';
	
		if acc_state_curr = READING then
			input_ready <= '1';
			if input_valid = '1' then
				accumulator_next <= accumulator_plus_input;
				acc_state_next <= OUTPUTTING;
				if counter = 2**ACC_LOG - 1 then
					counter_next <= 0;
				else
					counter_next <= counter + 1;
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
