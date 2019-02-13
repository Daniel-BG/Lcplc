----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.02.2019 16:32:09
-- Design Name: 
-- Module Name: splitter - Behavioral
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

entity SPLITTER is
	Generic (
		constant DATA_WIDTH: positive := 32
	);
	Port (
		clk, rst: in std_logic;
		--to input fifo where data IS 
		fifo_in_empty	: in	STD_LOGIC;
		fifo_in_data	: in	STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		fifo_in_readen	: out	STD_LOGIC;
		--to input master that assumes it reads from input fifo
		master_empty	: out 	STD_LOGIC;
		master_data		: out 	STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		master_readen	: in 	STD_LOGIC;
		--to output fifo that will end up with a copy of everything going through this link
		fifo_out_full	: in	STD_LOGIC;
		fifo_out_data	: out	STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		fifo_out_wren	: out	STD_LOGIC
	);
end SPLITTER;

architecture Behavioral of splitter is
	type splitter_state_t is (IDLE, READ);
	signal state_curr, state_next: splitter_state_t;
	
begin

	seq: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= IDLE;
			else 
				state_curr <= state_next;
			end if;
		end if;
	end process;

	fifo_out_data <= fifo_in_data;
	master_data   <= fifo_in_data;

	comb: process(state_curr, fifo_out_full, fifo_in_empty, master_readen)
	begin
		master_empty <= '0';
		fifo_in_readen <= master_readen;
		fifo_out_wren <= '0';
		state_next <= state_curr;
		
		if state_curr = IDLE then
			--can annouce read to master
			if fifo_out_full = '0' then
				master_empty <= fifo_in_empty;
			end if;
			if master_readen = '1' then
				state_next <= READ;
			end if;
		elsif state_curr = READ then
			if fifo_out_full = '0' then
				fifo_out_wren <= '1';
				master_empty <= fifo_in_empty;
				if master_readen = '0' then
					state_next <= IDLE;
				end if;
			end if;
		end if;
	end process;

end Behavioral;
