----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.02.2019 17:18:08
-- Design Name: 
-- Module Name: multipliertest - Behavioral
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
use ip_cores.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity multipliertest is
  PORT (
	  CLK : IN STD_LOGIC;
	  A : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
	  B : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
	  CE : IN STD_LOGIC;
	  SCLR : IN STD_LOGIC;
	  P : OUT STD_LOGIC_VECTOR(33 DOWNTO 0)
	);
end multipliertest;

architecture Behavioral of multipliertest is

begin

mult: entity ip_cores.mult_gen_17x17
	port map(CLK => CLK, A => A, B => B, CE => CE, SCLR => SCLR, P => P);


end Behavioral;
