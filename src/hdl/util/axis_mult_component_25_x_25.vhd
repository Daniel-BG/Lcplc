----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08.02.2019 10:28:15
-- Design Name: 
-- Module Name: AXIS_MULT_COMPONENT_25x25 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Wrapper around the 25x25 mult IP core to be used with AXIS interfaces
-- 
-- Dependencies: 25x25 MULT ip core
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

entity AXIS_MULT_COMPONENT_25x25 is
	Port(
		clk, rst: in std_logic;
		input_a, input_b: in std_logic_vector(24 downto 0);
		input_valid: in std_logic;
		input_ready: out std_logic;
		input_last: in std_logic;
		output: out std_logic_vector(49 downto 0);
		output_valid: out std_logic;
		output_ready: in std_logic;
		output_last: out std_logic
	);
end AXIS_MULT_COMPONENT_25x25;

architecture Behavioral of AXIS_MULT_COMPONENT_25x25 is
	--multiplier declaration
	constant MULT_STAGES: integer := 4;
	COMPONENT mult_25_x_25
		PORT (
			CLK : IN STD_LOGIC;
			A : IN STD_LOGIC_VECTOR(24 DOWNTO 0);
			B : IN STD_LOGIC_VECTOR(24 DOWNTO 0);
			CE : IN STD_LOGIC;
			SCLR : IN STD_LOGIC;
			P : OUT STD_LOGIC_VECTOR(49 DOWNTO 0)
		);
	END COMPONENT;

	signal mult_enable: std_logic;
	
	signal mult_stage_occupancy: std_logic_vector(MULT_STAGES - 1 downto 0);
	signal mult_stage_last: std_logic_vector(MULT_STAGES - 1 downto 0);
	
begin

	mult_enable <= '1' when mult_stage_occupancy(MULT_STAGES - 1) = '0' or output_ready = '1' else '0';
	
	seq_update: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				mult_stage_occupancy <= (others => '0');
				mult_stage_last <= (others => '0');
			elsif mult_enable = '1' then
				mult_stage_occupancy <= mult_stage_occupancy(MULT_STAGES - 2 downto 0) & input_valid;
				mult_stage_last      <= mult_stage_last     (MULT_STAGES - 2 downto 0) & input_last;
			end if;
		end if;
	end process;

	mult: mult_25_x_25
		port map(CLK => CLK, 
				 A => input_a, 
				 B => input_b, 
				 CE => mult_enable, 
				 SCLR => rst, 
				 P => output);

				 
	output_valid <= mult_stage_occupancy(MULT_STAGES - 1);
	output_last  <= mult_stage_last(MULT_STAGES - 1);
	input_ready  <= mult_enable;

end Behavioral;
