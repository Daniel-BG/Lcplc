----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.02.2019 16:14:04
-- Design Name: 
-- Module Name: SELECTOR_AXI - Behavioral
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

entity SELECTOR_AXI is
	generic (
		DATA_WIDTH: integer := 16
	);
	port (
		input_data_false:in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_data_true:in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_flag:		in	std_logic;
		input_ready:	out	std_logic;
		input_valid:	in 	std_logic;
		output_data:	out std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_valid:	out std_logic;
		output_ready:	in std_logic
	);
end SELECTOR_AXI;

architecture Behavioral of SELECTOR_AXI is

begin
	input_ready <= output_ready;
	output_valid <= input_valid;
	
	output_data <= input_data_false when input_flag = '0' else input_data_true;

end Behavioral;
