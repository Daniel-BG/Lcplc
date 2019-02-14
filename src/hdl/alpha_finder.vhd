----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08.02.2019 15:17:28
-- Design Name: 
-- Module Name: alpha_finder - Behavioral
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

entity ALPHA_FINDER is
	generic (
		DATA_WIDTH: integer := 16;
		BLOCK_SIZE_LOG: integer := 8;
		ALPHA_WIDTH: integer := 10
	);
	port (
		clk, rst: in std_logic;
		input_data_alphan: in std_logic_vector(DATA_WIDTH*2 + 2 + BLOCK_SIZE_LOG - 1 downto 0);
		input_data_alphad: in std_logic_vector(DATA_WIDTH*2 + 2 + BLOCK_SIZE_LOG - 1 downto 0);
		input_ready: out std_logic;
		input_valid: in std_logic;
		output_data: out std_logic_vector(ALPHA_WIDTH - 1 downto 0);
		output_ready: in std_logic;
		output_valid: out std_logic
	);
end ALPHA_FINDER;


architecture Behavioral of ALPHA_FINDER is
	type alpha_finder_state_t is (IDLE, DIVIDING, FINISHED);
	signal state_curr, state_next: alpha_finder_state_t;
	
	
	signal alphan_reg_curr, alphan_reg_next, alphad_reg_curr, alphad_reg_next: std_logic_vector (DATA_WIDTH*2 + 2 + BLOCK_SIZE_LOG - 1 downto 0);
	
	signal alpha_reg_curr, alpha_reg_next: std_logic_vector(ALPHA_WIDTH - 1 downto 0);
	
	
	signal counter_curr, counter_next: natural range 0 to ALPHA_WIDTH;
begin

	seq: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr <= IDLE;
				alphan_reg_curr <= (others => '0');
				alphad_reg_curr <= (others => '0');
				alpha_reg_curr <= (others => '0');
				counter_curr <= 0;
			else
				state_curr <= state_next;
				alphan_reg_curr <= alphan_reg_next;
				alphad_reg_curr <= alphad_reg_next;
				alpha_reg_curr <= alpha_reg_next;
				counter_curr <= counter_next;
			end if;
		end if;
	end process;
	
	comb: process(state_curr, input_valid, output_ready, counter_curr, input_data_alphad, input_data_alphan, alphad_reg_curr, alphan_reg_curr, alpha_reg_curr)
	begin
		input_ready <= '0';
		output_valid <= '0';
	
		state_next <= state_curr;
		alphad_reg_next <= alphad_reg_curr;
		alphan_reg_next <= alphan_reg_curr;
		counter_next <= counter_curr;
		alpha_reg_next <= alpha_reg_curr;
	
		if state_curr = IDLE then
			input_ready <= '1';
			if input_valid = '1' then
				state_next <= DIVIDING;
				alphad_reg_next <= input_data_alphad;
				alphan_reg_next <= input_data_alphan;
				alpha_reg_next <= (others => '0');
				counter_next <= 1;
			end if;
		elsif state_curr = DIVIDING then
			if counter_curr = ALPHA_WIDTH then
				state_next <= FINISHED;
			else
				counter_next <= counter_curr + 1;
			end if;
			
			if signed(alphan_reg_curr) > signed(alphad_reg_curr) then
				alphan_reg_next <= std_logic_vector(signed(alphan_reg_curr) - signed(alphad_reg_curr));
				alpha_reg_next  <= alpha_reg_curr(ALPHA_WIDTH - 2 downto 0) & '1';
			else
				alpha_reg_next  <= alpha_reg_curr(ALPHA_WIDTH - 2 downto 0) & '0';
			end if;
			--right logical shif (value is positive so we can shift zeroes in)
			alphad_reg_next <= '0' & alphad_reg_curr(alphad_reg_curr'length-1 downto 1);
		elsif state_curr = FINISHED then
			output_valid <= '1';
			if output_ready = '0' then
				state_next <= IDLE;
			end if;
		end if;
	end process;

	output_data <= alpha_reg_curr;
	
	
end Behavioral;
