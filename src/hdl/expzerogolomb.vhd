----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 15.02.2019 09:28:59
-- Design Name: 
-- Module Name: exp_zero_golomb - Behavioral
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

entity EXP_ZERO_GOLOMB is
	Generic (
		DATA_WIDTH: integer := 19
	);
	Port (
		input_data	: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_valid	: in	std_logic;
		input_ready	: out	std_logic;
		output_code	: out	std_logic_vector(DATA_WIDTH*2 downto 0);
		output_length:out	natural range 0 to DATA_WIDTH*2+1;
		output_valid: out	std_logic;
		output_ready: in 	std_logic
	);
end EXP_ZERO_GOLOMB;

architecture Behavioral of EXP_ZERO_GOLOMB is
	signal input_plus_one: std_logic_vector(DATA_WIDTH downto 0);
	
	signal final_bit_count: natural range 1 to DATA_WIDTH*2 + 1;
begin

	input_plus_one <= std_logic_vector(unsigned("0" & input_data) + to_unsigned(1, DATA_WIDTH+1));
	
	get_bit_cnt: process(input_plus_one)
	begin
		for i in DATA_WIDTH downto 0 loop
			final_bit_count <= 1;
			if input_plus_one(i) = '1' then
				final_bit_count <= 2*i + 1;
				exit;
			end if;
		end loop;
	end process;
	
	output_code <= (DATA_WIDTH*2 downto DATA_WIDTH + 1 => '0') & input_plus_one;
	output_valid <= input_valid;
	input_Ready <= output_ready;
	output_length <= final_bit_count;

	--add 1 to input_data (unsigned)
	--count its number of bits n
	--white n-1 zeroes and then write input_data+1 with n bits


end Behavioral;
