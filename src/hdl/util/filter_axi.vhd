----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 20.02.2019 11:07:14
-- Design Name: 
-- Module Name: FILTER_AXI - Behavioral
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

entity FILTER_AXI is
	Generic (
		DATA_WIDTH: integer := 16;
		FILTER_ON_UP: boolean := true
	);
	Port (
		clk, rst		: in 	std_logic;
		input_valid		: in	std_logic;
		input_ready		: out	std_logic;
		input_data		: in	std_logic_vector(DATA_WIDTH - 1 downto 0);
		flag_valid		: in	std_logic;
		flag_ready		: out	std_logic;
		flag_data		: in	std_logic_vector(0 downto 0);
		--to output axi ports
		output_valid	: out 	std_logic;
		output_ready	: in 	std_logic;
		output_data		: out	std_logic_vector(DATA_WIDTH - 1 downto 0)
	);
end FILTER_AXI;


architecture Behavioral of FILTER_AXI is
	--synced signals
	signal synced_valid, synced_ready: std_logic;
	signal synced_data: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal synced_flag: std_logic_vector(0 downto 0);
begin

	--need to sync input and flag
	input_joiner: entity work.JOINER_AXI_2 
		Generic map (
			DATA_WIDTH_0 => DATA_WIDTH,
			DATA_WIDTH_1 => 1
		)
		Port map(
			clk => clk, rst => rst,
			--to input axi port
			input_valid_0 => input_valid, 
			input_valid_1 => flag_valid,
			input_ready_0 => input_ready, 
			input_ready_1 => flag_ready,
			input_data_0  => input_data,
			input_data_1  => flag_data,
			--to output axi ports
			output_valid  => synced_valid,
			output_ready  => synced_ready,
			output_data_0 => synced_data,
			output_data_1 => synced_flag
		);
		
	gen_elim_on_up: if FILTER_ON_UP generate
		output_valid <= '1' when synced_valid = '1' and synced_flag = "0" else '0';
		synced_ready <= '1' when output_ready = '1' or (synced_valid = '1' and synced_flag = "1") else '0';
	end generate;
	
	gen_elim_on_down: if not FILTER_ON_UP generate
		output_valid <= '1' when synced_valid = '1' and synced_flag = "1" else '0';
		synced_ready <= '1' when output_ready = '1' or (synced_valid = '1' and synced_flag = "0") else '0';
	end generate;
		
	output_data <= synced_data;

end Behavioral;
