library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.JypecConstants.all;

entity MQCoder_fast is
	port(
		--control signals
		clk, rst, clk_en: in std_logic;
		--bit to code
		in_bit: in std_logic;
		--flag to end coding and output remaining bits
		end_coding_enable: in std_logic;
		--context with which this is coding
		in_context: in context_label_t;
		--while coding two bytes suffice, but with 3 we can do the final cleanup in one cycle
		out_bytes: out std_logic_vector(15 downto 0);
		--individually enable first, second and third byte. 
		--By design out_en(2) implies out_en(1) implies out_en(0)	
		out_enable: out std_logic_vector(1 downto 0)
	);
end MQCoder_fast;

architecture Behavioral of MQCoder_fast is
	
	-- memoria contexto
	signal mem_contexto_contexto_read : context_t;
	signal mem_contexto_contexto_write : context_t;
	signal mem_contexto_in : info_mem_contexto_t;
	signal mem_contexto_read : std_logic;
	signal mem_contexto_write : std_logic;
	signal mem_contexto_out : info_mem_contexto_t;
	signal mem_contexto_clk_en : std_logic;
	
	-- memoria estado	
	signal mem_estado_read: state_t;
	signal mem_estado_out : info_mem_estado_t;
	
	-- A
	signal normalized_interval_length : unsigned(15 downto 0);
	signal next_normalized_interval_length : unsigned(15 downto 0);
	signal final_normalized_interval_length : unsigned(15 downto 0);
	
	-- C
	signal normalized_lower_bound : unsigned(27+16+8-1 downto 0);
	signal next_normalized_lower_bound : unsigned(27+16+8-1 downto 0);
	signal final_normalized_lower_bound : unsigned(27+16+8-1 downto 0);
	
	signal acierto_pred_ajustada : std_logic;
	signal acierto_pred_ajustada_retardada : std_logic;
	signal acierto_pred_original : std_logic;
	signal contexto_segunda_etapa : context_label_t;
	signal contexto_tercera_etapa : context_label_t;
	signal info_a_manejar : info_mem_contexto_t;
	signal prediccion : std_logic;
	signal next_prediccion : std_logic;
	signal prediccion_ajustada : std_logic;
	
	signal num_shifts : unsigned(3 downto 0);
	signal num_shifts_retardada : unsigned(3 downto 0);
	signal num_shifts_retardada_retardada : unsigned(3 downto 0);	
	
	signal t : unsigned(4+1 downto 0);
	signal next_t : unsigned(4+1 downto 0);
	signal t_menos_num_shifts : unsigned(5+1 downto 0);	
	
	signal clk_en_segunda_etapa : std_logic;
	signal clk_en_tercera_etapa : std_logic;
	signal clk_en_cuarta_etapa : std_logic;
	signal in_bit_retardado : std_logic;
	
	signal out_bytes_interna : std_logic_vector(15 downto 0);
	signal out_enable_interna : std_logic_vector(1 downto 0);
	
	signal ultimo_byte_enviado_FF : std_logic;
	
	signal end_coding_enable_segunda_etapa : std_logic;
	signal end_coding_enable_tercera_etapa : std_logic;
	signal end_coding_enable_cuarta_etapa : std_logic;
	signal end_coding_enable_quinta_etapa : std_logic;
	
	signal prob_retardada : probability_t;
		
