----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11.02.2019 10:22:12
-- Design Name: 
-- Module Name: kjcalc - Behavioral
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

entity KJCALC is
	Generic (
		J_WIDTH: integer := 6;
		DATA_WIDTH: integer := 16
	);
	Port (
		rj: in std_logic_vector(DATA_WIDTH + J_WIDTH - 1 downto 0);
		j: in std_logic_vector(J_WIDTH - 1 downto 0);
		kj: out std_logic_vector(J_WIDTH - 2 downto 0)
	);
end KJCALC;


architecture Behavioral of KJCALC is
	signal rj_shifted: std_logic_vector(DATA_WIDTH + J_WIDTH - 1 downto 0);
begin

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
	
	calc_kj: process(rj_shifted)
		variable kj_tmp: std_logic_vector(J_WIDTH - 2 downto 0);
	begin
		kj_tmp := (others => '0');
		for i in DATA_WIDTH + J_WIDTH - 2 downto 0 loop
			if rj_shifted(i) = '1' then
				kj_tmp := std_logic_vector(to_unsigned(i+2, J_WIDTH - 1));
				exit;
			end if;
		end loop;
		
		kj <= kj_tmp;
	end process;



end Behavioral;

--architecture Behavioral of KJCALC is
--	signal adj_rj: std_logic_vector(DATA_WIDTH + J_WIDTH - 1 + (J_WIDTH - 1) + 1 downto 0);
--begin

	
--	adj_rj <= (J_WIDTH - 2 downto 0 => '0') & rj & '0';

--	calculate: process(rj, j)
--		variable tmp: std_logic_vector(J_WIDTH - 2 downto 0);
--	begin
--		tmp := (others => '0');
--		for i in 0 to DATA_WIDTH + J_WIDTH loop
--			if unsigned((DATA_WIDTH + J_WIDTH - 2 downto 0 => '0') & J & (i downto 0 => '0')) <= unsigned(rj) then 
--				tmp := std_logic_vector(to_unsigned(i, tmp'length));
--				exit;
--			end if;
--		end loop;
		
--		kj <= tmp;
--	end process;


--end Behavioral;
