----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11.02.2019 11:32:04
-- Design Name: 
-- Module Name: bitcount_axi - Behavioral
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

entity BITCOUNT_AXI is
	Generic (
		DATA_WIDTH: positive := 32;
		COUNTER_WIDTH: positive := 6 --make this ceil(log2(DATA_WIDTH) + 1) 
	);
	Port (
		data: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		data_ready: out std_logic;
		data_valid: in std_logic;
		bitcount: out std_logic_Vector(COUNTER_WIDTH - 1 downto 0);
		bitcount_ready: in std_logic;
		bitcount_valid: out std_logic
	);
end BITCOUNT_AXI;

architecture Behavioral of BITCOUNT_AXI is

begin


end Behavioral;
