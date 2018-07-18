----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:57:45 07/18/2018 
-- Design Name: 
-- Module Name:    FIFO_FORWARD - Behavioral 
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
entity FIFO_FORWARD is
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
end FIFO_FORWARD;

architecture Behavioral of FIFO_FORWARD is
	type memory_t is array(0 to FIFO_DEPTH - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal memory: memory_t;
	
	
	signal head, tail: natural range 0 to FIFO_DEPTH - 1;
	signal occupancy: natural range 0 to FIFO_DEPTH;
	
	signal in_empty, in_full: std_logic;
begin

	--direct mappings
	empty <= in_empty;
	full <= in_full;

	--flags
	in_empty <= '0' when occupancy /= 0 --is not empty because of buffers
							or wren = '1' 		--is not empty because of new data that can pass through
					else '0'; 					--it is indeed empty
					
	in_full <= '1' when occupancy = FIFO_DEPTH else '0';
	
	


	main_proc: process(clk, rst, wren, readen, in_empty, tail, head, in_full, occupancy)
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
					
					if occupancy = 0 then
						--pass_through case, reading with nothing in memory
						--so read from input which is valid since
						--in_empty = '0' and occupancy = 0
						dataout <= datain;
					else
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
		end if;
	end process;


end Behavioral;

