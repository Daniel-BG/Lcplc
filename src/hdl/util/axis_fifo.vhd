----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date:    11:46:49 07/18/2018 
-- Design Name: 
-- Module Name:    AXIS_FIFO - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: A simple FIFO queue with AXIS input and output port. Can configure
--		data width and fifo size
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

entity AXIS_FIFO is
	Generic (
		constant DATA_WIDTH: positive := 32;
		constant FIFO_DEPTH: positive := 256 --greater than 2!! (otherwise use other AXIS LINKS)
	);
	Port ( 
		clk		: in  STD_LOGIC;
		rst		: in  STD_LOGIC;
		--input axi port
		input_valid		: in  STD_LOGIC;
		input_ready		: out STD_LOGIC;
		input_data		: in  STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		--out axi port
		output_ready	: in  STD_LOGIC;
		output_data		: out STD_LOGIC_VECTOR (DATA_WIDTH - 1 downto 0);
		output_valid	: out STD_LOGIC
	);
end AXIS_FIFO;

architecture Behavioral of AXIS_FIFO is
	type memory_t is array(0 to FIFO_DEPTH - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal memory: memory_t;
	signal memory_wren, memory_readen: std_logic;
	signal memory_out: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	type fifo_state_t is (EMPTY, HALF_BUFFERED, HALF_UNBUFFERED, FULL_BUFFERED, FULL_UNBUFFERED);
	signal state_curr, state_next: fifo_state_t;
	
	--head is where we will be writing to
	signal head, head_next, head_incr: natural range 0 to FIFO_DEPTH - 1;
	--tail is where we will be reading from
	signal tail, tail_next, tail_incr: natural range 0 to FIFO_DEPTH - 1;
	signal occupancy, occupancy_next: natural range 0 to FIFO_DEPTH;
	
	signal input_buff, input_buff_next: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	signal almost_full, almost_empty: boolean;
begin

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				head <= 0;
				tail <= 1; --we read ahead of time to be able to use syncrhonous memory
				occupancy <= 0;
				state_curr <= EMPTY;
				input_buff <= (others => '0');
			else
				head <= head_next;
				tail <= tail_next;
				occupancy <= occupancy_next;
				state_curr <= state_next;
				if memory_wren = '1' then
					memory(head) <= input_data;
				end if;
				if memory_readen = '1' then
					memory_out   <= memory(tail);
				end if;
				input_buff <= input_buff_next;
			end if;
		end if;
	end process;
	
	
	head_incr <= 0 when head = FIFO_DEPTH - 1 else head + 1;
	tail_incr <= 0 when tail = FIFO_DEPTH - 1 else tail + 1;
	
	almost_precalc: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				almost_empty <= false;
				almost_full  <= false;
			else
				almost_empty <= occupancy_next = 1;
				almost_full  <= occupancy_next = FIFO_DEPTH - 1;
			end if;
		end if;
	end process;
	
	comb: process(state_curr, head, tail, occupancy,
			input_valid, output_ready,
			head_incr, tail_incr,
			input_data, input_buff, memory_out,
			almost_empty, almost_full)
	begin
		state_next <= state_curr;
		input_ready <= '0';
		output_valid <= '0';
		memory_wren <= '0';
		memory_readen <= '0';
		output_data <= (others => '0');
		
		head_next <= head;
		tail_next <= tail;
		occupancy_next <= occupancy;

		input_buff_next <= input_buff;
	
		if state_curr = EMPTY then
			input_ready <= '1';
			if input_valid = '1' then
				head_next <= head_incr;
				occupancy_next <= occupancy + 1;
				state_next <= HALF_BUFFERED;
				input_buff_next <= input_data;
			end if;
		elsif state_curr = HALF_BUFFERED then
			input_ready <= '1';
			output_valid <= '1';
			output_data <= input_buff;
			if input_valid = '1' and output_ready = '1' then
				--write and read from memory, update pointers
				memory_wren <= '1';
				memory_readen <= '1';
				head_next <= head_incr;
				tail_next <= tail_incr;
				--if occupancy is one we have not read the new value
				--keep BUFFERED until OCC>1

				if almost_empty then
					input_buff_next <= input_data;
				else
					state_next <= HALF_UNBUFFERED;
				end if;
			elsif input_valid = '1' then
				--write value and increment counters
				memory_wren <= '1';
				head_next <= head_incr;
				occupancy_next <= occupancy + 1;
				--if we fill the queue, change state
				if almost_full then
					state_next <= FULL_BUFFERED;
				end if;
			elsif output_ready = '1' then
				--read value and update counters
				memory_readen <= '1';
				tail_next <= tail_incr;
				occupancy_next <= occupancy - 1;
				--we are either going to an empty or unbuffered state
				if almost_empty then
					state_next <= EMPTY;
				else
					state_next <= HALF_UNBUFFERED;
				end if;
			end if;
		elsif state_curr = HALF_UNBUFFERED then
			--have available space and available data (FROM MEMORY READ)
			input_ready <= '1';
			output_valid <= '1';
			output_data <= memory_out;
			--input_buff_next <= input_data; --simplify logic
			if input_valid = '1' and output_ready = '1' then
				--write and read from memory, update counters
				memory_wren <= '1';
				memory_readen <= '1';
				head_next <= head_incr;
				tail_next <= tail_incr;
				--if we are not going to be able to read from mem
				--go to BUFFERED state
				if almost_empty then
					input_buff_next <= input_data;
					state_next <= HALF_BUFFERED;
				end if;
			elsif input_valid = '1' then
				--write to memory, update counters
				memory_wren <= '1';
				head_next <= head_incr;
				occupancy_next <= occupancy + 1;
				--if we fill the memory, go to final state
				if almost_full then
					state_next <= FULL_UNBUFFERED;
				end if;
			elsif output_ready = '1' then
				--read next value
				memory_readen <= '1';
				tail_next <= tail_incr;
				occupancy_next <= occupancy - 1;
				--if we run out of stuff, goto empty
				if almost_empty then
					state_next <= EMPTY;
				end if;
			end if;
		elsif state_curr = FULL_BUFFERED then
			output_valid <= '1';
			output_data <= input_buff;
			--do transaction if ready is up
			if output_ready = '1' then
				memory_readen <= '1';
				tail_next <= tail_incr;
				occupancy_next <= occupancy - 1;
				state_next <= HALF_UNBUFFERED;
			end if;
		elsif state_curr = FULL_UNBUFFERED then
			output_valid <= '1';
			output_data <= memory_out;
			--do transaction if ready is up
			if output_ready = '1' then
				memory_readen <= '1';
				tail_next <= tail_incr;
				occupancy_next <= occupancy - 1;
				state_next <= HALF_UNBUFFERED;
			end if;
		end if;
	end process;


end Behavioral;
