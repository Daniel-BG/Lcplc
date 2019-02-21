----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 21.02.2019 09:22:48
-- Design Name: 
-- Module Name: FIRSTBANDMODULE - Behavioral
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

entity FIRSTBANDMODULE is
	Generic (
		DATA_WIDTH: positive := 16;
		BLOCK_SIZE_LOG: positive := 8;
		ACC_LOG: positive := 5
	);
	Port (
		clk, rst		: in  std_logic;
		--input values
		x_valid			: in  std_logic;
		x_ready			: out std_logic;
		x_data			: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		--output mapped error, coding parameter and xhat out value
		merr_ready		: in std_logic;
		merr_valid		: out std_logic;
		merr_data		: out std_logic_vector(DATA_WIDTH + 2 downto 0);
		kj_ready		: in std_logic;
		kj_valid		: out std_logic;
		kj_data			: out std_logic_vector(ACC_LOG - 1 downto 0);
		xhatout_valid   : out std_logic;
		xhatout_ready	: in std_logic;
		xhatout_data	: out std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end FIRSTBANDMODULE;

architecture Behavioral of FIRSTBANDMODULE is
	type firstband_state_t is (IDLE, CODING_FIRST, CODING_REST);
	signal state_curr, state_next: firstband_state_t;

	--queue system for previous samples
	signal current_sample, left_sample, upper_sample: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal shift_enable: std_logic;

begin

	seq: process(clk)
	begin
		if rising_Edge(clk) then
			if rst = '1' then
				state_curr <= CODING_FIRST;
			else
				state_curr <= state_next;
				if shift_enable <= '1' then
					current_sample <= x_data;
					left_sample <= current_sample;
				end if;
			end if;
		end if;
	end process;
	
	shift_reg_prev_line: entity work.SHIFT_REG
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			DEPTH => 2**(BLOCK_SIZE_LOG/2)
		)
		Port map (
			clk => clk, enable => shift_enable,
			input => current_sample,
			output => upper_sample
		);
	
	comb: process(state_curr)
	begin
		x_ready <= '0';
		shift_enable <= '0';
		
		if state_curr = IDLE then
			x_ready <= '1';
			if x_valid = '1' then
				shift_enable <= '1';
				state_next <= CODING_FIRST;
			end if;
		elsif state_curr = CODING_FIRST then
		
		elsif state_curr = CODING_REST then
		
		end if;
	end process;

	


end Behavioral;
