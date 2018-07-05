library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.JypecConstants.all;

entity TablaEstados is
	port(
		clk, rst, clk_en: in std_logic;
		in_estado: in state_t;
		out_info_estado : out info_mem_estado_t
	);
end TablaEstados;

architecture Behavioral of TablaEstados is

	type array_estado_table_t is array(0 to 46) of info_mem_estado_t;
	signal table : array_estado_table_t;

	
begin

	memory: process(clk, rst, clk_en) 
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				for i in 0 to 46 loop
					table(i).P_ESTIMATE <=	P_ESTIMATE(i);
					table(i).SIGMA_MPS <= SIGMA_MPS(i);
					table(i).SIGMA_LPS <= SIGMA_LPS(i);
					table(i).X_S <= X_S(i);
					table(i).SHIFTED_P_ESTIMATE <= SHIFTED_P_ESTIMATE(i);
					table(i).P_ESTIMATE_SHIFT <=	P_ESTIMATE_SHIFT(i);			
				end loop;
			end if;
			if  (clk_en = '1') then
				out_info_estado <= table(in_estado);
			end if;
		end if;
	end process;

end Behavioral;