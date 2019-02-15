----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 15.02.2019 12:48:02
-- Design Name: 
-- Module Name: PACKER - Behavioral
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

entity PACKER is
	Generic (
		CODE_WIDTH: integer := 39;
		OUTPUT_WIDTH: integer := 32
	);
	Port (
		clk, rst			: in	std_logic;
		flush				: in 	std_logic;
		flushed				: out 	std_logic;
		input_code_data		: in	std_logic_vector(CODE_WIDTH - 1 downto 0);
		input_length_data	: in 	natural range 0 to CODE_WIDTH;
		input_valid			: in 	std_logic;
		input_ready			: out 	std_logic;
		output_data			: out	std_logic_vector(OUTPUT_WIDTH - 1 downto 0);
		output_valid		: out	std_logic;
		output_ready		: in 	std_logic
	);

end PACKER;

architecture Behavioral of PACKER is
	--state for control
	type packer_state_t is (IDLE, PRIMED, FLUSHING, FINISHED);
	signal state_curr, state_next: packer_state_t;
	
	--align left
	signal input_code_aligned_left: std_logic_vector(CODE_WIDTH - 1 downto 0);
	
	--input buffers
	signal input_code_buffer, input_code_buffer_next: std_logic_vector(CODE_WIDTH - 1 downto 0);
	signal input_length_buffer, input_length_buffer_next: natural range 0 to CODE_WIDTH;
	
	--inner signals
	signal occupancy_total: natural range 0 to OUTPUT_WIDTH + CODE_WIDTH;
	signal filling_buffer: boolean;
	signal input_code_buffer_resized, input_code_buffer_shifted: std_logic_vector(OUTPUT_WIDTH - 1 downto 0);
	
	--merge
	signal output_buffer_next_keep: std_logic_vector(OUTPUT_WIDTH - 1 downto 0);
	signal output_buffer_filled: boolean;
	signal output_occupancy_next_keep: natural range 0 to OUTPUT_WIDTH;
	signal input_code_buffer_emptied: boolean;
	signal input_code_buffer_next_keep: std_logic_vector(CODE_WIDTH - 1 downto 0);
	signal input_length_buffer_next_keep: natural range 0 to CODE_WIDTH;
	
	--output signals
	signal output_buf, output_buf_next: std_logic_vector(OUTPUT_WIDTH - 1 downto 0);
	signal occupancy, occupancy_next: natural range 0 to OUTPUT_WIDTH;
	
	
