----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.02.2019 12:54:33
-- Design Name: 
-- Module Name: merger_axi - Behavioral
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

entity MERGER_AXI is
	Generic (
		DATA_WIDTH: integer := 16;
		FROM_PORT_ZERO: integer := 256
	);
	Port ( 
		clk, rst: in std_logic;
		clear: in std_logic;
		--to input axi port
		input_valid_0	: in	std_logic;
		input_ready_0	: out	std_logic;
		input_data_0	: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_valid_1	: in	std_logic;
		input_ready_1	: out	std_logic;
		input_data_1	: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		--to output axi ports
		output_valid	: out 	std_logic;
		output_ready	: in 	std_logic;
		output_data		: out	std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end MERGER_AXI;

architecture Behavioral of MERGER_AXI is
	signal counter: natural range 0 to FROM_PORT_ZERO - 1;
	
	signal read_from_zero: boolean;
begin

	input_ready_0 <= output_ready when read_from_zero else '0';
	input_ready_1 <= output_ready when not read_from_zero else '0';
	output_valid  <= input_valid_0 when read_from_zero else input_valid_1;
	
	output_data   <= input_data_0 when read_from_zero else input_data_1; 

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' or clear = '1' then
				counter <= 0;
				read_from_zero <= true;
			else
				if input_valid_0 = '1' and output_ready = '1' then
					if counter = FROM_PORT_ZERO - 1 then
						read_from_zero <= false;
					else
						counter <= counter + 1;
					end if;
				end if;
			end if;
		end if;
	end process;


end Behavioral;