begin


	mem_contexto: entity work.TablaContexto
		port map (
			clk => clk, 
			rst => rst, 
			clk_en => mem_contexto_clk_en,
			in_contexto_read => mem_contexto_contexto_read,
			in_contexto_write => mem_contexto_contexto_write,
			in_info_estado => mem_contexto_in,
			in_read => mem_contexto_read,
			in_write => mem_contexto_write,
			out_info_estado => mem_contexto_out
		);
	mem_contexto_clk_en <= clk_en or clk_en_tercera_etapa;
	mem_contexto_read <= clk_en;
	mem_contexto_contexto_read <= in_context;
	mem_contexto_contexto_write <= contexto_tercera_etapa;
	mem_contexto_in.P_ESTIMATE <= mem_estado_out.P_ESTIMATE;
	mem_contexto_in.SIGMA_MPS <= mem_estado_out.SIGMA_MPS;
	mem_contexto_in.SIGMA_LPS <= mem_estado_out.SIGMA_LPS;
	mem_contexto_in.X_S <= mem_estado_out.X_S;
	mem_contexto_in.SHIFTED_P_ESTIMATE <= mem_estado_out.SHIFTED_P_ESTIMATE;
	mem_contexto_in.P_ESTIMATE_SHIFT <= mem_estado_out.P_ESTIMATE_SHIFT;
	next_prediccion <= not info_a_manejar.prediction when (next_normalized_interval_length(15) = '0' and acierto_pred_original = '0' and info_a_manejar.X_S = '1') else info_a_manejar.prediction;
	mem_contexto_in.prediction <= prediccion;

	
	mem_estado: entity work.TablaEstados
		port map (
			clk => clk, 
			rst => rst, 
			clk_en => clk_en_segunda_etapa,
			in_estado => mem_estado_read,
			out_info_estado => mem_estado_out
		);
	mem_estado_read <= info_a_manejar.SIGMA_MPS when (acierto_pred_original = '1') else info_a_manejar.SIGMA_LPS;

	info_a_manejar.prediction <= prediccion when (contexto_segunda_etapa = contexto_tercera_etapa and mem_contexto_write = '1') else mem_contexto_out.prediction;
	info_a_manejar.P_ESTIMATE <= mem_estado_out.P_ESTIMATE when (contexto_segunda_etapa = contexto_tercera_etapa and mem_contexto_write = '1') else mem_contexto_out.P_ESTIMATE;
	info_a_manejar.SIGMA_MPS <= mem_estado_out.SIGMA_MPS when (contexto_segunda_etapa = contexto_tercera_etapa and mem_contexto_write = '1') else mem_contexto_out.SIGMA_MPS;
	info_a_manejar.SIGMA_LPS <= mem_estado_out.SIGMA_LPS when (contexto_segunda_etapa = contexto_tercera_etapa and mem_contexto_write = '1') else mem_contexto_out.SIGMA_LPS;
	info_a_manejar.X_S <= mem_estado_out.X_S when (contexto_segunda_etapa = contexto_tercera_etapa and mem_contexto_write = '1') else mem_contexto_out.X_S;
	info_a_manejar.SHIFTED_P_ESTIMATE <= mem_estado_out.SHIFTED_P_ESTIMATE when (contexto_segunda_etapa = contexto_tercera_etapa and mem_contexto_write = '1') else mem_contexto_out.SHIFTED_P_ESTIMATE;
	info_a_manejar.P_ESTIMATE_SHIFT <= mem_estado_out.P_ESTIMATE_SHIFT when (contexto_segunda_etapa = contexto_tercera_etapa and mem_contexto_write = '1') else mem_contexto_out.P_ESTIMATE_SHIFT;


	prediccion_ajustada <= not info_a_manejar.prediction when (normalized_interval_length < 2*info_a_manejar.P_ESTIMATE) else info_a_manejar.prediction;
	acierto_pred_ajustada <= '1' when (in_bit_retardado = prediccion_ajustada) else '0';
	acierto_pred_original <= '1' when (in_bit_retardado = info_a_manejar.prediction) else '0';


	valores_A_C_sync : process(clk, rst, clk_en_segunda_etapa, clk_en_tercera_etapa)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				normalized_interval_length <= to_unsigned(32768, 16);
				normalized_lower_bound <= (others => '0');
				prob_retardada <= 0;
				acierto_pred_ajustada_retardada <= '0';
			else
				if (clk_en_segunda_etapa = '1') then
					normalized_interval_length <= final_normalized_interval_length;
					prob_retardada <= info_a_manejar.P_ESTIMATE;
					acierto_pred_ajustada_retardada <= acierto_pred_ajustada;
	--				normalized_lower_bound <= final_normalized_lower_bound;
				end if;
				if (clk_en_tercera_etapa = '1') then
					normalized_lower_bound <= final_normalized_lower_bound;
				end if;
			end if;
		end if;
	end process;
	
--	valores_A_C_comb : process(acierto_pred_ajustada, info_a_manejar.P_ESTIMATE, normalized_lower_bound, normalized_interval_length)
--	begin
--		next_normalized_lower_bound <= normalized_lower_bound;
--		next_normalized_interval_length <= normalized_interval_length;
--		if (acierto_pred_ajustada = '1') then
--			next_normalized_lower_bound <= normalized_lower_bound + info_a_manejar.P_ESTIMATE;
--			next_normalized_interval_length <= normalized_interval_length - info_a_manejar.P_ESTIMATE;
--		else
--			next_normalized_interval_length <= to_unsigned(info_a_manejar.P_ESTIMATE, 16);
--		end if;
--	end process;

