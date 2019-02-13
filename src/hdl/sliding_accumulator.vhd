----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12.02.2019 15:39:07
-- Design Name: 
-- Module Name: accumulator - Behavioral
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

entity SLIDING_ACCUMULATOR is
	Generic (
		DATA_WIDTH: integer := 16;
		ACC_LOG: integer := 5
	);
	Port (
		clk, rst: in std_logic;
		input: in std_logic_vector(DATA_WIDTH - 1 downto 0);
		input_valid: in std_logic;
		input_ready: out std_logic;
		output_cnt: out std_logic_vector(ACC_LOG downto 0);
		output_data: out std_logic_vector(DATA_WIDTH + ACC_LOG - 1 downto 0);
		output_valid: out std_logic;
		output_ready: in std_logic
	);
end SLIDING_ACCUMULATOR;

architecture Behavioral of SLIDING_ACCUMULATOR  is
	signal input_ready_in, output_valid_in: std_logic;
	signal write, read: std_logic;

	signal accumulator: std_logic_vector(DATA_WIDTH + ACC_LOG - 1 downto 0);
	signal input_queued: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	
	signal counter: natural range 0 to 2**ACC_LOG;
	
	signal full: std_logic;

begin

	input_ready_in <= '1' when full = '0' or output_ready = '1' else '0';
	output_valid_in <= full;
	
	write <= '1' when input_valid = '1' and input_ready_in = '1' else '0';
	read  <= '1' when output_ready = '1' and output_valid_in = '1' else '0';
	
	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				accumulator <= (others => '0');
				counter <= 0;
				full <= '0';
			else
				if write = '1' then
					full <= '1';
					if counter = 2**ACC_LOG then
						--acc saturated, substract from mem
						accumulator <= std_logic_vector(unsigned(accumulator) + unsigned((ACC_LOG - 1 downto 0 => '0') & input) - unsigned((ACC_LOG - 1 downto 0 => '0') & input_queued));
					else
						--acc not saturated yet, keep adding
						counter <= counter + 1;
						accumulator <= std_logic_vector(unsigned(accumulator) + unsigned((ACC_LOG - 1 downto 0 => '0') & input));
					end if;
				else
					if read = '1' then
						full <= '0';
					end if;
				end if;
			end if;
		end if;
	end process;
	
	sample_queue: entity work.FIFO_AXI
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			FIFO_DEPTH => 2**ACC_LOG
		)
		Port map (
			clk => clk, rst => rst,
			in_valid => write,
			in_ready => open, --assume always 1 by construction
			in_data  => input,
			out_ready => read,
			out_data  => input_queued,
			out_valid => open --assume always valid by construction
		);
	
	output_cnt	<= std_logic_vector(to_unsigned(counter, ACC_LOG + 1));
	output_data	<= accumulator;
	
	input_ready <= input_ready_in;
	output_valid <= output_valid_in;
	
	
end Behavioral;
