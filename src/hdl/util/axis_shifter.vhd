----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 18.02.2019 10:28:00
-- Design Name: 
-- Module Name: AXIS_SHIFTER - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: shift values left or right arithmetic or logical 
--		(latency is equal to SHIFT_WIDTH+1)
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
use work.FUNCTIONS.ALL;
use work.data_types.all;
use work.constants.all;

entity AXIS_SHIFTER is
	Generic (
		SHIFT_WIDTH	: integer := 7;
		INPUT_WIDTH : integer := 39;
		OUTPUT_WIDTH: integer := 70;
		BITS_PER_STAGE: integer := 7;
		LEFT		: boolean := true;
		ARITHMETIC	: boolean := false;
		LATCH_INPUT_SYNC: boolean := true;
		LAST_POLICY: last_policy_t := PASS_ONE
	);
	Port ( 
		clk, rst		: in	std_logic;
		shift_data		: in 	std_logic_vector(SHIFT_WIDTH - 1 downto 0);
		shift_ready		: out   std_logic;
		shift_valid		: in 	std_logic;
		shift_last		: in 	std_logic := '0';
		input_data		: in	std_logic_vector(INPUT_WIDTH - 1 downto 0);
		input_ready		: out	std_logic;
		input_valid		: in	std_logic;
		input_last  	: in  	std_logic := '0';
		output_data		: out 	std_logic_vector(OUTPUT_WIDTH - 1 downto 0);
		output_ready	: in	std_logic;
		output_valid	: out	std_logic;
		output_last		: out 	std_logic
	);
end AXIS_SHIFTER;

architecture Behavioral of AXIS_SHIFTER is
	constant STAGES: integer := (SHIFT_WIDTH + BITS_PER_STAGE - 1) / BITS_PER_STAGE;

	--synchronizer signals
	signal synced_shift	: std_logic_vector(SHIFT_WIDTH - 1 downto 0);
	signal synced_data 	: std_logic_vector(INPUT_WIDTH - 1 downto 0);
	signal synced_valid, synced_ready, synced_last: std_logic;

	--shifting signals
	type data_storage_t is array(0 to STAGES) of std_logic_vector(OUTPUT_WIDTH - 1 downto 0);
	signal memory_curr: data_storage_t;
	type data_storage_t_1 is array(1 to STAGES) of std_logic_vector(OUTPUT_WIDTH - 1 downto 0);
	signal memory_next: data_storage_t_1;
	type data_storage_t_swm1 is array(0 to STAGES-1) of std_logic_vector(OUTPUT_WIDTH - 1 downto 0);
	signal shifted_values: data_storage_t_swm1;
	
	type shiftamt_storage_t is array(0 to STAGES-1) of std_logic_vector(SHIFT_WIDTH - 1 downto 0);
	signal shiftamt_curr, shiftamt_final: shiftamt_storage_t;
	
	attribute KEEP of shiftamt_curr: signal is KEEP_DEFAULT;
	
	signal valid, valid_next: std_logic_vector(STAGES downto 0);
	signal last, last_next: std_logic_vector(STAGES downto 0);
	signal enable: std_logic;
