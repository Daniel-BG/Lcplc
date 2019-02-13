----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.02.2019 12:18:55
-- Design Name: 
-- Module Name: averager - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity AVERAGER is
	Generic (
		constant DATA_WIDTH: positive := 32;
		constant AVERAGE_DEPTH_WIDTH: positive := 8
	);
	Port ( 
		clk		: in  STD_LOGIC;
		rst		: in  STD_LOGIC;
		fifo_in_empty	: in	STD_LOGIC;
		fifo_in_data	: in	STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		fifo_in_readen	: out	STD_LOGIC;
		fifo_out_full	: in	STD_LOGIC;
		fifo_out_data	: out	STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		fifo_out_wren	: out	STD_LOGIC
	);
end AVERAGER;

architecture Behavioral of AVERAGER is
	type averager_state_t is (IDLE, AVERAGING, WRITEBACK);
	signal state_curr, state_next: averager_state_t;
	
	signal count, count_next: natural range 0 to 2**AVERAGE_DEPTH_WIDTH;
	
	signal accumulator, accumulator_next: std_logic_vector(DATA_WIDTH + AVERAGE_DEPTH_WIDTH - 1 downto 0);

begin

	update: process(clk, rst)
	begin
		if (rising_edge(clk)) then
			if rst = '1' then
				state_curr <= IDLE;
				count <= 0;
				accumulator <= (others => '0');
			else
				state_curr <= state_next;
				count <= count_next;
				accumulator <= accumulator_next;
			end if;
		end if;
	end process;


	main_proc: process(state_curr, count, accumulator, fifo_in_data, fifo_in_empty, fifo_out_full)
	begin
		--default values for all signals
		state_next <= state_curr;
		fifo_in_readen <= '0';
		count_next <= count;
		accumulator_next <= accumulator;
		fifo_out_wren <= '0';
		fifo_out_data <= (others => '0');
		
		if (state_curr = IDLE) then
			--as soon as we have data, read it and go to AVERAGING
			--state where it will be added together with the previous
			--read data (if any)
			if (fifo_in_empty = '0') then
				state_next <= AVERAGING;
				fifo_in_readen <= '1';
				count_next <= count + 1;
			end if;
		elsif (state_curr = AVERAGING) then
			--accumulate values
			accumulator_next <= std_logic_vector(unsigned(accumulator) + unsigned(fifo_in_data));
			--if all values have been added, write them to output fifo
			if (count = 2**AVERAGE_DEPTH_WIDTH) then
				state_next <= WRITEBACK;
			else
				--if fifo is not empty, continue adding values
				if (fifo_in_empty = '0') then
					fifo_in_readen <= '1';
					count_next <= count + 1;
				--if fifo is empty go to idle and wait
				else
					state_next <= IDLE; 
				end if;
			end if;
		elsif (state_curr = WRITEBACK) then
			--wait for output fifo to be empty
			if (fifo_out_full = '0') then
				--reset and send out value
				accumulator_next <= (others => '0');
				count_next <= 0;
				fifo_out_data <= accumulator(DATA_WIDTH + AVERAGE_DEPTH_WIDTH - 1 downto AVERAGE_DEPTH_WIDTH);
				fifo_out_wren <= '1';
			end if;
		end if;
	end process;


end Behavioral;
