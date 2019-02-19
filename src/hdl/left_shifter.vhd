----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 18.02.2019 10:28:00
-- Design Name: 
-- Module Name: LEFT_ALIGNER - Behavioral
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
use work.FUNCTIONS.ALL;

entity LEFT_SHIFTER is
	Generic (
		DATA_WIDTH: integer := 39
	);
	Port ( 
		clk, rst		: in	std_logic;
		input_shift		: in 	natural range 0 to DATA_WIDTH;
		input_data		: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_ready		: out	std_logic;
		input_valid		: in	std_logic;
		output_data		: out 	std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_ready	: in	std_logic;
		output_valid	: out	std_logic
	);
end LEFT_SHIFTER;

architecture Behavioral of LEFT_SHIFTER is
	constant IN_BIT_WIDTH: integer := bits(DATA_WIDTH);
	type data_storage_t is array(0 to IN_BIT_WIDTH) of std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	signal memory_curr, memory_next, shifted_values: data_storage_t;
	
	type shiftamt_storage_t is array(0 to IN_BIT_WIDTH) of std_logic_vector(IN_BIT_WIDTH - 1 downto 0);
	
	signal shiftamt_curr: shiftamt_storage_t;
	
	signal valid: std_logic_vector(IN_BIT_WIDTH downto 0);
	
	
	signal enable: std_logic;
begin

	--enable when i have something at the output and it is being read
	--or when i have nothing to output
	enable <= '1' when output_ready = '1' or valid(IN_BIT_WIDTH) = '0' else '0';
	
	output_valid <= valid(IN_BIT_WIDTH);
	input_ready <= enable;
	output_data <= memory_curr(IN_BIT_WIDTH);
	--output_length <= to_integer(unsigned(shiftamt_curr(IN_BIT_WIDTH)));
	
	gen_next_vals: for i in 1 to IN_BIT_WIDTH generate
		memory_next(i) <= shifted_values(i-1) when shiftamt_curr(i-1)(i-1) = '1' else memory_curr(i-1);
	end generate;

	gen_shifts: for i in 0 to IN_BIT_WIDTH - 1 generate
		shifted_values(i) <= memory_curr(i)(DATA_WIDTH - 1 - 2**i downto 2**i) & (2**i - 1 downto 0 => '0');
	end generate;
	
	
	
	
	seq: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then	
				valid <= (others => '0');
			else
				if enable = '1' then
					--do all necessary shifting
					for i in 1 to IN_BIT_WIDTH loop
						memory_curr(i) <= memory_next(i);
						shiftamt_curr(i) <= shiftamt_curr(i-1);
						valid(i) <= valid(i-1);
					end loop;
					if input_valid = '1' then
						--shift in a 1 into the input
						memory_curr(0) <= input_data;
						shiftamt_curr(0) <= std_logic_vector(to_unsigned(input_shift, IN_BIT_WIDTH));
						valid(0) <= '1'; 
					else
						--shift in a 0 into the input
						memory_curr(0) <= (others => '0');
						shiftamt_curr(0) <= (others => '0');
						valid(0) <= '0';
					end if; 
				end if;
			end if;
		end if;
	end process;


	


	


end Behavioral;
