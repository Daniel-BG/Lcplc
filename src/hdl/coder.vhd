----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.02.2019 12:20:04
-- Design Name: 
-- Module Name: coder - Behavioral
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

entity CODER is
	Generic (
		DATA_WIDTH: integer := 16;
		ACC_LOG: integer := 5;
		BLOCK_SIZE_LOG: integer := 8
	);
	Port (
		--inputs
		xhat_data	: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		xhat_ready	: out	std_logic;
		xhat_valid	: in	std_logic;
		ehat_data	: in	std_logic_vector(DATA_WIDTH + 2 downto 0);
		ehat_ready	: out	std_logic;
		ehat_valid	: in 	std_logic;
		kj_data		: in 	std_logic_vector(ACC_LOG - 1 downto 0);
		kj_ready	: out	std_logic;
		kj_valid	: in 	std_logic;
		xtilde_data	: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		xtilde_ready: out	std_logic;
		xtilde_valid: in	std_logic;
		d_data		: in	std_logic_vector((DATA_WIDTH + 3)*2 + BLOCK_SIZE_LOG - 1 downto 0);
		d_ready		: out	std_logic;
		d_valid		: in 	std_logic
		--outputs
		--??????
	);
end CODER;

architecture Behavioral of CODER is

begin


end Behavioral;
