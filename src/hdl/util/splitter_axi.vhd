----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12.02.2019 18:26:18
-- Design Name: 
-- Module Name: splitter_axi - Behavioral
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

entity SPLITTER_AXI is
	Generic (
		DATA_WIDTH: positive := 32;
		OUTPUT_PORTS: positive := 2
	);
	Port (
		--to input axi port
		input_valid		: in	STD_LOGIC;
		input_data		: in	STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		input_ready		: out	STD_LOGIC;
		--to output axi ports
		output_valid	: out 	STD_LOGIC_VECTOR(OUTPUT_PORTS - 1 downto 0);
		output_data		: out 	STD_LOGIC_VECTOR(DATA_WIDTH*OUTPUT_PORTS - 1 downto 0);
		output_ready	: in 	STD_LOGIC_VECTOR(OUTPUT_PORTS - 1 downto 0)
	);
end SPLITTER_AXI;

architecture Behavioral of SPLITTER_AXI is
	signal all_ready: std_logic;
begin
	gen_output: for i in 1 to OUTPUT_PORTS generate
		output_data(DATA_WIDTH*i - 1 downto DATA_WIDTH*(i-1)) <= input_data;
		output_valid(i-1) <= all_ready;
	end generate;
	
	all_ready <= '1' when output_ready = (output_ready'range => '1') and input_valid = '1' else '0';
	
	input_ready    <= all_ready;

end Behavioral;



--entity SPLITTER_AXI is
--	Generic (
--		DATA_WIDTH: positive := 32;
--		OUTPUT_PORTS: positive := 2
--	);
--	Port (
--		--to input axi port
--		input_valid		: in	STD_LOGIC;
--		input_data		: in	STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
--		input_ready		: out	STD_LOGIC;
--		--to output axi ports
--		output_valid	: out 	STD_LOGIC_VECTOR(OUTPUT_PORTS - 1 downto 0);
--		output_data		: out 	STD_LOGIC_VECTOR(DATA_WIDTH*OUTPUT_PORTS - 1 downto 0);
--		output_ready	: in 	STD_LOGIC_VECTOR(OUTPUT_PORTS - 1 downto 0)
--	);
--end SPLITTER_AXI;

--architecture Behavioral of SPLITTER_AXI is
--	signal all_ready: std_logic;
--begin
--	gen_output: for i in 1 to OUTPUT_PORTS generate
--		output_data(DATA_WIDTH*i - 1 downto DATA_WIDTH*(i-1)) <= input_data;
--		output_valid(i-1) <= all_ready;
--	end generate;
	
--	all_ready <= '1' when output_ready = (output_ready'range => '1') and input_valid = '1' else '0';
	
--	input_ready    <= all_ready;

--end Behavioral;
