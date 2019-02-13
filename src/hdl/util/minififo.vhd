----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11.02.2019 15:57:30
-- Design Name: 
-- Module Name: minififo - Behavioral
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

entity MINIFIFO is
	Generic (
		DATA_WIDTH: integer := 32
	);
	Port (
		clk, rst: in std_logic;
		in_ready: out std_logic;
		in_valid: in  std_logic;
		in_data : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		out_ready: in  std_logic;
		out_valid: out std_logic;
		out_data : out std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end MINIFIFO;

architecture Behavioral of minififo is
	--buffers
	signal buf0, buf1: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	--buffer flags
	signal buf0_full, buf1_full: std_logic;
	
	--inner signals
	signal inner_in_ready, inner_out_valid: std_logic;
begin

	out_data <= buf1;

	inner_in_ready	<= not buf0_full;
	inner_out_valid	<=     buf1_full;
	in_ready	<= inner_in_ready;
	out_valid	<= inner_out_valid;

	seq: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				buf0_full <= '0';
				buf1_full <= '0';
				buf0 	  <= (others => '0');
				buf1 	  <= (others => '0');
			else
				if inner_in_ready = '1' and in_valid = '1' and inner_out_valid = '1' and out_ready = '1' then
					--writing and reading (can only happen if one buffer is '1' and the other is '0')
					buf1 <= in_data;
					--buf1_full keeps its value of 1
				elsif inner_in_ready = '1' and in_valid = '1' then
					--writing (can happen with one or both buffers free)
					--write to buf1 unless full
					if buf1_full = '0' then
						buf1 <= in_data;
						buf1_full <= '1';
					else
						buf0 <= in_data;
						buf0_full <= '1';
					end if;
				elsif inner_out_valid = '1' and out_ready = '1' then
					--reading (can happen with one or both buffers full)
					buf1 <= buf0;
					buf1_full <= buf0_full;
					buf0_full <= '0';
				end if;
			end if;
		end if;
	end process;
	


end Behavioral;
