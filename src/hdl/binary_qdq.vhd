----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12.02.2019 09:18:01
-- Design Name: 
-- Module Name: binary_qdq - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
--	quantizes then dequantizes the input
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

entity BINARY_QDQ is
	Generic (
		--0 leaves it the same
		SHIFT_WIDTH	: integer := 4;
		DATA_WIDTH	: integer := 16;
		USER_WIDTH	: integer := 1
	);
	Port (
		clk, rst: std_logic;
		input_ready	: out std_logic;
		input_valid	: in  std_logic;
		input_data	: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_last	: in  std_logic := '0';
		input_user  : in  std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		output_ready: in  std_logic;
		output_valid: out std_logic;
		output_data	: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_last : out std_logic;
		output_user : out std_logic_vector(USER_WIDTH - 1 downto 0);
		--configuration ports
		input_shift	: in  std_logic_vector(SHIFT_WIDTH - 1 downto 0)
	);
end BINARY_QDQ;

architecture Behavioral of BINARY_QDQ is

	signal imm_ready:	std_logic;
	signal imm_valid:	std_logic;
	signal imm_data:	std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal imm_last:	std_logic;
	signal imm_user:	std_logic_vector(USER_WIDTH - 1 downto 0);

begin

	quant: entity work.BINARY_QUANTIZER
		generic map (
			SHIFT_WIDTH => SHIFT_WIDTH,
			DATA_WIDTH => DATA_WIDTH,
			USER_WIDTH => USER_WIDTH
		)
		port map (
			clk => clk, rst => rst,
			input_ready	=> input_ready,
			input_valid	=> input_valid,
			input_data	=> input_data,
			input_last	=> input_last,
			input_user	=> input_user,
			output_ready=> imm_ready,
			output_valid=> imm_valid,
			output_data	=> imm_data,
			output_last	=> imm_last,
			output_user	=> imm_user,
			input_shift	=> input_shift
		);

	dequant: entity work.BINARY_DEQUANTIZER
		generic map (
			SHIFT_WIDTH => SHIFT_WIDTH,
			DATA_WIDTH => DATA_WIDTH,
			USER_WIDTH => USER_WIDTH
		)
		port map (
			clk => clk, rst => rst,
			input_ready	=> imm_ready,
			input_valid	=> imm_valid,
			input_data	=> imm_data,
			input_last	=> imm_last,
			input_user	=> imm_user,
			output_ready=> output_ready,
			output_valid=> output_valid,
			output_data	=> output_data,
			output_last	=> output_last,
			output_user	=> output_user,
			input_shift	=> input_shift
		);

end Behavioral;
