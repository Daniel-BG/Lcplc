----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 22.02.2019 18:08:34
-- Design Name: 
-- Module Name: AXIS_REDUCER - Behavioral
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

entity AXIS_REDUCER is
	Generic (
		DATA_WIDTH: integer := 32;
		VALID_TRANSACTIONS: integer := 255;
		INVALID_TRANSACTIONS: integer := 1;
		START_VALID: boolean := true
	);
	Port (
		clk, rst: in std_logic;
		input_ready:	out	std_logic;
		input_valid:	in	std_logic;
		input_data: 	in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_ready:	in 	std_logic;
		output_valid:	out	std_logic;
		output_data:	out	std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end AXIS_REDUCER;

architecture Behavioral of AXIS_REDUCER is

begin

	gen_valid: if START_VALID generate
		separator: entity work.AXIS_SEPARATOR
			Generic map (
				DATA_WIDTH => DATA_WIDTH,
				TO_PORT_ZERO => VALID_TRANSACTIONS,
				TO_PORT_ONE  => INVALID_TRANSACTIONS
			)
			Port map ( 
				clk => clk, rst => rst,
				--to input axi port
				input_valid		=> input_valid,
				input_ready		=> input_ready,
				input_data		=> input_data,
				--to output axi ports
				output_valid_0	=> output_valid,
				output_ready_0	=> output_ready,
				output_data_0	=> output_data,
				output_valid_1	=> open,
				output_ready_1	=> '1',
				output_data_1	=> open
			);
	end generate;
	
	gen_invalid: if not START_VALID generate
		separator: entity work.AXIS_SEPARATOR
			Generic map (
				DATA_WIDTH => DATA_WIDTH,
				TO_PORT_ZERO => INVALID_TRANSACTIONS,
				TO_PORT_ONE  => VALID_TRANSACTIONS
			)
			Port map ( 
				clk => clk, rst => rst,
				--to input axi port
				input_valid		=> input_valid,
				input_ready		=> input_ready,
				input_data		=> input_data,
				--to output axi ports
				output_valid_0	=> open,
				output_ready_0	=> '1',
				output_data_0	=> open,
				output_valid_1	=> output_valid,
				output_ready_1	=> output_ready,
				output_data_1   => output_data
			);
	end generate;


end Behavioral;
