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

entity FIFO_AXI is
	Generic (
		constant DATA_WIDTH: positive := 32;
		constant FIFO_DEPTH: positive := 256
	);
	Port ( 
		clk		: in  STD_LOGIC;
		rst		: in  STD_LOGIC;
		--input axi port
		in_valid: in  STD_LOGIC;
		in_ready: out STD_LOGIC;
		in_data	: in  STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		--out axi port
		out_ready: in  STD_LOGIC;
		out_data : out STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		out_valid: out STD_LOGIC
		
	);
end FIFO_AXI;

architecture Behavioral of FIFO_AXI is
	type memory_t is array(0 to FIFO_DEPTH - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal memory: memory_t;
	
	
	signal head, tail, tail_next: natural range 0 to FIFO_DEPTH - 1;
	signal occupancy: natural range 0 to FIFO_DEPTH;
	
	signal in_empty, in_full: std_logic;
	signal next_in_empty, next_in_full: std_logic;
	
	signal dataout_mem, dataout_last: std_logic_vector (DATA_WIDTH - 1 downto 0);
	signal last_read_fromin: std_logic;
begin

	out_valid <= not in_empty;
	in_ready  <= not in_full;

	next_in_empty <= '1' when 
					(occupancy = 0 and in_valid = '0') or 
					(occupancy = 1 and in_valid = '0' and out_ready = '1') 
					else '0';					
	next_in_full <= '1' when 
					(occupancy = FIFO_DEPTH and (out_ready = '0' or (out_ready = '1' and in_valid = '1'))) or
					(occupancy = FIFO_DEPTH - 1 and in_valid = '1' and out_ready = '0')
					else '0';
					
	tail_next <= 0 when tail = FIFO_DEPTH - 1 else tail + 1;
					
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


	main_proc: process(clk, rst, in_valid, out_ready, in_empty, tail, head, in_full)
	begin
		if (rising_edge(clk)) then
			if rst = '1' then
				head <= 0;
				tail <= 0;
				occupancy <= 0;
			else			
				if (in_valid = '1' and out_ready = '1' and in_empty = '0') then
					tail <= tail_next;
					if occupancy = 1 then
						last_read_fromin <= '1';
						dataout_last <= in_data;
					else
						last_read_fromin <= '0';
						dataout_mem <= memory(tail_next);
					end if;
					
					memory(head) <= in_data;
					if (head = FIFO_DEPTH - 1) then
						head <= 0;
					else
						head <= head + 1;
					end if;
				elsif (in_valid = '1' and not in_full = '1') then 
					occupancy <= occupancy + 1;
					memory(head) <= in_data;
					if (head = FIFO_DEPTH - 1) then
						head <= 0;
					else
						head <= head + 1;
					end if;
					dataout_last <= in_data;
					last_read_fromin <= '1';
				elsif (out_ready = '1' and not in_empty = '1') then 
					occupancy <= occupancy - 1;
					tail <= tail_next;
					dataout_mem <= memory(tail_next);
					last_read_fromin <= '0';
				end if;
			end if;
		end if;
	end process;
	
	out_data <= dataout_mem when last_read_fromin = '0' else dataout_last;


end Behavioral;
