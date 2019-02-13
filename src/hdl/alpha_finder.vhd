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

entity alpha_finder is
	generic (
		DATA_WIDTH: integer := 16;
		BLOCK_SIZE_LOG: integer := 8;
		ALPHA_DEPTH: integer := 10
	);
	port (
		clk, rst, en: in std_logic;
		alphan: in std_logic_vector(DATA_WIDTH*2 + 2 + BLOCK_SIZE_LOG - 1 downto 0);
		alphad: in std_logic_vector(DATA_WIDTH*2 + 2 + BLOCK_SIZE_LOG - 1 downto 0);
		res: out std_logic_vector(ALPHA_DEPTH - 1 downto 0);
		done: out std_logic
	);
end alpha_finder;



architecture Behavioral of alpha_finder is
	type alpha_finder_state_t is (IDLE, DIVIDING, FINISHED);
	signal state_curr, state_next: alpha_finder_state_t;
	
	
	signal alphan_reg_curr, alphan_reg_next, alphad_reg_curr, alphad_reg_next: std_logic_vector (DATA_WIDTH*2 + 2 + BLOCK_SIZE_LOG - 1 downto 0);
	
	signal alpha_reg_curr, alpha_reg_next: std_logic_vector(ALPHA_DEPTH - 1 downto 0);
	
	
	signal counter_curr, counter_next: natural range 0 to ALPHA_DEPTH;
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
	
	comb: process(state_curr, en, counter_curr, alphad, alphan, alphad_reg_curr, alphan_reg_curr, alpha_reg_curr)
	begin
		state_next <= state_curr;
		alphad_reg_next <= alphad_reg_curr;
		alphan_reg_next <= alphan_reg_curr;
		counter_next <= counter_curr;
		alpha_reg_next <= alpha_reg_curr;
		done <= '0';
	
		if state_curr = IDLE then
			if en = '1' then
				state_next <= DIVIDING;
				alphad_reg_next <= alphad;
				alphan_reg_next <= alphan;
				alpha_reg_next <= (others => '0');
				counter_next <= 1;
			end if;
		elsif state_curr = DIVIDING then
			if counter_curr = ALPHA_DEPTH then
				state_next <= FINISHED;
			else
				counter_next <= counter_curr + 1;
			end if;
			
			if signed(alphan_reg_curr) > signed(alphad_reg_curr) then
				alphan_reg_next <= std_logic_vector(signed(alphan_reg_curr) - signed(alphad_reg_curr));
				alpha_reg_next  <= alpha_reg_curr(ALPHA_DEPTH - 2 downto 0) & '1';
			else
				alpha_reg_next  <= alpha_reg_curr(ALPHA_DEPTH - 2 downto 0) & '0';
			end if;
			--right logical shif (value is positive so we can shift zeroes in)
			alphad_reg_next <= '0' & alphad_reg_curr(alphad_reg_curr'length-1 downto 1);
		elsif state_curr = FINISHED then
			done <= '1';
			if en = '0' then
				state_next <= IDLE;
			end if;
		end if;
	end process;

	res <= alpha_reg_curr;
	
	
end Behavioral;
