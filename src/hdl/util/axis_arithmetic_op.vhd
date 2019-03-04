----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.02.2019 16:59:23
-- Design Name: 
-- Module Name: AXIS_ARITHMETIC_OP - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Perform unsigned or signed addition or substraction of the given
--		inputs. Input and output sizes are configurable. Operations are done
--		in the output size, so that that into account for overflows and the like.
--		If OUTPUT_DATA_WIDTH is set to 1 or more than the max of the input data widths,
--		overflow will not occur.
-- 
-- Dependencies: AXIS_SYNCHRONIZER_2 to sync the inputs
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity AXIS_ARITHMETIC_OP is
	Generic (
		DATA_WIDTH_0: integer := 32;
		DATA_WIDTH_1: integer := 32;
		OUTPUT_DATA_WIDTH: integer := 32;
		IS_ADD: boolean := true;
		SIGN_EXTEND_0	: boolean := true;
		SIGN_EXTEND_1	: boolean := true;
		SIGNED_OP		: boolean := true;
		LATCH_INPUT_SYNC: boolean := true
	);
	Port(
		clk, rst: in std_logic;
		input_0_data	: in  std_logic_vector(DATA_WIDTH_0 - 1 downto 0);
		input_0_valid	: in  std_logic;
		input_0_ready	: out std_logic;
		input_1_data	: in  std_logic_vector(DATA_WIDTH_1 - 1 downto 0);
		input_1_valid	: in  std_logic;
		input_1_ready	: out std_logic;
		output_data		: out std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);
		output_valid	: out std_logic;
		output_ready	: in  std_logic
	);
end AXIS_ARITHMETIC_OP;

architecture Behavioral of AXIS_ARITHMETIC_OP is
	--joiner
	signal joint_valid, joint_ready: std_logic;
	signal joint_data_0: std_logic_vector(DATA_WIDTH_0 - 1 downto 0);
	signal joint_data_1: std_logic_vector(DATA_WIDTH_1 - 1 downto 0);
	signal joint_data_0_ex, joint_data_1_ex: std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);
	
	--operation signals
	signal output_reg: std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);
	signal output_valid_reg: std_logic;
	
	signal op_enable: std_logic;
	
	signal result: std_logic_vector(OUTPUT_DATA_WIDTH - 1 downto 0);
begin

	data_joiner: entity work.AXIS_SYNCHRONIZER_2
		generic map (
			DATA_WIDTH_0 => DATA_WIDTH_0,
			DATA_WIDTH_1 => DATA_WIDTH_1,
			LATCH 		 => LATCH_INPUT_SYNC
		)
		port map (
			clk => clk, rst => rst,
			input_0_valid => input_0_valid,
			input_0_ready => input_0_ready,
			input_0_data  => input_0_data,
			input_1_valid => input_1_valid,
			input_1_ready => input_1_ready,
			input_1_data  => input_1_data,
			output_valid  => joint_valid,
			output_ready  => joint_ready,
			output_data_0 => joint_data_0,
			output_data_1 => joint_data_1
		);

	op_enable <= '1' when output_valid_reg = '0' or output_ready = '1' else '0';
	
	input_0_zero_extend: if not SIGN_EXTEND_0 generate
		joint_data_0_ex <= std_logic_vector(resize(unsigned(joint_data_0), OUTPUT_DATA_WIDTH));
	end generate;
	input_0_sign_extend: if SIGN_EXTEND_0 generate
		joint_data_0_ex <= std_logic_vector(resize(signed(joint_data_0), OUTPUT_DATA_WIDTH));
	end generate;
	input_1_zero_extend: if not SIGN_EXTEND_1 generate
		joint_data_1_ex <= std_logic_vector(resize(unsigned(joint_data_1), OUTPUT_DATA_WIDTH));
	end generate;
	input_1_sign_extend: if SIGN_EXTEND_1 generate
		joint_data_1_ex <= std_logic_vector(resize(signed(joint_data_1), OUTPUT_DATA_WIDTH));
	end generate;

	gen_res_add_signed: if IS_ADD and SIGNED_OP generate
		result <= std_logic_vector(signed(joint_data_0_ex) + signed(joint_data_1_ex));
	end generate;
	gen_res_add_unsigned: if IS_ADD and not SIGNED_OP generate
		result <= std_logic_vector(unsigned(joint_data_0_ex) + unsigned(joint_data_1_ex));
	end generate;
	gen_res_sub_signed: if not IS_ADD and SIGNED_OP generate
		result <= std_logic_vector(signed(joint_data_0_ex) - signed(joint_data_1_ex));
	end generate;
	gen_res_sub_unsigned: if not IS_ADD and not SIGNED_OP generate
		result <= std_logic_vector(unsigned(joint_data_0_ex) - unsigned(joint_data_1_ex));
	end generate;
	
	seq_update: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				output_valid_reg <= '0';
				output_reg <= (others => '0');
			elsif op_enable = '1' then
				output_reg <= result;
				output_valid_reg <= joint_valid;
			end if;
		end if;
	end process;
				 
	output_valid <= output_valid_reg;
	joint_ready  <= op_enable;
	output_data	 <= output_reg;
	
	
end Behavioral;