begin

	occupancy_total <= occupancy + input_length_data;
	filling_buffer <= occupancy_total >= OUTPUT_WIDTH;

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= IDLE;
				output_buf <= (others => '0');
				occupancy  <= 0;
				input_code_buffer <= (others => '0');
				input_length_buffer <= 0;
			else
				state_curr <= state_next;
				output_buf <= output_buf_next;
				occupancy  <= occupancy_next;
				input_code_buffer <= input_code_buffer_next;
				input_length_buffer <= input_length_buffer_next;
			end if;
		end if;
	end process;
	
	--from input directly
	input_code_aligned_left <= std_logic_vector(shift_left(unsigned(input_code_data), CODE_WIDTH - input_length_data));
	
	--take the buffer and align it with the output buffer for just ORing the results together for output 
	gen_input_resized_0: if CODE_WIDTH >= OUTPUT_WIDTH generate
		input_code_buffer_resized <= input_code_buffer(CODE_WIDTH - 1 downto CODE_WIDTH - OUTPUT_WIDTH);
	end generate;
	gen_input_resized_1: if CODE_WIDTH < OUTPUT_WIDTH generate
		input_code_buffer_resized <= input_code_buffer(CODE_WIDTH - 1 downto 0) & (OUTPUT_WIDTH - CODE_WIDTH - 1 downto 0 => '0');
	end generate;
	input_code_buffer_shifted <= std_logic_vector(shift_right(unsigned(input_code_buffer_resized), occupancy));
	
	--this is the current buffer ored with the shifted input code buffer. It is output when its length fills OUTPUT_WIDTH bits or
	--else it is saved on to the output_buffer for further bit injection
	output_buffer_next_keep	<= output_buf or input_code_buffer_shifted;
	--flag indicating if the buffer fills this cycle (adding the bits in the input buffer to the ones on the output buffer)
	output_buffer_filled    <= occupancy + input_length_buffer >= OUTPUT_WIDTH;
	--occupancy of the output buffer after adding the bits from the input buffer
	output_occupancy_next_keep <= OUTPUT_WIDTH when occupancy + input_length_buffer >= OUTPUT_WIDTH else occupancy + input_length_buffer;
	
	--true when the input buffer is to be emptied this cycle to the output buffer
	input_code_buffer_emptied <= occupancy + input_length_buffer <= OUTPUT_WIDTH;
	--next input code buffer assuming we don't need new data (that is, it still contains valid data that has not been yet output)
	input_code_buffer_next_keep <= std_logic_vector(shift_left(unsigned(input_code_buffer), OUTPUT_WIDTH - occupancy));
	--length of the input buffer after sending some bits to the output buffer and still having some remaining
	input_length_buffer_next_keep <= input_length_buffer - OUTPUT_WIDTH + occupancy;
	
	comb: process(state_curr, flush, output_ready, 
		input_valid, input_length_data, input_code_aligned_left, 
		input_code_buffer_emptied, input_length_buffer, input_code_buffer, input_code_buffer_next_keep, input_length_buffer_next_keep, 
		output_buffer_next_keep, output_occupancy_next_keep, output_buffer_filled,
		output_buf, occupancy)
	begin
		--default values
		state_next <= state_curr;
		input_ready <= '0';
		output_valid <= '0';
		input_length_buffer_next <= input_length_buffer;
		input_code_buffer_next   <= input_code_buffer;
		output_data  <= (others => '0');
		output_buf_next <= output_buf;
		occupancy_next <= occupancy;
		flushed <= '0';
		
		if state_curr = IDLE then
			if flush = '1' then
				state_next <= FLUSHING;
			else
				input_ready <= '1';
				if input_valid = '1' then
					input_code_buffer_next <= input_code_aligned_left;
					input_length_buffer_next <= input_length_data;
				end if;
			end if;
		elsif state_curr = PRIMED then
			if output_buffer_filled and input_code_buffer_emptied then
				output_valid <= '1';
				output_data <= output_buffer_next_keep;
				if output_ready = '1' then
					output_buf_next <= (others => '0');
					occupancy_next <= 0;
					input_ready <= '1';
					if input_valid = '0' then
						--just outputting, we have nothing new
						input_length_buffer_next <= 0;
						state_next <= IDLE;
					else
						--outputting and getting new value. keep primed state
						input_code_buffer_next <= input_code_aligned_left;
						input_length_buffer_next <= input_length_data;
					end if;
				end if;
			elsif output_buffer_filled then
				--we still have stuff in input code buffer, so don't read anything new
				output_valid <= '1';
				output_data <= output_buffer_next_keep;
				if output_ready = '1' then
					output_buf_next <= (others => '0');
					occupancy_next <= 0;
					--could do a bypass here directly to output buffer but for now it's ok
					input_code_buffer_next <= input_code_buffer_next_keep;
					input_length_buffer_next <= input_length_buffer_next_keep;
				end if;
			else --obf = 0 and icbf = '1', both zero is impossible
				--we need more values here
				input_ready <= '1';
				if input_valid = '1' then
					output_buf_next <= output_buffer_next_keep;
					occupancy_next <= output_occupancy_next_keep;
					input_code_buffer_next <= input_code_aligned_left;
					input_length_buffer_next <= input_length_data;
				end if;
			end if;
		elsif state_curr = FLUSHING then
			output_valid <= '1';
			output_data <= output_buf;
			if output_ready = '1' then
				state_next <= FINISHED;
			end if;
		elsif state_curr = FINISHED then
			flushed <= '1'; --will need to be reset to go out of this state
		end if;
	end process;

	


end Behavioral;
