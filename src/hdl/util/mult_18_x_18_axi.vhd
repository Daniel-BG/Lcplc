----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08.02.2019 10:28:15
-- Design Name: 
-- Module Name: queued_multiplier - Behavioral
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

entity MULT_18_X_18_AXI is
	Port(
		clk, rst: in std_logic;
		input_a, input_b: in std_logic_vector(17 downto 0);
		input_valid: in std_logic;
		input_ready: out std_logic;
		output: out std_logic_vector(35 downto 0);
		output_valid: out std_logic;
		output_ready: in std_logic
	);
end MULT_18_X_18_AXI;

architecture Behavioral of MULT_18_X_18_AXI is
	--multiplier declaration
	constant MULT_STAGES: integer := 3;
	COMPONENT mult_18_x_18
		PORT (
			CLK : IN STD_LOGIC;
			A : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
			B : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
			CE : IN STD_LOGIC;
			SCLR : IN STD_LOGIC;
			P : OUT STD_LOGIC_VECTOR(35 DOWNTO 0)
		);
	END COMPONENT;

	signal mult_enable: std_logic;
	
	signal mult_stage_occupancy: std_logic_vector(MULT_STAGES - 1 downto 0);
	
begin

	mult_enable <= '1' when mult_stage_occupancy(MULT_STAGES - 1) = '0' or output_ready = '1' else '0';
	
	seq_update: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				mult_stage_occupancy <= (others => '0');
			elsif mult_enable = '1' then
				mult_stage_occupancy <= mult_stage_occupancy(MULT_STAGES - 2 downto 0) & input_valid;
			end if;
		end if;
	end process;

	mult: mult_18_x_18
		port map(CLK => CLK, 
				 A => input_a, 
				 B => input_b, 
				 CE => mult_enable, 
				 SCLR => rst, 
				 P => output);
				 
	output_valid <= mult_stage_occupancy(MULT_STAGES - 1);
	input_ready  <= mult_enable;

end Behavioral;
