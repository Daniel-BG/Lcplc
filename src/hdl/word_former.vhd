----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 18.02.2019 12:21:47
-- Design Name: 
-- Module Name: WORD_FORMER - Behavioral
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

entity WORD_FORMER is
	Generic (
		DATA_WIDTH: integer := 39;
		WORD_WIDTH: integer := 32
	);
	Port (
		clk, rst		: in	std_logic;
		input_data		: in 	std_logic_vector(DATA_WIDTH - 1 + WORD_WIDTH - 1 downto 0);
		input_quantity	: in	natural range 0 to DATA_WIDTH;
		input_ready		: out	std_logic;
		input_valid		: in	std_logic;
		output_data		: out 	std_logic_vector(WORD_WIDTH - 1 downto 0);
		output_ready	: in	std_logic;
		output_valid	: out	std_logic
	);
end WORD_FORMER;



architecture Behavioral of WORD_FORMER is
	type former_state_t is (IDLE, MERGING, MERGING_ACC_EMPTY, MERGING_ACC_FULL);
	signal state_curr, state_next: former_state_t;
	
	signal acc_bits_left_curr, acc_bits_left_next: natural range 0 to DATA_WIDTH;
	signal acc_data_curr, acc_data_next: std_logic_vector(WORD_WIDTH - 1 downto 0);
	
	--buffers for input signals
	signal data_buf_curr, data_buf_next: std_logic_vector(DATA_WIDTH - 1 + WORD_WIDTH - 1 downto 0);
	signal quantity_buf_curr, quantity_buf_next: natural range 0 to DATA_WIDTH;
	
	
	
	
begin

	output_data <= acc_data_curr;

	seq: process(clk, rst) 
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= IDLE;
				data_buf_curr <= (others => '0');
				quantity_buf_curr <= 0;
				acc_bits_left_curr <= WORD_WIDTH;
				acc_data_curr <= (others => '0');
			else
				state_curr <= state_next;
				data_buf_curr <= data_buf_next;
				quantity_buf_curr <= quantity_buf_next;
				acc_bits_left_curr <= acc_bits_left_next;
				acc_data_curr <= acc_data_next;
			end if;
		end if;
	end process;
	
	comb: process(state_curr, data_buf_curr, quantity_buf_curr, input_valid, input_data, input_quantity, acc_bits_left_curr, output_ready, data_buf_next, acc_data_curr) 
	begin
		--defaults
		state_next <= state_curr;
		input_ready <= '0';
		output_valid <= '0';
		data_buf_next <= data_buf_curr;
		quantity_buf_next <= quantity_buf_curr;
		acc_bits_left_next <= acc_bits_left_curr;
		acc_data_next <= acc_data_curr;
		
		if state_curr = IDLE then
			input_ready <= '1';
			if input_valid = '1' then
				state_next <= MERGING;
				data_buf_next <= input_data;
				quantity_buf_next <= input_quantity;
			end if;
		elsif state_curr = MERGING then
			if acc_bits_left_curr = 0 then
				output_valid <= '1';
				--i can have stuff buffered or not
				--todo	
				if output_ready = '1' then
					if quantity_buf_curr > WORD_WIDTH then --a lot of bits left
						acc_data_next <= data_buf_next(data_buf_next'high downto data_buf_next'high - WORD_WIDTH + 1);
						acc_bits_left_next <= 0;
						data_buf_next <= data_buf_curr(data_buf_curr'high - WORD_WIDTH downto 0) & (WORD_WIDTH - 1 downto 0 => '0');
						quantity_buf_next <= quantity_buf_curr - WORD_WIDTH;
					elsif quantity_buf_curr > 0 then --some bits left
						acc_data_next <= data_buf_next(data_buf_next'high downto data_buf_next'high - WORD_WIDTH + 1);
						acc_bits_left_next <= WORD_WIDTH - quantity_buf_curr;
						input_ready <= '1';
						if input_valid = '1' then
							data_buf_next <= input_data;
							quantity_buf_next <= input_quantity;
						else
							data_buf_next <= (others => '0');
							quantity_buf_next <= 0;
						end if;
					else --no bits left
						input_ready <= '1';
						if input_valid = '1' then
							data_buf_next <= input_data;
							quantity_buf_next <= input_quantity;
						end if;
					end if;
				else
					--can only read if the buffer is empty
					if quantity_buf_curr = 0 then
						input_ready <= '1';
						if input_valid = '1' then
							data_buf_next <= input_data;
							quantity_buf_next <= input_quantity;
						end if;
					end if;
				end if;
			elsif quantity_buf_curr < acc_bits_left_curr then
				acc_data_next <= acc_data_curr or data_buf_next(data_buf_next'high downto data_buf_next'high - WORD_WIDTH + 1);
				acc_bits_left_next <= acc_bits_left_curr - quantity_buf_curr;
				input_ready <= '1';
				if input_valid = '1' then
					data_buf_next <= input_data;
					quantity_buf_next <= input_quantity;
				else --reset to avoid overwriting w/ stuff
					data_buf_next <= (others => '0');
					quantity_buf_next <= 0;
				end if;
			elsif quantity_buf_curr = acc_bits_left_curr then
				acc_data_next <= acc_data_curr or data_buf_next(data_buf_next'high downto data_buf_next'high - WORD_WIDTH + 1);
				acc_bits_left_next <= 0;
				input_ready <= '1';
				if input_valid = '1' then
					data_buf_next <= input_data;
					quantity_buf_next <= input_quantity;
				else --reset to avoid overwriting w/ stuff
					data_buf_next <= (others => '0');
					quantity_buf_next <= 0;
				end if;
			else --quantity_buf_curr > quantity_acc 
				acc_data_next <= acc_data_curr or data_buf_next(data_buf_next'high downto data_buf_next'high - WORD_WIDTH + 1);
				acc_bits_left_next <= 0;
				data_buf_next <= data_buf_curr(data_buf_curr'high - WORD_WIDTH downto 0) & (WORD_WIDTH - 1 downto 0 => '0');
				quantity_buf_next <= quantity_buf_curr - acc_bits_left_curr;
			end if;
		end if;
	end process;

end Behavioral;
