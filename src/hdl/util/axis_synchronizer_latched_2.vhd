----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 12.02.2019 19:01:39
-- Design Name: 
-- Module Name: AXIS_SYNCHRONIZER_LATCHED_2 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Synchronize two axis streams into only one. 
--		Data outputs are kept separate for ease of use
--		Latches the control signals so that critical paths
--		can be reduced. This adds a layer of registers for data and
--		control, so the module is more expensive FF-wise
-- 
-- Dependencies: None
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity AXIS_SYNCHRONIZER_LATCHED_2 is
	Generic (
		DATA_WIDTH_0: integer := 32;
		DATA_WIDTH_1: integer := 32
	);
	Port (
		clk, rst: in std_logic;
		--to input axi port
		input_0_valid: in  std_logic;
		input_0_ready: out std_logic;
		input_0_data : in  std_logic_vector(DATA_WIDTH_0 - 1 downto 0);
		input_1_valid: in  std_logic;
		input_1_ready: out std_logic; 
		input_1_data : in  std_logic_vector(DATA_WIDTH_1 - 1 downto 0);
		--to output axi ports
		output_valid	: out 	STD_LOGIC;
		output_ready	: in 	STD_LOGIC;
		output_data_0	: out std_logic_vector(DATA_WIDTH_0 - 1 downto 0);
		output_data_1	: out std_logic_vector(DATA_WIDTH_1 - 1 downto 0)
	);
end AXIS_SYNCHRONIZER_LATCHED_2;

architecture Behavioral of AXIS_SYNCHRONIZER_LATCHED_2 is
	signal buf_i_0_full, buf_i_1_full, buf_o_0_full, buf_o_1_full: std_logic;
	signal buf_i_0, buf_o_0: std_logic_vector(DATA_WIDTH_0 - 1 downto 0); 
	signal buf_i_1, buf_o_1: std_logic_vector(DATA_WIDTH_1 - 1 downto 0);
	
	signal input_0_ready_in, input_1_ready_in: std_logic;
	signal output_valid_in: std_logic;
begin

	input_0_ready_in <= '1' when buf_i_0_full = '0' or buf_o_0_full = '0' else '0';
	input_1_ready_in <= '1' when buf_i_1_full = '0' or buf_o_1_full = '0' else '0';
	input_0_ready <= input_0_ready_in;
	input_1_ready <= input_1_ready_in;
	
	output_valid_in <= '1' when buf_o_0_full = '1' and buf_o_1_full = '1' else '0';
	output_valid <= output_valid_in;
	
	output_data_0 <= buf_o_0;
	output_data_1 <= buf_o_1;
	
	seq: process(clk) 
	begin
		if rising_edge(clk) then
			if rst = '1' then
				buf_i_0_full <= '0';
				buf_i_1_full <= '0';
				buf_o_0_full <= '0';
				buf_o_1_full <= '0';
				buf_i_0 <= (others => '0');
				buf_i_1 <= (others => '0');
				buf_o_0 <= (others => '0');
				buf_o_1 <= (others => '0');
			else
				--if reading from output
				if output_valid_in = '1' and output_ready = '1' then
					--shift first input
					if input_0_ready_in = '1' and input_0_valid = '1' then
						buf_o_0 <= input_0_data;
						buf_o_0_full <= '1';
					else --shift first value
						buf_o_0 <= buf_i_0;
						buf_o_0_full <= buf_i_0_full;
						--buf_i_0 <= (others => '0');
						buf_i_0_full <= '0';
					end if;
					--shift second input
					if input_1_ready_in = '1' and input_1_valid = '1' then
						buf_o_1 <= input_1_data;
						buf_o_1_full <= '1';
					else --shift first value
						buf_o_1 <= buf_i_1;
						buf_o_1_full <= buf_i_1_full;
						--buf_i_1 <= (others => '0');
						buf_i_1_full <= '0';
					end if;
				else --not reading from output
					if input_0_ready_in = '1' and input_0_valid = '1' then
						--writing to output buffer
						if buf_o_0_full = '0' then
							buf_o_0_full <= '1';
							buf_o_0 <= input_0_data;
						else --writing to first buffer
							buf_i_0_full <= '1';
							buf_i_0 <= input_0_data;
						end if;
					end if;
					if input_1_ready_in = '1' and input_1_valid = '1' then
						--writing to output buffer
						if buf_o_1_full = '0' then
							buf_o_1_full <= '1';
							buf_o_1 <= input_1_data;
						else --writing to first buffer
							buf_i_1_full <= '1';
							buf_i_1 <= input_1_data;
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;
	
end Behavioral;
