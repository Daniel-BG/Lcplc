----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 14.02.2019 12:54:33
-- Design Name: 
-- Module Name: AXIS_MERGER_BASE - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Module that connects the input buses for the given amount of times
--		with the outputs. The last input is left connected until clear or rst is
--		brought up. As long as clear is held up, the first axis bus is connected so 
--		transactions will be made through it!
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
use work.constants.all;

entity AXIS_MERGER_BASE is
	Generic (
		DATA_WIDTH: integer := 16;
		NUMBER_OF_PORTS: integer := 4;
		START_ON_PORT: integer := 0;
		USER_WIDTH: integer := 1
	);
	Port ( 
		clk, rst: in std_logic;
		--to input axi port
		input_valid 	: in  std_logic_vector(NUMBER_OF_PORTS - 1 downto 0);
		input_ready 	: out std_logic_vector(NUMBER_OF_PORTS - 1 downto 0);
		input_data 		: in  std_logic_vector(NUMBER_OF_PORTS * DATA_WIDTH - 1 downto 0);
		input_last 		: in  std_logic_vector(NUMBER_OF_PORTS - 1 downto 0);
		input_merge		: in  std_logic_vector(NUMBER_OF_PORTS - 1 downto 0);
		input_user		: in  std_logic_vector(NUMBER_OF_PORTS * USER_WIDTH - 1 downto 0);
		--to output axi ports
		output_valid	: out std_logic;
		output_ready	: in  std_logic;
		output_data		: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_last 	: out std_logic;
		output_user		: out std_logic_vector(USER_WIDTH - 1 downto 0)
	);
end AXIS_MERGER_BASE;

architecture Behavioral of AXIS_MERGER_BASE is
	signal port_curr, port_next: natural range 0 to NUMBER_OF_PORTS - 1;
	
begin

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				port_curr <= START_ON_PORT;
			else
				port_curr <= port_next;
			end if;
		end if;
	end process;

	comb: process(port_curr, input_valid, input_data, input_last, input_user, input_merge, output_ready)
	begin
		port_next <= port_curr;
		input_ready <= (others => '0');
		input_ready(port_curr) <= output_ready;
		output_valid <= input_valid(port_curr);
		output_data  <= input_data(DATA_WIDTH*(port_curr+1) - 1 downto DATA_WIDTH*port_curr);
		output_user  <= input_user(USER_WIDTH*(port_curr+1) - 1 downto USER_WIDTH*port_curr);
		output_last  <= input_last(port_curr);
		
		if input_valid(port_curr) = '1' and output_ready = '1' then
			if input_merge(port_curr) = '1' then
				if port_curr = NUMBER_OF_PORTS - 1 then
					port_next <= 0;
				else
					port_next <= port_curr + 1;
				end if;
			end if;
		end if;
 	end process;


end Behavioral;
