library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.JypecConstants.all;

entity TablaContexto is
	port(
		clk, rst, clk_en: in std_logic;
		in_contexto_read : in context_t;
		in_contexto_write : in context_t;
		in_info_estado : in info_mem_contexto_t;
		in_read : in std_logic;
		in_write : in std_logic;
		out_info_estado : out info_mem_contexto_t
	);
end TablaContexto;

architecture Behavioral of TablaContexto is

	type array_estado_table_t is array(0 to 18) of info_mem_contexto_t;
	signal table : array_estado_table_t;
	
begin

	memory: process(clk, rst, clk_en) 
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				for i in 0 to 18 loop
					table(i).prediction <= STATE_TABLE_DEFAULT(i).prediction;
					table(i).P_ESTIMATE <= P_ESTIMATE(STATE_TABLE_DEFAULT(i).state);
					table(i).SIGMA_MPS <= SIGMA_MPS(STATE_TABLE_DEFAULT(i).state);
					table(i).SIGMA_LPS <= SIGMA_LPS(STATE_TABLE_DEFAULT(i).state);
					table(i).X_S <= X_S(STATE_TABLE_DEFAULT(i).state);
					table(i).SHIFTED_P_ESTIMATE <= SHIFTED_P_ESTIMATE(STATE_TABLE_DEFAULT(i).state);
					table(i).P_ESTIMATE_SHIFT <=	P_ESTIMATE_SHIFT(STATE_TABLE_DEFAULT(i).state);			
				end loop;
			elsif (clk_en = '1') then
				if (in_write = '1') then
					table(in_contexto_write) <= in_info_estado;
				end if;
				if (in_read = '1') then
					if (in_contexto_read = in_contexto_write and in_write = '1') then
						out_info_estado <= in_info_estado;
					else
						out_info_estado <= table(in_contexto_read);
					end if;
				end if;									
			end if;
		end if;
	end process;

end Behavioral;