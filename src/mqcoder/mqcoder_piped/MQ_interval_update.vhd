----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:38:19 07/02/2018 
-- Design Name: 
-- Module Name:    MQ_interval_update - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
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
use work.JypecConstants.all;

entity MQ_interval_update is
	port(
		--control signals
		clk, rst, clk_en: in std_logic;
		--bit to code
		in_bit: in std_logic;
		--context with which this is coding
		in_context: in context_label_t;
		--outputs for the bound update
		out_hit: out std_logic;
		out_prob: out unsigned(15 downto 0);
		out_shift: out unsigned(3 downto 0);
		out_enable: out std_logic
	);
end MQ_interval_update;


architecture Behavioral of MQ_interval_update is
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
	signal normalized_lower_bound : unsigned(27 downto 0);
	signal next_normalized_lower_bound : unsigned(27 downto 0);
	signal next_normalized_lower_bound_shifted : unsigned(27 downto 0);
	
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
	
	signal clk_en_segunda_etapa, clk_en_tercera_etapa: std_logic;
	signal in_bit_retardado : std_logic;
	
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
				prob_retardada <= 0;
				acierto_pred_ajustada_retardada <= '0';
			else
				if (clk_en_segunda_etapa = '1') then
					normalized_interval_length <= final_normalized_interval_length;
					prob_retardada <= info_a_manejar.P_ESTIMATE;
					acierto_pred_ajustada_retardada <= acierto_pred_ajustada;
				end if;
			end if;
		end if;
	end process;
	


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
				in_bit_retardado <= '0';
				contexto_segunda_etapa <= CONTEXT_ZERO;
				contexto_tercera_etapa <= CONTEXT_ONE;
				num_shifts_retardada <= (others=>'0');
			else
				clk_en_segunda_etapa <= clk_en;
				clk_en_tercera_etapa <= clk_en_segunda_etapa;
				in_bit_retardado <= in_bit;
				contexto_segunda_etapa <= in_context;
				contexto_tercera_etapa <= contexto_segunda_etapa;
				num_shifts_retardada <= num_shifts;		
			end if;
		end if;
	end process;
	
	next_normalized_interval_length <= normalized_interval_length - info_a_manejar.P_ESTIMATE when (acierto_pred_ajustada = '1') else to_unsigned(info_a_manejar.P_ESTIMATE, 16);
	
	num_shifts <=  "0000" when (next_normalized_interval_length(15) = '1' and acierto_pred_ajustada = '1') else
						"0001" when (next_normalized_interval_length(14) = '1' and acierto_pred_ajustada = '1') else
						--"0010" when (next_normalized_interval_length(13) = '1' and acierto_pred_ajustada = '1') else
						"0010" when (acierto_pred_ajustada = '1') else
						to_unsigned(info_a_manejar.P_ESTIMATE_SHIFT, 4);
						
	final_normalized_interval_length <= 	next_normalized_interval_length when (num_shifts = "0000" and acierto_pred_ajustada = '1') else
												next_normalized_interval_length(14 downto 0)&"0" when (num_shifts = "0001" and acierto_pred_ajustada = '1') else
												next_normalized_interval_length(13 downto 0)&"00" when (num_shifts = "0010" and acierto_pred_ajustada = '1') else
												to_unsigned(info_a_manejar.SHIFTED_P_ESTIMATE, 16);
						
						
	--data that goes to the fifo
	out_hit <= acierto_pred_ajustada_retardada;
	out_prob <= to_unsigned(prob_retardada, 16);
	out_shift <= num_shifts_retardada;
	out_enable <= clk_en_tercera_etapa;

	
end Behavioral;

