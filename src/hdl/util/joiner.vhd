----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.02.2019 12:54:01
-- Design Name: 
-- Module Name: joiner - Behavioral
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


--reads PORT_A_COUNT samples from FIFO port A and then reads from port B until
--a rst is issued
entity JOINER is
	Generic (
		constant DATA_WIDTH: positive := 32;
		constant PORT_A_COUNT: positive := 256
	);
	Port ( 
		clk		: in  STD_LOGIC;
		rst		: in  STD_LOGIC;
		--two fifo ports for input
		fifo_in_a_readen: out STD_LOGIC;
		fifo_in_a_data	: in STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		fifo_in_a_empty : in STD_LOGIC;
		fifo_in_b_readen: out STD_LOGIC;
		fifo_in_b_data	: in STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		fifo_in_b_empty : in STD_LOGIC;
		--one fifo port for output
		fifo_readen		: in  STD_LOGIC;
		fifo_data		: out STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		fifo_empty		: out STD_LOGIC
	);


end JOINER;

architecture Behavioral of JOINER is
	type joiner_state_t is (READING_PORT_A, TRANSITION, READING_PORT_B);
	signal state_curr, state_next: joiner_state_t;
	
	signal counter, counter_next: natural range 0 to PORT_A_COUNT;

begin

	--sequential process
	update: process(clk, rst, state_next, counter_next)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= READING_PORT_A;
				counter <= 0;
				
			else
				state_curr <= state_next;
				counter <= counter_next;			
			end if;
		end if;
	end process;
	
	
	comb: process(state_curr, fifo_readen, fifo_in_a_data, fifo_in_a_empty, fifo_in_b_data, fifo_in_b_empty, counter)
	begin
		--default values
		state_next <= state_curr;
		fifo_in_a_readen <= '0';
		fifo_in_b_readen <= '0';
		fifo_data <= (others => '0');
		fifo_empty <= '0';
		counter_next <= counter;
		--pipe all data from port A
		if state_curr = READING_PORT_A then
			fifo_in_a_readen <= fifo_readen;
			fifo_data <= fifo_in_a_data;
			fifo_empty <= fifo_in_a_empty;
			if fifo_readen = '1' then
				counter_next <= counter + 1;
				if counter = PORT_A_COUNT - 1 then
					state_next <= TRANSITION;
				end if;
			end if;
		--data is on port A, signals are from/to port B
		elsif state_curr = TRANSITION then	
			fifo_in_b_readen <= fifo_readen;
			fifo_data <= fifo_in_a_data;
			fifo_empty <= fifo_in_b_empty;
			if fifo_readen = '1' then
				state_next <= READING_PORT_B;
			end if;
		--everything coming from/going to port b
		elsif state_curr = READING_PORT_B then
			fifo_in_b_readen <= fifo_readen;
			fifo_data <= fifo_in_b_data;
			fifo_empty <= fifo_in_b_empty;
		end if;
	end process;


end Behavioral;
