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

entity AXIS_SHIFTER is
	Generic (
		SHIFT_WIDTH	: integer := 6;
		DATA_WIDTH	: integer := 39;
		LEFT		: boolean := true;
		ARITHMETIC	: boolean := false
	);
	Port ( 
		clk, rst		: in	std_logic;
		shift_data		: in 	std_logic_vector(SHIFT_WIDTH - 1 downto 0);
		shift_ready		: out   std_logic;
		shift_valid		: in 	std_logic;
		input_data		: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_ready		: out	std_logic;
		input_valid		: in	std_logic;
		output_data		: out 	std_logic_vector(DATA_WIDTH - 1 downto 0);
		output_ready	: in	std_logic;
		output_valid	: out	std_logic
	);
end AXIS_SHIFTER;

architecture Behavioral of AXIS_SHIFTER is
	--synchronizer signals
	signal synced_shift	: std_logic_vector(SHIFT_WIDTH - 1 downto 0);
	signal synced_data	: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal synced_valid, synced_ready: std_logic;

	--shifting signals
	type data_storage_t is array(0 to SHIFT_WIDTH) of std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal memory_curr: data_storage_t;
	type data_storage_t_1 is array(1 to SHIFT_WIDTH) of std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal memory_next: data_storage_t_1;
	type data_storage_t_swm1 is array(0 to SHIFT_WIDTH-1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal shifted_values: data_storage_t_swm1;
	
	type shiftamt_storage_t is array(0 to SHIFT_WIDTH) of std_logic_vector(SHIFT_WIDTH - 1 downto 0);
	signal shiftamt_curr: shiftamt_storage_t;
	
	signal valid: std_logic_vector(SHIFT_WIDTH downto 0);
	signal enable: std_logic;
begin

	sync_inputs: entity work.AXIS_SYNCHRONIZER_2
		Generic map (DATA_WIDTH_0 => SHIFT_WIDTH, DATA_WIDTH_1 => DATA_WIDTH)
		Port map (
			clk => clk, rst => rst,
			input_0_valid => shift_valid,
			input_0_ready => shift_ready,
			input_0_data  => shift_data,
			input_1_valid => input_valid,
			input_1_ready => input_ready,
			input_1_data  => input_data,
			output_valid  => synced_valid,
			output_ready  => synced_ready,
			output_data_0 => synced_shift,
			output_data_1 => synced_data
		);



	--enable when i have something at the output and it is being read
	--or when i have nothing to output
	enable <= '1' when output_ready = '1' or valid(SHIFT_WIDTH) = '0' else '0';
	
	output_valid <= valid(SHIFT_WIDTH);
	synced_ready <= enable;
	output_data <= memory_curr(SHIFT_WIDTH);
	
	gen_next_vals: for i in 1 to SHIFT_WIDTH generate
		memory_next(i) <= shifted_values(i-1) when shiftamt_curr(i-1)(i-1) = '1' else memory_curr(i-1);
	end generate;

	gen_left_shift: if LEFT generate
		gen_shifts: for i in 0 to SHIFT_WIDTH - 1 generate
			shifted_values(i) <= memory_curr(i)(DATA_WIDTH - 1 - 2**i downto 0) & (2**i - 1 downto 0 => '0');
		end generate;
	end generate;

	gen_right_shift: if not LEFT generate
		gen_shifts: for i in 0 to SHIFT_WIDTH - 1 generate
			gen_arith: if ARITHMETIC generate
				shifted_values(i) <= (2**i - 1 downto 0 =>  memory_curr(i)(DATA_WIDTH)) & memory_curr(i)(DATA_WIDTH - 1 downto 2**i);
			end generate;
			gen_logic: if NOT ARITHMETIC generate
				shifted_values(i) <= (2**i - 1 downto 0 => '0') & memory_curr(i)(DATA_WIDTH - 1 downto 2**i);
			end generate;
		end generate;
	end generate;
	
	
	seq: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then	
				valid <= (others => '0');
			else
				if enable = '1' then
					--do all necessary shifting
					for i in 1 to SHIFT_WIDTH loop
						memory_curr(i) <= memory_next(i);
						shiftamt_curr(i) <= shiftamt_curr(i-1);
						valid(i) <= valid(i-1);
					end loop;
					if synced_valid = '1' then
						--shift in a 1 into the input
						memory_curr(0) <= synced_data;
						shiftamt_curr(0) <= synced_shift;
						valid(0) <= '1'; 
					else
						--shift in a 0 into the input
						memory_curr(0) <= (others => '0');
						shiftamt_curr(0) <= (others => '0');
						valid(0) <= '0';
					end if; 
				end if;
			end if;
		end if;
	end process;

end Behavioral;
