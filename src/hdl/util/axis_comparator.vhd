----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel B�scones
-- 
-- Create Date: 11.02.2019 16:28:19
-- Design Name: 
-- Module Name: AXIS_COMPARATOR - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Module that takes two different axi_stream streams and compares the
-- 		given values outputting a flag which meaning depends on module configuration.
--		Set the IS_SIGNED, IS_EQUAL and IS_GREATER generics. Flag will be one if the 
--		condition input_0 OP input_1 is true. 
--		E.g if IS_SIGNED and not IS_EQUAL and not IS_GREATER then
--			output <= 1 when input_0 < input_1 else 0
-- 
-- Dependencies: 
--		AXIS_SYNCHRONIZER_2: to merge both AXIS streams
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity AXIS_COMPARATOR is
	--for lower than just invert the inputs
	Generic (
		DATA_WIDTH: integer := 32;
		IS_SIGNED: 	boolean := true;
		IS_EQUAL: 	boolean := true;
		IS_GREATER: boolean := true
	);
	Port(
		clk, rst: in std_logic;
		input_0_data : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_0_valid: in  std_logic;
		input_0_ready: out std_logic;
		input_1_data : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_1_valid: in  std_logic;
		input_1_ready: out std_logic;
		output_data	 : out std_logic;
		output_valid : out std_logic;
		output_ready : in  std_logic
	);
end AXIS_COMPARATOR;

architecture Behavioral of AXIS_COMPARATOR is
	--synchronizer signals
	signal input_sync_valid, input_sync_ready: std_logic;
	signal input_sync_data_0, input_sync_data_1: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--local signals
	signal output_reg: std_logic;
	signal output_valid_reg: std_logic;
	
	signal op_enable: std_logic;
	
	signal result: std_logic;
begin

	input_synchronizer: entity work.AXIS_SYNCHRONIZER_2
		Generic map (
			DATA_WIDTH_0 => DATA_WIDTH,
			DATA_WIDTH_1 => DATA_WIDTH
		)
		Port map (
			clk => clk, rst => rst,
			--to input axi port
			input_0_valid => input_0_valid,
			input_0_ready => input_0_ready,
			input_0_data  => input_0_data,
			input_1_valid => input_1_valid,
			input_1_ready => input_1_ready,
			input_1_data  => input_1_data,
			--to output axi ports
			output_valid  => input_sync_valid,
			output_ready  => input_sync_ready,
			output_data_0 => input_sync_data_0,
			output_data_1 => input_sync_data_1
		);

	op_enable <= '1' when output_valid_reg = '0' or output_ready = '1' else '0';

	gen_equal: if IS_EQUAL and not IS_GREATER generate
		result <= '1' when input_sync_data_0 = input_sync_data_1 else '0';
	end generate;
	gen_not_equal: if not IS_EQUAL and not IS_GREATER generate
		result <= '1' when input_sync_data_0 /= input_sync_data_1 else '0';
	end generate;
	gen_signed_geq: if IS_SIGNED and IS_EQUAL and IS_GREATER generate
		result <= '1' when signed(input_sync_data_0) >= signed(input_sync_data_1) else '0';
	end generate;
	gen_signed_gt: if IS_SIGNED and not IS_EQUAL and IS_GREATER generate
		result <= '1' when signed(input_sync_data_0) > signed(input_sync_data_1) else '0';
	end generate;  
	gen_unsigned_geq: if not IS_SIGNED and IS_EQUAL and IS_GREATER generate
		result <= '1' when unsigned(input_sync_data_0) >= unsigned(input_sync_data_1) else '0';
	end generate;
	gen_unsigned_gt: if not IS_SIGNED and not IS_EQUAL and IS_GREATER generate
		result <= '1' when unsigned(input_sync_data_0) > unsigned(input_sync_data_1) else '0';
	end generate;  
	
	seq_update: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				output_valid_reg <= '0';
				output_reg <= '0';
			elsif op_enable = '1' then
				output_reg <= result;
				output_valid_reg <= input_sync_valid;
			end if;
		end if;
	end process;
				 
	output_valid		<= output_valid_reg;
	input_sync_ready	<= op_enable;
	output_data			<= output_reg;
	

end Behavioral;