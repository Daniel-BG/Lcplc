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

entity QUEUED_MULTIPLIER is
	Port(
		clk, rst 		: in std_logic;
		input_full		: out std_logic;
		input_data_a	: in std_logic_vector(16 downto 0);
		input_data_b	: in std_logic_vector(16 downto 0);
		input_wren  	: in std_logic;
		output_empty	: out std_logic;
		output_data 	: out std_logic_vector(33 downto 0);
		output_readen	: in std_logic
	);
end QUEUED_MULTIPLIER;

architecture Behavioral of QUEUED_MULTIPLIER is
	--multiplier declaration
	constant MULT_STAGES: integer := 5;
	COMPONENT mult_gen_prealpha
		PORT (
			CLK : IN STD_LOGIC;
			A : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
			B : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
			CE : IN STD_LOGIC;
			SCLR : IN STD_LOGIC;
			P : OUT STD_LOGIC_VECTOR(33 DOWNTO 0)
		);
	END COMPONENT;

	signal mult_enable: std_logic;
	signal mult_out: std_logic_vector(33 downto 0);
	
	signal mult_stage_occupancy: std_logic_vector(MULT_STAGES - 1 downto 0);
	signal next_occupancy: std_logic;
	
	
	signal can_output: std_logic;
	signal can_input : std_logic;
	signal has_data  : std_logic;
	
begin

	mult: mult_gen_prealpha
		port map(CLK => CLK, 
				 A => input_data_a, 
				 B => input_data_b, 
				 CE => mult_enable, 
				 SCLR => rst, 
				 P => mult_out);
				 
	--can output if it has a value in its last place
	can_output <= mult_stage_occupancy(0);
	--can input if it has no value in the last place or,
	--when having it, the output read enable is active (meaning a shift)
	can_input  <= (not mult_stage_occupancy(0)) or output_readen;		
	--has data when any of its stages is full
	has_data   <= '1' when mult_stage_occupancy /= (mult_stage_occupancy'range => '0') else '0'; 
	
	
	output_empty <= not can_output;
	input_full   <= not can_input;
		
		
	mult_enable  <= can_input;
	next_occupancy <= input_wren;
	
				 
	seq_update: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				mult_stage_occupancy <= (others => '0');
				output_data <= (others => '0');
			else
				if mult_enable = '1' then
					mult_stage_occupancy <= next_occupancy & mult_stage_occupancy(MULT_STAGES - 1 downto 1);
				end if;
				if output_readen = '1' then
					output_data <= mult_out;
				end if;
			end if;
		end if;
	end process;

	


end Behavioral;
