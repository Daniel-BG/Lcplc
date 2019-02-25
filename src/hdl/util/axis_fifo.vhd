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
		constant FIFO_DEPTH: positive := 256
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
	
	signal output_valid_in, input_ready_in: std_logic;
	
	signal head, head_next, tail, tail_next, tail_lookahead, tail_lookahead_next: natural range 0 to FIFO_DEPTH - 1;
	signal occupancy: natural range 0 to FIFO_DEPTH;
	
	signal input_empty, input_full: std_logic;
	signal next_input_empty, next_input_full: std_logic;
	
	signal dataout_mem, dataout_last: std_logic_vector (DATA_WIDTH - 1 downto 0);
	signal last_read_fromin: std_logic;
	
	--precalc flags
	signal occupancy_0_flag, occupancy_1_flag: std_logic;
begin

	output_valid_in <= not input_empty;
	input_ready_in  <= not input_full;
	output_valid <= output_valid_in;
	input_ready  <= input_ready_in;

	next_input_empty <= '1' when 
					(occupancy = 0 and input_valid = '0') or 
					(occupancy = 1 and input_valid = '0' and output_ready = '1') 
					else '0';					
	next_input_full <= '1' when 
					(occupancy = FIFO_DEPTH and (output_ready = '0' or (output_ready = '1' and input_valid = '1'))) or
					(occupancy = FIFO_DEPTH - 1 and input_valid = '1' and output_ready = '0')
					else '0';
					
	tail_next <= 0 when tail = FIFO_DEPTH - 1 else tail + 1;
	tail_lookahead_next <= 0 when tail_lookahead = FIFO_DEPTH - 1 else tail_lookahead + 1;
	head_next <= 0 when head = FIFO_DEPTH - 1 else head + 1;
					
	update_flags: process(clk, rst)
	begin
		if (rising_edge(clk)) then
			if rst = '1' then
				input_empty <= '1';
				input_full <= '0';
			else
				input_empty <= next_input_empty;
				input_full <= next_input_full;
			end if;
		end if;
	end process;


	main_proc: process(clk)
	begin
		if (rising_edge(clk)) then
			if rst = '1' then
				head <= 0;
				tail <= 0;
				tail_lookahead <= 1;
				occupancy <= 0;
				occupancy_0_flag <= '1';
				occupancy_1_flag <= '0';
			else	
				--read always to avoid LUT on input enable
				dataout_mem <= memory(tail_lookahead);
				--read and write		
				if (input_valid = '1' and input_ready_in = '1' and output_ready = '1' and output_valid_in = '1') then
					tail <= tail_next;
					tail_lookahead <= tail_lookahead_next;
					memory(head) <= input_data;
					head <= head_next;
										
					if occupancy_1_flag = '1'  then
						last_read_fromin <= '1';
						dataout_last <= input_data;
					else
						--dataout_mem <= memory(tail_lookahead);
						last_read_fromin <= '0';
					end if;
				--just write
				elsif (input_valid = '1' and input_ready_in = '1') then 
					occupancy <= occupancy + 1;
					memory(head) <= input_data;
					head <= head_next;
					occupancy_0_flag <= '0';
					
					if occupancy_0_flag = '1' then
						last_read_fromin <= '1';
						dataout_last <= input_data;
						occupancy_1_flag <= '1';
					else
						occupancy_1_flag <= '0';
					end if;
					--	last_read_fromin <= '0';
					--	dataout_mem <= memory(tail);
					--	occupancy_1_flag <= '0';
					--end if; --otherwise it alredy has the value
				--just read
				elsif (output_ready = '1' and output_valid_in = '1') then 
					occupancy <= occupancy - 1;
					tail <= tail_next;
					tail_lookahead <= tail_lookahead_next;
					--dataout_mem <= memory(tail_lookahead);
					last_read_fromin <= '0';
					if occupancy = 2 then
						occupancy_1_flag <= '1';
					else
						occupancy_1_flag <= '0';
					end if;
					if occupancy = 1 then
						occupancy_0_flag <= '1';
					else
						occupancy_0_flag <= '0';
					end if;
				end if;
			end if;
		end if;
	end process;
	
	output_data <= dataout_mem when last_read_fromin = '0' else dataout_last;


end Behavioral;
