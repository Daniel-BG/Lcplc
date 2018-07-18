----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:46:49 07/18/2018 
-- Design Name: 
-- Module Name:    FIFO - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
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
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity FIFO is
	Generic (
		constant DATA_WIDTH: positive := 64;
		constant FIFO_DEPTH: positive := 32
	);
	Port ( 
		clk		: in  STD_LOGIC;
		rst		: in  STD_LOGIC;
		wren		: in  STD_LOGIC;
		datain	: in  STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		readen	: in  STD_LOGIC;
		dataout	: out STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		empty		: out STD_LOGIC;
		full		: out STD_LOGIC
	);
end FIFO;

architecture Behavioral of FIFO is
	type memory_t is array(0 to FIFO_DEPTH - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal memory: memory_t;
	
	
	signal head, tail: natural range 0 to FIFO_DEPTH - 1;
	signal occupancy: natural range 0 to FIFO_DEPTH;
	
	signal in_empty, in_full: std_logic;
	signal next_in_empty, next_in_full: std_logic;
begin

	empty <= in_empty;
	full <= in_full;

	next_in_empty <= '1' when 
					(occupancy = 0 and wren = '0') or 
					(occupancy = 1 and wren = '0' and readen = '1') 
					else '0';					
	next_in_full <= '1' when 
					(occupancy = FIFO_DEPTH and (readen = '0' or (readen = '1' and wren = '1'))) or
					(occupancy = FIFO_DEPTH - 1 and wren = '1' and readen = '0')
					else '0';
					
	update_flags: process(clk, rst)
	begin
		if (rising_edge(clk)) then
			if rst = '1' then
				in_empty <= '1';
				in_full <= '0';
			else
				in_empty <= next_in_empty;
				in_full <= next_in_full;
			end if;
		end if;
	end process;


	main_proc: process(clk, rst, wren, readen, in_empty, tail, head, in_full)
	begin
		if (rising_edge(clk)) then
			if rst = '1' then
				head <= 0;
				tail <= 0;
				occupancy <= 0;
			else			
				if (wren = '1' and readen = '1' and not in_empty = '1') then
					dataout <= memory(tail);
					if (tail = FIFO_DEPTH - 1) then
						tail <= 0;
					else
						tail <= tail + 1;
					end if;
					memory(head) <= datain;
					if (head = FIFO_DEPTH - 1) then
						head <= 0;
					else
						head <= head + 1;
					end if;
				elsif (wren = '1' and not in_full = '1') then 
					occupancy <= occupancy + 1;
					memory(head) <= datain;
					if (head = FIFO_DEPTH - 1) then
						head <= 0;
					else
						head <= head + 1;
					end if;
				elsif (readen = '1' and not in_empty = '1') then 
					occupancy <= occupancy - 1;
					dataout <= memory(tail);
					if (tail = FIFO_DEPTH - 1) then
						tail <= 0;
					else
						tail <= tail + 1;
					end if;
				end if;
			end if;
		end if;
	end process;


end Behavioral;



