----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.02.2019 16:19:13
-- Design Name: 
-- Module Name: alpha_calc - Behavioral
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

entity ALPHA_CALC is
	Generic (
		constant DATA_WIDTH: positive := 16;
		constant BLOCK_SIZE_LOG : positive := 8;
		constant ALPHA_WIDTH: positive := 10
	);
	Port (
		x_empty			: in  std_logic;
		x_readen		: out std_logic;
		x_data			: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		xhat_empty		: in  std_logic;
		xhat_readen		: out std_logic;
		xhat_data		: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		xmean_empty		: in  std_logic;
		xmean_readen	: out std_logic;
		xmean_data		: in  std_logic_vector(DATA_WIDTH + BLOCK_SIZE_LOG - 1 downto 0);
		xhatmean_empty	: in  std_logic;
		xhatmean_readen	: out std_logic;
		xhatmean_data	: in  std_logic_vector(DATA_WIDTH + BLOCK_SIZE_LOG - 1 downto 0);
		alpha_full      : in  std_logic;
		alpha_wren		: out std_logic;
		alpha_data		: out std_logic_vector(ALPHA_WIDTH - 1 downto 0)
	);
end ALPHA_CALC;

architecture Behavioral of ALPHA_CALC is
	
	

begin

	--FSM
	--read both xmean and xhatmean and save them
	--read both x and xhat
	--center on mean and send to multiplier if available, can read the next data right away
		--need a counter for the amount of data to send to multiplier
		
	--at the end of the multiplier
		--add result to accumulators
		--when signaled the end of multiplications, send results to calculate alpha. This can trigger a new alpha calculation
		--find the alpha value and send it to the alpha fifo


end Behavioral;
