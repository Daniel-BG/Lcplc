----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12.02.2019 16:59:06
-- Design Name: 
-- Module Name: transaction_limiter - Behavioral
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

entity TRANSACTION_LIMITER is
	Generic(
		DATA_WIDTH: integer := 16;
		NUMBER_OF_TRANSACTIONS: positive := 256
	);
	Port (
		--metacontrol signals
		clk, rst: in std_logic;
		clear: in std_logic;
		--control signals
		saturated: out std_logic;
		--axi bus controls (data goes directly, only control signals are dealt with here)
		input_valid: in std_logic;
		input_ready: out std_logic;
		output_valid: out std_logic;
		output_ready: in std_logic
	);
end TRANSACTION_LIMITER;

architecture Behavioral of TRANSACTION_LIMITER is
	signal counter, counter_next: natural range 0 to NUMBER_OF_TRANSACTIONS - 1;
	signal saturated_local_next: std_logic;
	signal saturated_local: std_logic;
	
	signal enable, transaction: std_logic;
begin

	saturated_local_next <= '1' when counter = NUMBER_OF_TRANSACTIONS - 1 else '0';
	counter_next <= counter + 1;
	
	--saturated output
	saturated <= saturated_local;
	enable <= not saturated_local;

	enabler: entity work.TRANSACTION_ENABLER
		Port map (
			enable => enable,
			transaction => transaction,
			input_valid => input_valid,
			input_ready => input_ready,
			output_valid => output_valid, 
			output_ready => output_ready
		);
		
	seq: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' or clear = '1' then
				counter <= 0;
				saturated_local <= '0';
			else
				if transaction = '1' then
					counter <= counter_next;
					saturated_local <= saturated_local_next;
				end if;
			end if;
		end if;
	end process;
	
end Behavioral;
