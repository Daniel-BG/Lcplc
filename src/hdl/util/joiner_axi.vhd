----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12.02.2019 19:01:39
-- Design Name: 
-- Module Name: joiner_axi - Behavioral
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

entity JOINER_AXI is
	Generic (
		DATA_WIDTH_0: integer := 32;
		DATA_WIDTH_1: integer := 32
	);
	Port (
		--to input axi port
		input_valid_0, input_valid_1: in std_logic;
		input_ready_0, input_ready_1: out std_logic;
		input_data_0: in std_logic_vector(DATA_WIDTH_0 - 1 downto 0);
		input_data_1: in std_logic_vector(DATA_WIDTH_1 - 1 downto 0);
		--to output axi ports
		output_valid	: out 	STD_LOGIC;
		output_ready	: in 	STD_LOGIC;
		output_data_0: out std_logic_vector(DATA_WIDTH_0 - 1 downto 0);
		output_data_1: out std_logic_vector(DATA_WIDTH_1 - 1 downto 0)
	);
end JOINER_AXI;

architecture Behavioral of JOINER_AXI is
	signal all_ready: std_logic;
begin

	output_data_0 <= input_data_0;
	output_data_1 <= input_data_1;
	
	all_ready <= '1' when input_valid_0 = '1' and input_valid_1 = '1' and output_ready = '1' else '0';
	
	output_valid    <= all_ready;
	input_ready_0   <= all_ready;
	input_ready_1   <= all_ready;

end Behavioral;
