----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11.02.2019 11:29:41
-- Design Name: 
-- Module Name: kjcalc_axi - Behavioral
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

entity KJCALC_AXI is
	Generic (
		J_WIDTH: integer := 6;
		DATA_WIDTH: integer := 16
	);
	Port (
		clk, rst: in std_logic;
		rj: in std_logic_vector(DATA_WIDTH + J_WIDTH - 1 downto 0);
		j: in std_logic_vector(J_WIDTH - 1 downto 0);
		input_valid: in std_logic;
		input_ready: out std_logic;
		kj: out std_logic_vector(J_WIDTH - 2 downto 0);
		output_valid: out std_logic;
		output_ready: in std_logic
	);
end KJCALC_AXI;

architecture Behavioral of KJCALC_AXI is
	signal input_ready_local: std_logic;
		
	signal rj_shifted: std_logic_vector(DATA_WIDTH + J_WIDTH - 1 downto 0);
	signal middle_busy: std_logic;
	signal rj_shifted_latch: std_logic_vector(DATA_WIDTH + J_WIDTH - 1 downto 0);
	
	signal output_busy: std_logic;
	signal output_kj      : std_logic_vector(J_WIDTH - 2 downto 0);
	signal output_kj_latch: std_logic_vector(J_WIDTH - 2 downto 0);
begin

	kj <= output_kj_latch;
	
	input_ready_local <= '1' when middle_busy = '0' or output_busy = '0' or output_ready = '1' 
						 else '0';
	input_ready <= input_ready_local;			
	
	output_valid <= output_busy;	
	

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				middle_busy <= '0';
				output_busy <= '0';
				rj_shifted_latch <= (others => '0');
				output_kj_latch <= (others => '0');
			else
				--control new inputs via AXI in port
				if input_ready_local = '1' and input_valid = '1' then
					middle_busy <= '1';
					rj_shifted_latch <= rj_shifted;
				end if;
				--control outputs via AXI out port
				if output_busy = '0' or output_ready = '1' then
					output_busy <= middle_busy;
					output_kj_latch <= output_kj;
				end if;
			end if;
		end if;
	end process;


	calc_rj_shift: process(rj, j) 
		variable rj_shifted_tmp: std_logic_vector(DATA_WIDTH + J_WIDTH - 1 downto 0);
	begin
		rj_shifted_tmp := (others => '0');
		for i in J_WIDTH - 1 downto 0 loop
			if j(i) = '1' then
				rj_shifted_tmp := (i downto 0 => '0') & rj(DATA_WIDTH + J_WIDTH - 1 downto i + 1);
				exit;
			end if;
		end loop;
		
		rj_shifted <= rj_shifted_tmp;
	end process;
	
	calc_kj: process(rj_shifted_latch)
		variable kj_tmp: std_logic_vector(J_WIDTH - 2 downto 0);
	begin
		kj_tmp := (others => '0');
		for i in DATA_WIDTH + J_WIDTH - 2 downto 0 loop
			if rj_shifted_latch(i) = '1' then
				kj_tmp := std_logic_vector(to_unsigned(i+2, J_WIDTH - 1));
				exit;
			end if;
		end loop;
		
		output_kj <= kj_tmp;
	end process;



end Behavioral;
