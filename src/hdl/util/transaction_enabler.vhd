----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12.02.2019 17:40:46
-- Design Name: 
-- Module Name: transaction_enabler - Behavioral
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

entity TRANSACTION_ENABLER is
	Generic (
		DATA_WIDTH: integer := 16
	);
	Port (
		--metacontrol signals
		enable: in std_logic;
		transaction: out std_logic;
		--axi bus controls (data goes directly, only control signals are dealt with here)
		input_valid: in std_logic;
		input_ready: out std_logic;
		output_valid: out std_logic;
		output_ready: in std_logic
	);
end TRANSACTION_ENABLER;

architecture Behavioral of TRANSACTION_ENABLER is

begin

	input_ready  <= output_ready when enable = '1' else '0';
	output_valid <= input_valid when enable = '1' else '0';
	transaction <= '1' when enable = '1' and output_ready = '1' and input_valid = '1' else '0';


end Behavioral;
