----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.02.2019 10:18:12
-- Design Name: 
-- Module Name: WORD_MERGER - Behavioral
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

entity WORD_MERGER is
	Generic (
		WORD_WIDTH: integer := 32
	);
	Port (
		clk, rst		: in	std_logic;
		input_data		: in 	std_logic_vector(WORD_WIDTH-1 downto 0);
		input_ends_word : in	std_logic;
		input_valid		: in 	std_logic;
		input_ready		: out	std_logic;
		output_data		: out	std_logic_vector(WORD_WIDTH-1 downto 0);
		output_valid	: out	std_logic;
		output_ready	: in 	std_logic;
		flush			: in 	std_logic
	);
end WORD_MERGER;

architecture Behavioral of WORD_MERGER is
	signal data_buf, data_buf_next: std_logic_vector(WORD_WIDTH-1 downto 0);
	
begin
	
	seq: process(clk)
	begin
		if rising_Edge(clk) then
			if rst = '1' then
				data_buf <= (others => '0');
			else
				data_buf <= data_buf_next;
			end if;
		end if;
	end process;
	
	
	data_buf_next <=	
		(others => '0') 		when input_ends_word = '1' and input_valid = '1' else
		data_buf				when input_valid = '0' else
		data_buf or input_data; 
	
	output_data <= input_data or data_buf;
	input_ready <= output_ready;
	output_valid <= (input_ends_word and input_valid) or flush;


end Behavioral;
