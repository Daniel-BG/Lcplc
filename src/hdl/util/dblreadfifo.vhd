----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.02.2019 11:29:06
-- Design Name: 
-- Module Name: dblreadfifo - Behavioral
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

entity DBLREADFIFO is
	Generic (
		constant DATA_WIDTH: positive := 32;
		constant FIFO_DEPTH: positive := 256
	);
	Port (
		--control signals 
		clk		: in  STD_LOGIC;
		rst		: in  STD_LOGIC;
		--input port signals
		write_en	: in  STD_LOGIC;
		write_data	: in  STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		write_full	: out STD_LOGIC;
		--output port #1 signals
		read_a_en	: in  STD_LOGIC;
		read_a_data	: out STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		read_a_empty: out STD_LOGIC;
		--output port #2 signals
		read_b_en	: in  STD_LOGIC;
		read_b_data : out STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		read_b_empty: out STD_LOGIC
	);
end DBLREADFIFO;

architecture Behavioral of DBLREADFIFO is
	signal fifo_a_full, fifo_b_full: std_logic;

begin

	write_full <= fifo_a_full or fifo_b_full;

	FIFO_A: entity work.FIFO 
		generic map(DATA_WIDTH => DATA_WIDTH, FIFO_DEPTH => FIFO_DEPTH)
		port map(clk => clk, rst => rst, 
				wren => write_en, datain => write_data, 
				readen => read_a_en, dataout => read_a_data, 
				empty => read_a_empty, full => fifo_a_full);


	FIFO_B: entity work.FIFO 
		generic map(DATA_WIDTH => DATA_WIDTH, FIFO_DEPTH => FIFO_DEPTH)
		port map(clk => clk, rst => rst, 
				wren => write_en, datain => write_data, 
				readen => read_b_en, dataout => read_b_data, 
				empty => read_b_empty, full => fifo_b_full);


end Behavioral;
