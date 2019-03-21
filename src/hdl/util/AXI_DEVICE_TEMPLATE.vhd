----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12.02.2019 09:18:01
-- Design Name: 
-- Module Name: axi_device_template - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

entity AXI_DEVICE_TEMPLATE is
	Generic (
		DATA_WIDTH: integer := 16
	);
	Port (
		clk, rst: std_logic;
		input_ready: out std_logic;
		input_valid: in std_logic;
		input: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_ready: in std_logic;
		output_valid: out std_logic;
		output: out std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end AXI_DEVICE_TEMPLATE;

architecture Behavioral of AXI_DEVICE_TEMPLATE is
	constant STAGES: integer := 3;
	
	--control signals
	signal device_enable: std_logic;
	
	--segmentation points
	type stage_array is array(0 to STAGES) of std_logic_vector(DATA_WIDTH - 1 downto 0); 
	signal registers: stage_array;
	signal functions: stage_array;
	
	--valid values for each stage
	signal valid_stages: std_logic_vector(STAGES - 1 downto 0);
begin
	
	--general control
	output_valid <= valid_stages(STAGES - 1);
	device_enable <= '1' when valid_stages(STAGES - 1) = '0' or output_ready = '1' else '0';
	input_ready <= device_enable;
	
	--stages
	functions(0) <= input;
	functions(1) <= registers(0);
	functions(2) <= registers(1);
	
	seq: process(clk, rst) 
	begin
		if rising_edge(clk) then
			if rst = '1' then
				valid_stages <= (others => '0');
				for i in 0 to STAGES - 1 loop
					registers(i) <= (others => '0');
				end loop;
			else
				if device_enable = '1' then
					valid_stages(0) <= input_valid;
					for i in 0 to STAGES - 2 loop
						valid_stages(i+1) <= valid_stages(i);
					end loop;
					for i in 0 to STAGES - 1 loop
						registers(i) <= functions(i);
					end loop;
				end if;
			end if;
		end if;
	end process;
	
	output <= registers(STAGES - 1);


end Behavioral;