begin

	sync_inputs: entity work.AXIS_SYNCHRONIZER_2
		Generic map (
			DATA_WIDTH_0 => SHIFT_WIDTH, 
			DATA_WIDTH_1 => INPUT_WIDTH,
			LATCH 		 => LATCH_INPUT_SYNC,
			LAST_POLICY  => LAST_POLICY
		)
		Port map (
			clk => clk, rst => rst,
			input_0_valid => shift_valid,
			input_0_ready => shift_ready,
			input_0_data  => shift_data,
			input_0_last  => shift_last,
			input_1_valid => input_valid,
			input_1_ready => input_ready,
			input_1_data  => input_data,
			input_1_last  => input_last,
			output_valid  => synced_valid,
			output_ready  => synced_ready,
			output_data_0 => synced_shift,
			output_data_1 => synced_data,
			output_last   => synced_last
		);



	--enable when i have something at the output and it is being read
	--or when i have nothing to output
	enable <= '1' when output_ready = '1' or valid(STAGES) = '0' else '0';
	
	output_last  <= last(STAGES);
	output_valid <= valid(STAGES);
	synced_ready <= enable;
	output_data <= memory_curr(STAGES);
	
	gen_next_vals: for i in 1 to STAGES generate
		memory_next(i) <= shifted_values(i-1); --when shiftamt_curr(i-1)(i-1) = '1' else memory_curr(i-1);
	end generate;
	gen_shamt_final: for i in 0 to STAGES - 1 generate
		gen_opt_0: if SHIFT_WIDTH - 1 < BITS_PER_STAGE*(i+1) and BITS_PER_STAGE*i - 1 < 0 generate
			shiftamt_final(i) <= 
				shiftamt_curr(i)(minval(BITS_PER_STAGE*(i+1) - 1, SHIFT_WIDTH - 1) downto BITS_PER_STAGE*i);
		end generate;
		gen_opt_1: if SHIFT_WIDTH - 1 < BITS_PER_STAGE*(i+1) and BITS_PER_STAGE*i - 1 >= 0 generate
			shiftamt_final(i) <= 
				shiftamt_curr(i)(minval(BITS_PER_STAGE*(i+1) - 1, SHIFT_WIDTH - 1) downto BITS_PER_STAGE*i) 
				& (BITS_PER_STAGE*i - 1 downto 0 => '0');
		end generate;
		gen_opt_2: if SHIFT_WIDTH - 1 >= BITS_PER_STAGE*(i+1) and BITS_PER_STAGE*i - 1 < 0 generate
			shiftamt_final(i) <= 
				  (SHIFT_WIDTH - 1 downto BITS_PER_STAGE*(i+1) => '0')
				& shiftamt_curr(i)(minval(BITS_PER_STAGE*(i+1) - 1, SHIFT_WIDTH - 1) downto BITS_PER_STAGE*i);
		end generate;
		gen_opt_3: if SHIFT_WIDTH - 1 >= BITS_PER_STAGE*(i+1) and BITS_PER_STAGE*i - 1 >= 0 generate
			shiftamt_final(i) <= 
				  (SHIFT_WIDTH - 1 downto BITS_PER_STAGE*(i+1) => '0')
				& shiftamt_curr(i)(minval(BITS_PER_STAGE*(i+1) - 1, SHIFT_WIDTH - 1) downto BITS_PER_STAGE*i) 
				& (BITS_PER_STAGE*i - 1 downto 0 => '0');
		end generate;
		
		
		--shiftamt_final(i) <= 
		--	  (SHIFT_WIDTH - 1 downto BITS_PER_STAGE*(i+1) => '0')
		--	& shiftamt_curr(i)(minval(BITS_PER_STAGE*(i+1) - 1, SHIFT_WIDTH - 1) downto BITS_PER_STAGE*i) 
		--	& (BITS_PER_STAGE*i - 1 downto 0 => '0');
			
		--shiftamt_final(i) <= 
		--	std_logic_vector(resize(unsigned(
		--		shiftamt_curr(i)(minval(BITS_PER_STAGE*(i+1) - 1, SHIFT_WIDTH - 1) downto BITS_PER_STAGE*i) 
		--		& (BITS_PER_STAGE*i - 1 downto 0 => '0')
		--	) , SHIFT_WIDTH));
			
	end generate;
	
	gen_left_shift: if LEFT generate
		gen_shifts: for i in 0 to STAGES - 1 generate
			shifted_values(i) <= std_logic_vector(shift_left(
				unsigned(memory_curr(i)), 
				to_integer(unsigned(shiftamt_final(i)))
			)); 
			--memory_curr(i)(DATA_WIDTH - 1 - 2**i downto 0) & (2**i - 1 downto 0 => '0');
		end generate;
	end generate;

	gen_right_shift: if not LEFT generate
		gen_shifts: for i in 0 to STAGES - 1 generate
			gen_arith: if ARITHMETIC generate
				shifted_values(i) <= std_logic_vector(shift_right(
					signed(memory_curr(i)), 
					to_integer(unsigned(shiftamt_final(i)))
				)); 
				--shifted_values(i) <= (2**i - 1 downto 0 =>  memory_curr(i)(DATA_WIDTH)) & memory_curr(i)(DATA_WIDTH - 1 downto 2**i);
			end generate;
			gen_logic: if NOT ARITHMETIC generate
				shifted_values(i) <= std_logic_vector(shift_right(
					unsigned(memory_curr(i)), 
					to_integer(unsigned(shiftamt_final(i)))
				)); 
				--shifted_values(i) <= (2**i - 1 downto 0 => '0') & memory_curr(i)(DATA_WIDTH - 1 downto 2**i);
			end generate;
		end generate;
	end generate;

--	comb: process(synced_data, synced_shift, enable, synced_valid)
--	begin
--	memory_curr(0) <= synced_data;
--		shiftamt_curr(0) <= synced_shift;
--		if enable = '1' and synced_valid = '1' then
--			valid(0) <= '1';
--		else
--			valid(0) <= '0';
--		end if;
--		--valid(0) <= '1' when enable = '1' and synced_valid = '1' else '0';
--	end process;

	next_valid_last_assign: process(synced_last, synced_valid, enable, valid, last)
	begin
		last_next(0) <= synced_last;
		if enable = '1' and synced_valid = '1' then
			valid_next(0) <= '1';
		else
			valid_next(0) <= '0';
		end if;
		for i in 1 to STAGES loop
			valid_next(i) <= valid(i);
			last_next (i) <= last (i);
		end loop;
	
	end process;
--	valid_next: std_logic_vector(STAGES downto 0);
--	signal last, last_next
	
	seq: process(clk, rst, synced_data, synced_shift, synced_valid, enable, synced_last)
	begin
		memory_curr(0) <= std_logic_vector(resize(unsigned(synced_data), OUTPUT_WIDTH));
		shiftamt_curr(0) <= synced_shift;
--		last(0) <= synced_last;
--		if enable = '1' and synced_valid = '1' then
--			valid(0) <= '1';
--		else
--			valid(0) <= '0';
--		end if;

		if rising_edge(clk) then
			if rst = '1' then	
				valid(valid'high downto 0) <= (others => '0');
				last (last'high  downto 0) <= (others => '0');
			else
				if enable = '1' then
					--do all necessary shifting
					for i in 1 to STAGES loop
						memory_curr(i) <= memory_next(i);
						valid(i) <= valid_next(i-1);
						last (i) <= last_next (i-1);
					end loop;
					for i in 1 to STAGES - 1 loop
						shiftamt_curr(i) <= shiftamt_curr(i-1);
					end loop;
				end if;
			end if;
		end if;
	end process;

end Behavioral;
