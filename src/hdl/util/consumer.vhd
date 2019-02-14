----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 13.02.2019 17:41:01
-- Design Name: 
-- Module Name: consumer - Behavioral
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

entity consumer is
	Generic (
		DATA_WIDTH: integer := 32
	);
	Port (
		clk, rst: in std_logic;
		input_ready	: out std_logic;
		input_valid	: in std_logic;
		input_data	: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_valid: out std_logic;
		--output_ready: in std_logic; --no need for this
		output_data	: out std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end consumer;

architecture Behavioral of consumer is
	signal buf: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal buf_full: std_logic;
begin

	input_ready <= '1';
	
	output_valid <= buf_full;
	output_data <= buf;
	
	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				buf_full <= '0';
				buf <= (others => '0');
			elsif input_valid = '1' then
				buf <= input_data;
				buf_full <= '1';
			end if;
		end if;
	end process;


end Behavioral;