--next_normalized_lower_bound <= normalized_lower_bound + info_a_manejar.P_ESTIMATE when (acierto_pred_ajustada = '1') else normalized_lower_bound;
next_normalized_lower_bound <= normalized_lower_bound + prob_retardada when (acierto_pred_ajustada_retardada = '1') else normalized_lower_bound;
next_normalized_interval_length <= normalized_interval_length - info_a_manejar.P_ESTIMATE when (acierto_pred_ajustada = '1') else to_unsigned(info_a_manejar.P_ESTIMATE, 16);

	general : process(clk, clk_en_segunda_etapa, rst)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				mem_contexto_write <= '0';
				prediccion <= '0';
			elsif (clk_en_segunda_etapa = '1') then				
				prediccion <= next_prediccion;
				mem_contexto_write <= not next_normalized_interval_length(15);
			else
				mem_contexto_write <= '0';
			end if;
		end if;
	end process;

	retardos_etapas : process(clk, clk_en, rst)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				clk_en_segunda_etapa <= '0';
				clk_en_tercera_etapa <= '0';
				clk_en_cuarta_etapa <= '0';
				in_bit_retardado <= '0';
				contexto_segunda_etapa <= CONTEXT_ZERO;
				contexto_tercera_etapa <= CONTEXT_ONE;
				num_shifts_retardada <= (others=>'0');
				num_shifts_retardada_retardada <= (others=>'0');
				end_coding_enable_segunda_etapa <= '0';
				end_coding_enable_tercera_etapa <= '0';
				end_coding_enable_cuarta_etapa <= '0';
				end_coding_enable_quinta_etapa <= '0';
			else
				clk_en_segunda_etapa <= clk_en;
				clk_en_tercera_etapa <= clk_en_segunda_etapa;
				clk_en_cuarta_etapa <= clk_en_tercera_etapa;
				in_bit_retardado <= in_bit;
				contexto_segunda_etapa <= in_context;
				contexto_tercera_etapa <= contexto_segunda_etapa;
				num_shifts_retardada <= num_shifts;
				num_shifts_retardada_retardada <= num_shifts_retardada;				
				end_coding_enable_segunda_etapa <= end_coding_enable;
				end_coding_enable_tercera_etapa <= end_coding_enable_segunda_etapa;
				end_coding_enable_cuarta_etapa <= end_coding_enable_tercera_etapa;
				end_coding_enable_quinta_etapa <= end_coding_enable_cuarta_etapa;
			end if;
		end if;
	end process;

	num_shifts <=  "0000" when (next_normalized_interval_length(15) = '1' and acierto_pred_ajustada = '1') else
						"0001" when (next_normalized_interval_length(14) = '1' and acierto_pred_ajustada = '1') else
						--"0010" when (next_normalized_interval_length(13) = '1' and acierto_pred_ajustada = '1') else
						"0010" when (acierto_pred_ajustada = '1') else
						to_unsigned(info_a_manejar.P_ESTIMATE_SHIFT, 4);
						
	final_normalized_interval_length <= 	next_normalized_interval_length when (num_shifts = "0000" and acierto_pred_ajustada = '1') else
												next_normalized_interval_length(14 downto 0)&"0" when (num_shifts = "0001" and acierto_pred_ajustada = '1') else
												next_normalized_interval_length(13 downto 0)&"00" when (num_shifts = "0010" and acierto_pred_ajustada = '1') else
												to_unsigned(info_a_manejar.SHIFTED_P_ESTIMATE, 16);
						
	final_normalized_lower_bound <= 	next_normalized_lower_bound when num_shifts_retardada = "0000" else
												next_normalized_lower_bound(26+16+8-1 downto 0)&"0" when num_shifts_retardada = "0001" else
												next_normalized_lower_bound(25+16+8-1 downto 0)&"00" when num_shifts_retardada = "0010" else
												next_normalized_lower_bound(24+16+8-1 downto 0)&"000" when num_shifts_retardada = "0011" else
												next_normalized_lower_bound(23+16+8-1 downto 0)&"0000" when num_shifts_retardada = "0100" else
												next_normalized_lower_bound(22+16+8-1 downto 0)&"00000" when num_shifts_retardada = "0101" else
												next_normalized_lower_bound(21+16+8-1 downto 0)&"000000" when num_shifts_retardada = "0110" else
												next_normalized_lower_bound(20+16+8-1 downto 0)&"0000000" when num_shifts_retardada = "0111" else
												next_normalized_lower_bound(19+16+8-1 downto 0)&"00000000" when num_shifts_retardada = "1000" else
												next_normalized_lower_bound(18+16+8-1 downto 0)&"000000000" when num_shifts_retardada = "1001" else
												next_normalized_lower_bound(17+16+8-1 downto 0)&"0000000000" when num_shifts_retardada = "1010" else
												next_normalized_lower_bound(16+16+8-1 downto 0)&"00000000000" when num_shifts_retardada = "1011" else
												next_normalized_lower_bound(15+16+8-1 downto 0)&"000000000000" when num_shifts_retardada = "1100" else
												next_normalized_lower_bound(14+16+8-1 downto 0)&"0000000000000" when num_shifts_retardada = "1101" else
												next_normalized_lower_bound(13+16+8-1 downto 0)&"00000000000000" when num_shifts_retardada = "1110" else
												next_normalized_lower_bound(12+16+8-1 downto 0)&"000000000000000";-- when num_shifts = "1111";

												

	
	-- la salida como una tercera etapa y 'end_coding_enable' como cuarta
	
	t_menos_num_shifts(4+1 downto 0) <= t - num_shifts_retardada_retardada when (end_coding_enable_quinta_etapa = '0') else t;		
	t_menos_num_shifts(5+1) <= '0';

	next_t <= 	t_menos_num_shifts(4+1 downto 0) + 8 when (t_menos_num_shifts > 8 and t_menos_num_shifts <= 16 and ultimo_byte_enviado_FF = '0') else 
					t_menos_num_shifts(4+1 downto 0) + 7 when (t_menos_num_shifts > 8 and t_menos_num_shifts <= 16 and ultimo_byte_enviado_FF = '1') else 
					t_menos_num_shifts(4+1 downto 0) + 16 when (t_menos_num_shifts <= 8 and normalized_lower_bound(27+16+8-1-to_integer(t_menos_num_shifts) downto 27+16+8-1-to_integer(t_menos_num_shifts)-8+1) /= "11111111") else 
					t_menos_num_shifts(4+1 downto 0) + 15 when (t_menos_num_shifts <= 8 and normalized_lower_bound(27+16+8-1-to_integer(t_menos_num_shifts) downto 27+16+8-1-to_integer(t_menos_num_shifts)-8+1) = "11111111") else
					t_menos_num_shifts(4+1 downto 0);

	out_bytes_interna(7 downto 0) <= 	(others=>'0') when (t_menos_num_shifts > 16 and end_coding_enable_quinta_etapa = '0') else
										std_logic_vector("0"&normalized_lower_bound(27+16+8-1-to_integer(t_menos_num_shifts) downto 27+16+8-1-to_integer(t_menos_num_shifts)-8+2)) when (ultimo_byte_enviado_FF = '1') else 
										std_logic_vector(normalized_lower_bound(27+16+8-1-to_integer(t_menos_num_shifts) downto 27+16+8-1-to_integer(t_menos_num_shifts)-8+1));
	
	out_bytes_interna(15 downto 8) <= 	(others=>'0') when (t_menos_num_shifts > 8 and end_coding_enable_quinta_etapa = '0') else
										std_logic_vector(normalized_lower_bound(27+16+8-1-to_integer(t_menos_num_shifts)-8+1 downto 27+16+8-1-to_integer(t_menos_num_shifts)-16+1+1)) when (ultimo_byte_enviado_FF = '1') else 
										std_logic_vector("0"&normalized_lower_bound(27+16+8-1-to_integer(t_menos_num_shifts)-8 downto 27+16+8-1-to_integer(t_menos_num_shifts)-16+2)) when (normalized_lower_bound(27+16+8-1-to_integer(t_menos_num_shifts) downto 27+16+8-1-to_integer(t_menos_num_shifts)-8+1) = "11111111") else 
										std_logic_vector(normalized_lower_bound(27+16+8-1-to_integer(t_menos_num_shifts)-8 downto 27+16+8-1-to_integer(t_menos_num_shifts)-16+1));			


	out_enable_interna(0) <= '1' when (end_coding_enable_quinta_etapa = '1' or (t_menos_num_shifts <= 16 and clk_en_cuarta_etapa = '1')) else '0';	
	out_enable_interna(1) <= '1' when (end_coding_enable_quinta_etapa = '1' or (t_menos_num_shifts <= 8 and clk_en_cuarta_etapa = '1')) else '0';	
	
	out_bytes(15 downto 8) <= out_bytes_interna(7 downto 0) when (out_enable_interna(1) = '1') else (others=>'0');
	out_bytes(7 downto 0) <= out_bytes_interna(7 downto 0) when (out_enable_interna(1) = '0') else out_bytes_interna(15 downto 8);
	out_enable <= out_enable_interna;
	
	-- comprobar que el último byte enviado fue 0xFF
	senales_envio : process(clk)--, clk_en_tercera_etapa, rst)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				t <= to_unsigned(12+16+8,5+1);
				ultimo_byte_enviado_FF <= '0';
			elsif (clk_en_cuarta_etapa = '1') then 
				if ((out_enable_interna(1) = '1' and out_bytes_interna(15 downto 8) = "11111111") or (out_enable_interna(1) = '0' and out_enable_interna(0) = '1' and out_bytes_interna(7 downto 0) = "11111111") ) then
					ultimo_byte_enviado_FF <= '1';
				elsif (out_enable_interna(0) = '1') then
					ultimo_byte_enviado_FF <= '0';
				end if;
				t <= next_t;
			end if;
		end if;
	end process;
	
	
end Behavioral;
