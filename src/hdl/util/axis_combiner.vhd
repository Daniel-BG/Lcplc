----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 14.02.2019 12:54:33
-- Design Name: 
-- Module Name: AXIS_COMBINER - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Combine two buses into one. Take FROM_PORT_ZERO samples from the
--		first bus and then FROM_PORT_ONE from second bus. Repeat forever
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

entity AXIS_COMBINER is
	Generic (
		DATA_WIDTH: integer := 16;
		FROM_PORT_ZERO: integer := 256;
		FROM_PORT_ONE: integer := 256
	);
	Port ( 
		clk, rst: in std_logic;
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
end AXIS_COMBINER;

architecture Behavioral of AXIS_COMBINER is
	
	signal read_from_zero: boolean;
	
	signal counter_zero_enable, counter_zero_saturating: std_logic;
	signal counter_one_enable, counter_one_saturating: std_logic;
	
begin

	counter_zero: entity work.COUNTER 
		Generic map (
			COUNT => FROM_PORT_ZERO
		)
		Port map ( 
			clk => clk, rst	=> rst,
			enable		=> counter_zero_enable,
			saturating	=> counter_zero_saturating
		);

	counter_one: entity work.COUNTER 
		Generic map (
			COUNT => FROM_PORT_ONE
		)
		Port map ( 
			clk => clk, rst	=> rst,
			enable		=> counter_one_enable,
			saturating	=> counter_one_saturating
		);

	input_ready_0 <= output_ready when read_from_zero else '0';
	input_ready_1 <= output_ready when not read_from_zero else '0';
	
	output_valid  <= input_valid_0 when read_from_zero else
					 input_valid_1;
	output_data   <= input_data_0 when read_from_zero else 
					 input_data_1; 

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				read_from_zero <= true;
			else
				counter_zero_enable <= '0';
				counter_one_enable <= '0';
				
				if read_from_zero then
					if input_valid_0 = '1' and output_ready = '1' then
						counter_zero_enable <= '1';
						if counter_zero_saturating = '1' then
							read_from_zero <= false;
						end if;
					end if;
				elsif not read_from_zero then
					if input_valid_1 = '1' and output_ready = '1' then
						counter_one_enable <= '1';
						if counter_one_saturating = '1' then
							read_from_zero <= true;
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;


end Behavioral;
