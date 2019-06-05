----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12.02.2019 09:19:13
-- Design Name: 
-- Module Name: binary_dequantizer - Behavioral
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
use work.constants.all;

entity BINARY_DEQUANTIZER is
	Generic (
		--0 leaves it the same
		SHIFT_WIDTH : integer := 4;
		DATA_WIDTH	: integer := 16;
		USER_WIDTH	: integer := 1
	);
	Port (
		clk, rst: std_logic;
		input_ready	: out std_logic;
		input_valid	: in  std_logic;
		input_data	: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_last  : in  std_logic := '0';
		input_user	: in  std_logic_vector(USER_WIDTH - 1 downto 0) := (others => '0');
		output_ready: in  std_logic;
		output_valid: out std_logic;
		output_data	: out std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_last : out std_logic;
		output_user : out std_logic_vector(USER_WIDTH - 1 downto 0);
		--configuration ports
		input_shift	: in  std_logic_vector(SHIFT_WIDTH - 1 downto 0)
	);
end BINARY_DEQUANTIZER;

architecture Behavioral of BINARY_DEQUANTIZER is

--	signal input_sign_extended: std_logic_vector(DATA_WIDTH downto 0);
--	signal abs_val: std_logic_vector(DATA_WIDTH downto 0);
--	
--	signal shifted_up: std_logic_vector(DATA_WIDTH downto 0);
--
--	signal pre_out: std_logic_vector(DATA_WIDTH downto 0);
--	attribute KEEP of pre_out: signal is KEEP_DEFAULT;
--	
--	
--	--latching/registers
--	constant STAGES: integer := 2;
--	signal valid_stages: std_logic_vector(STAGES - 1 downto 0);
--	signal device_enable: std_logic;
--	
--	signal input_sign: std_logic;
--
--	signal stage_1_reg: std_logic_vector(DATA_WIDTH downto 0);
--	signal stage_2_reg: std_logic_vector(DATA_WIDTH - 1 downto 0);
--	signal stage_1_last, stage_2_last: std_logic;
--	signal stage_1_user, stage_2_user: std_logic_vector(USER_WIDTH - 1 downto 0);
	
begin

	output_data <= std_logic_vector(shift_left(signed(input_data), to_integer(unsigned(input_shift))));
	output_valid <= input_valid;
	input_ready <= output_ready;
	output_last <= input_last;
	output_user <= input_user;

--	device_enable <= '1' when valid_stages(STAGES - 1) = '0' or output_ready = '1' else '0';
--	input_ready <= device_enable;
--	output_valid <= valid_stages(STAGES - 1);
--
--	output_data <= stage_2_reg;
--	output_last <= stage_2_last;
--	output_user <= stage_2_user;
--	
--	seq: process(clk, rst)
--	begin
--		if rising_edge(clk) then
--			if rst = '1' then
--				valid_stages <= (others => '0');
--			else
--				if device_enable = '1' then
--					input_sign <= input_data(DATA_WIDTH - 1);
--					valid_stages(0) <= input_valid;
--					for i in 0 to STAGES - 2 loop
--						valid_stages(i+1) <= valid_stages(i);
--					end loop;
--					stage_1_reg <= shifted_up;
--					stage_2_reg <= pre_out(DATA_WIDTH - 1 downto 0);
--					stage_1_last<= input_last;
--					stage_2_last<= stage_1_last;
--					stage_1_user<= input_user;
--					stage_2_user<= stage_1_user;
--				end if;	
--			end if;
--		end if;
--	end process;
--
--	--stage 1
--	input_sign_extended <= input_data(DATA_WIDTH - 1) & input_data;
--	abs_val <= input_sign_extended when input_data(DATA_WIDTH - 1) = '0' else std_logic_vector(-signed(input_sign_extended));
--	
--	shifted_up <= std_logic_vector(shift_left(unsigned(abs_val), to_integer(unsigned(input_shift))));
--	
--	--stage 2
--	pre_out <= stage_1_reg when input_sign = '0' else std_logic_vector(-signed(stage_1_reg));

end Behavioral;
