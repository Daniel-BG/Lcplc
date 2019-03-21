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
use IEEE.NUMERIC_STD.ALL;
use work.functions.all;
use work.constants.all;

entity KJCALC_AXI is
	Generic (
		EXTRA_RJ_WIDTH: integer := 5;
		J_WIDTH: integer := 6;
		DATA_WIDTH: integer := 16
	);
	Port (
		clk, rst 	: in  std_logic;
		input_rj	: in  std_logic_vector(DATA_WIDTH + EXTRA_RJ_WIDTH - 1 downto 0);
		input_j 	: in  std_logic_vector(J_WIDTH - 1 downto 0);
		input_valid	: in  std_logic;
		input_ready : out std_logic;
		output_kj 	: out std_logic_vector(bits(EXTRA_RJ_WIDTH+DATA_WIDTH) - 1 downto 0);
		output_valid: out std_logic;
		output_ready: in  std_logic
	);
end KJCALC_AXI;

architecture Behavioral of KJCALC_AXI is
	constant OUT_WIDTH: integer := bits(EXTRA_RJ_WIDTH+DATA_WIDTH);

	signal input_ready_local: std_logic;
		
	signal rj_shifted: std_logic_vector(DATA_WIDTH + EXTRA_RJ_WIDTH - 1 downto 0);
	signal middle_busy: std_logic;
	signal rj_shifted_latch: std_logic_vector(DATA_WIDTH + EXTRA_RJ_WIDTH - 1 downto 0);
	attribute KEEP of rj_shifted_latch: signal is KEEP_DEFAULT;
	
	signal output_busy: std_logic;
	signal output_kj_pre  : std_logic_vector(OUT_WIDTH - 1 downto 0);
	signal output_kj_latch: std_logic_vector(OUT_WIDTH - 1 downto 0);
begin

	output_kj <= output_kj_latch;
	
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
				--inputting and outputting
				if input_ready_local = '1' and input_valid = '1' and output_busy = '1' and output_ready = '1' then
					middle_busy <= '1';
					rj_shifted_latch <= rj_shifted;
					output_busy <= middle_busy;
					output_kj_latch <= output_kj_pre;
				--control new inputs via AXI in port
				elsif input_ready_local = '1' and input_valid = '1' then
					middle_busy <= '1';
					rj_shifted_latch <= rj_shifted;
					if middle_busy = '1' then
						output_busy <= middle_busy;
						output_kj_latch <= output_kj_pre;
					end if;
				--control outputs via AXI out port
				elsif output_busy = '1' or output_ready = '1' then
					output_busy <= middle_busy;
					output_kj_latch <= output_kj_pre;
					middle_busy <= '0';
				end if;
			end if;
		end if;
	end process;


	calc_rj_shift: process(input_rj, input_j) 
		variable rj_shifted_tmp: std_logic_vector(DATA_WIDTH + EXTRA_RJ_WIDTH - 1 downto 0);
	begin
		rj_shifted_tmp := (others => '0');
		for i in J_WIDTH-1 downto 0 loop
			if input_j(i) = '1' then
				rj_shifted_tmp := (i - 1 downto 0 => '0') & input_rj(DATA_WIDTH + EXTRA_RJ_WIDTH - 1 downto i);
				exit;
			end if;
		end loop;
		
		rj_shifted <= rj_shifted_tmp;
	end process;
	
	calc_kj: process(rj_shifted_latch)
		variable kj_tmp: std_logic_vector(OUT_WIDTH - 1 downto 0);
	begin
		kj_tmp := std_logic_vector(to_unsigned(1, OUT_WIDTH));
		for i in DATA_WIDTH + EXTRA_RJ_WIDTH - 1 downto 0 loop
			if rj_shifted_latch(i) = '1' then
				kj_tmp := std_logic_vector(to_unsigned(i+1, OUT_WIDTH));
				exit;
			end if;
		end loop;
		
		output_kj_pre <= kj_tmp;
	end process;



end Behavioral;
