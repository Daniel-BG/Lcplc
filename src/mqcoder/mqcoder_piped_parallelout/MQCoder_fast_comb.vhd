library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.JypecConstants.all;

entity MQCoder_fast_comb is
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
		out_bytes: out std_logic_vector(23 downto 0);
		--individually enable first, second and third byte. 
		--By design out_en(2) implies out_en(1) implies out_en(0)	
		out_enable: out std_logic_vector(2 downto 0)
	);
end MQCoder_fast_comb;

architecture Behavioral of MQCoder_fast_comb is
	
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
	signal normalized_lower_bound_add, normalized_lower_bound_aligned : unsigned(27 downto 0);
	signal carry_deletion_mask: unsigned(27 downto 0);
	signal next_normalized_lower_bound : unsigned(27 downto 0);
	
	signal acierto_pred_ajustada : std_logic;
	signal acierto_pred_ajustada_retardada : std_logic;
	signal acierto_pred_original : std_logic;
	signal contexto_segunda_etapa : context_label_t;
	signal contexto_tercera_etapa : context_label_t;
	signal info_a_manejar : info_mem_contexto_t;
	signal prediccion : std_logic;
	signal next_prediccion : std_logic;
	signal prediccion_ajustada : std_logic;
	
	subtype number_of_shifts_t is natural range 0 to 15;
	signal num_shifts, num_shifts_retardada: number_of_shifts_t;
	

	
	signal clk_en_segunda_etapa : std_logic;
	signal clk_en_tercera_etapa : std_logic;
	signal in_bit_retardado : std_logic;
	
	signal ultimo_byte_enviado_FF : std_logic;
	
	signal end_coding_enable_segunda_etapa : std_logic;
	signal end_coding_enable_tercera_etapa : std_logic;
	
	signal prob_retardada : probability_t;
	
	
	--output signals
	signal temp_byte_buffer_carried: unsigned(7 downto 0);
	signal temp_byte_buffer, next_temp_byte_buffer: unsigned(7 downto 0);
	subtype countdown_timer_t is natural range 0 to 8;
	signal countdown_timer, next_countdown_timer: countdown_timer_t;
	signal first_carry_bit: std_logic;
	signal first_byte_case_ff, first_byte_case_ffnew, first_byte_case_noff, first_byte_carried, first_byte_output, first_byte: unsigned(7 downto 0);
	signal first_byte_ffnew_flag, first_byte_ff_flag, first_byte_output_enable, first_byte_7_flag, first_byte_active_flag: std_logic;
	
	signal second_byte_ff_flag: std_logic;
	signal second_carry_bit, second_7_carry_bit, second_8_carry_bit: std_logic;
	signal second_7_byte_case_ff, second_7_byte_case_ffnew, second_7_byte_case_noff, second_8_byte_case_ff, second_8_byte_case_ffnew, second_8_byte_case_noff, second_byte_case_ff, second_byte_case_ffnew, second_byte_case_noff, second_byte, second_byte_output: unsigned(7 downto 0);
	signal second_byte_ffnew_flag, second_byte_7_flag, second_byte_active_flag, second_byte_output_enable: std_logic;
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
				countdown_timer <= 4;
				temp_byte_buffer <= (others => '0');
			else
				if (clk_en_segunda_etapa = '1') then
					normalized_interval_length <= final_normalized_interval_length;
					prob_retardada <= info_a_manejar.P_ESTIMATE;
					acierto_pred_ajustada_retardada <= acierto_pred_ajustada;
	--				normalized_lower_bound <= final_normalized_lower_bound;
				end if;
				if (clk_en_tercera_etapa = '1') then
					normalized_lower_bound <= next_normalized_lower_bound;
					countdown_timer <= next_countdown_timer;
					temp_byte_buffer <= next_temp_byte_buffer;
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
normalized_lower_bound_add <= normalized_lower_bound + prob_retardada 
			when (acierto_pred_ajustada_retardada = '1' and end_coding_enable_tercera_etapa = '0') 
			else normalized_lower_bound;
--normalized_lower_bound_aligned <= shift_left(normalized_lower_bound_add, countdown_timer);
normalized_lower_bound_aligned <= normalized_lower_bound_add when countdown_timer = 0 else
							normalized_lower_bound_add(26 downto 0) & "0" when countdown_timer = 1 else
							normalized_lower_bound_add(25 downto 0) & "00" when countdown_timer = 2 else
							normalized_lower_bound_add(24 downto 0) & "000" when countdown_timer = 3 else
							normalized_lower_bound_add(23 downto 0) & "0000" when countdown_timer = 4 else
							normalized_lower_bound_add(22 downto 0) & "00000" when countdown_timer = 5 else
							normalized_lower_bound_add(21 downto 0) & "000000" when countdown_timer = 6 else
							normalized_lower_bound_add(20 downto 0) & "0000000" when countdown_timer = 7 else
							normalized_lower_bound_add(19 downto 0) & "00000000";
							
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
				in_bit_retardado <= '0';
				contexto_segunda_etapa <= CONTEXT_ZERO;
				contexto_tercera_etapa <= CONTEXT_ONE;
				num_shifts_retardada <= 0;
				end_coding_enable_segunda_etapa <= '0';
				end_coding_enable_tercera_etapa <= '0';
			else
				clk_en_segunda_etapa <= clk_en;
				clk_en_tercera_etapa <= clk_en_segunda_etapa;
				in_bit_retardado <= in_bit;
				contexto_segunda_etapa <= in_context;
				contexto_tercera_etapa <= contexto_segunda_etapa;
				num_shifts_retardada <= num_shifts;			
				end_coding_enable_segunda_etapa <= end_coding_enable;
				end_coding_enable_tercera_etapa <= end_coding_enable_segunda_etapa;
			end if;
		end if;
	end process;

	num_shifts <=  0 when (next_normalized_interval_length(15) = '1' and acierto_pred_ajustada = '1') else
						1 when (next_normalized_interval_length(14) = '1' and acierto_pred_ajustada = '1') else
						--"0010" when (next_normalized_interval_length(13) = '1' and acierto_pred_ajustada = '1') else
						2 when (acierto_pred_ajustada = '1') else
						info_a_manejar.P_ESTIMATE_SHIFT;
						
	final_normalized_interval_length <= 	next_normalized_interval_length when (num_shifts = 0 and acierto_pred_ajustada = '1') else
												next_normalized_interval_length(14 downto 0)&"0" when (num_shifts = 1 and acierto_pred_ajustada = '1') else
												next_normalized_interval_length(13 downto 0)&"00" when (num_shifts = 2 and acierto_pred_ajustada = '1') else
												to_unsigned(info_a_manejar.SHIFTED_P_ESTIMATE, 16);
						

	--output and final updates
	temp_byte_buffer_carried <= temp_byte_buffer + ("0000000" & first_carry_bit);
				
	--flags for the first byte		
	first_byte_active_flag <= '1' when countdown_timer <= num_shifts_retardada else '0';
	first_byte_ff_flag <= '1' when temp_byte_buffer = "11111111" else '0';
	first_byte_ffnew_flag <= '1' when temp_byte_buffer = "11111110" and first_carry_bit = '1' else '0';
	first_byte_7_flag <= '1' when first_byte_ff_flag = '1' or first_byte_ffnew_flag = '1' else '0';
	-------------------

	--carry bit and cases for the first byte
	first_carry_bit <= normalized_lower_bound_aligned(27);

	first_byte_case_ff <= normalized_lower_bound_aligned(27 downto 20);
	first_byte_case_ffnew <= "0" & normalized_lower_bound_aligned(26 downto 20);
	first_byte_case_noff <= normalized_lower_bound_aligned(26 downto 19);

	first_byte <=	first_byte_case_ff when first_byte_ff_flag = '1' else
					first_byte_case_ffnew when first_byte_ffnew_flag = '1' else
					first_byte_case_noff;
	-------------------
	
	first_byte_carried <= first_byte + ("0000000" & second_carry_bit);

	first_byte_output <= temp_byte_buffer when first_byte_ff_flag = '1' else temp_byte_buffer_carried;
	first_byte_output_enable <= first_byte_active_flag;


	--flags for the last byte
	second_byte_active_flag <= '1' when (first_byte_7_flag = '1' and num_shifts_retardada - countdown_timer >= 7) or
										(first_byte_7_flag = '0' and num_shifts_retardada - countdown_timer >= 8)
										else '0';
	second_byte_ff_flag <= '1' when first_byte_output = "11111111" else '0';
	second_byte_ffnew_flag <= '1' when first_byte_output = "11111110" and second_carry_bit = '1' else '0';
	second_byte_7_flag <= '1' when second_byte_ff_flag = '1' or second_byte_ffnew_flag = '1' else '0';
	-------------------

	--first option for the last byte
	second_7_carry_bit <= normalized_lower_bound_aligned(20);
	
	second_7_byte_case_ff <= normalized_lower_bound_aligned(20 downto 13);
	second_7_byte_case_ffnew <= "0" & normalized_lower_bound_aligned(19 downto 13);
	second_7_byte_case_noff <= normalized_lower_bound_aligned(19 downto 12);
	-------------------
	
	--second option for the last byte
	second_8_carry_bit <= normalized_lower_bound_aligned(19);
	
	second_8_byte_case_ff <= second_7_byte_case_noff;
	second_8_byte_case_ffnew <= "0" & normalized_lower_bound_aligned(18 downto 12);
	second_8_byte_case_noff <= normalized_lower_bound_aligned(18 downto 11);
	-------------------

	--last byte muxes
	second_carry_bit 		<= second_7_carry_bit when first_byte_7_flag = '1' else second_8_carry_bit;
	second_byte_case_ff 	<= second_7_byte_case_ff when first_byte_7_flag = '1' else second_8_byte_case_ff;
	second_byte_case_ffnew	<= second_7_byte_case_ffnew when first_byte_7_flag = '1' else second_8_byte_case_ffnew;
	second_byte_case_noff	<= second_7_byte_case_noff when first_byte_7_flag = '1' else second_8_byte_case_noff;

	second_byte <=	second_byte_case_ff when second_byte_ff_flag = '1' else
					second_byte_case_ffnew when second_byte_ffnew_flag = '1' else
					second_byte_case_noff;
	-------------------

	--second byte output control. the first is output since the second will be stored as temp_Byte_buffer
	second_byte_output <= first_byte when second_byte_ff_flag = '1' else first_byte_carried;
	second_byte_output_enable <= '1' when first_byte_active_flag = '1' and second_byte_active_flag = '1' else '0';
	-------------------

	--calculations for next cycle
	next_temp_byte_buffer <= temp_byte_buffer when first_byte_active_flag = '0' else
							 first_byte when second_byte_active_flag = '0' else
							 second_byte;
							 
							 
	carry_deletion_mask <= shift_right("1000000000000000000000000000", next_countdown_timer) 
									when first_byte_output_enable = '1' or second_byte_output_enable = '1' 
									else (others => '0');
									
	next_normalized_lower_bound <= shift_left(normalized_lower_bound_add, num_shifts_retardada)  and (not carry_deletion_mask);



	next_cd_timer_proc: process(first_byte_active_flag, second_byte_active_flag,first_byte_7_flag, second_byte_7_flag, countdown_timer, num_shifts_retardada)
	begin
		if (second_byte_active_flag = '1') then --in this case first is also active
			if (first_byte_7_flag = '1' and second_byte_7_flag = '1') then
				next_countdown_timer <= 14 + countdown_timer - num_shifts_retardada;
			elsif (first_byte_7_flag = '0' and second_byte_7_flag = '0') then
				next_countdown_timer <= 16 + countdown_timer - num_shifts_retardada;
			else
				next_countdown_timer <= 15 + countdown_timer - num_shifts_retardada;
			end if;
		elsif (first_byte_active_flag = '1') then
			if (first_byte_7_flag = '1') then
				next_countdown_timer <= 7 + countdown_timer - num_shifts_retardada;
			else
				next_countdown_timer <= 8 + countdown_timer - num_shifts_retardada;
			end if;
		else
			next_countdown_timer <= countdown_timer - num_shifts_retardada;
		end if;

		
	end process;

	
	--connect outputs
	output: process(clk, clk_en_tercera_etapa) 
	begin
		if (rising_edge(clk)) then
			out_bytes(23 downto 16) <= std_logic_vector(first_byte_output);
			out_bytes(15 downto 8) <= std_logic_vector(second_byte_output);
			out_bytes(7 downto 0) <= std_logic_vector(next_temp_byte_buffer);
			if (clk_en_tercera_etapa = '1') then
				if (end_coding_enable_tercera_etapa = '1') then
					out_enable(2) <= '1';
					out_enable(1) <= '1';
					if ((first_byte_7_flag = '1' and countdown_timer >= 5) or (first_byte_7_flag = '0' and countdown_timer >= 4)) then
						out_enable(0) <= '0';
					else
						out_enable(0) <= '1';
					end if;
				else
					out_enable(2) <= first_byte_output_enable;
					out_enable(1) <= second_byte_output_enable;	
					out_enable(0) <= '0';
				end if;
			else
				out_enable(2) <= '0';
				out_enable(1) <= '0';
				out_enable(0) <= '0';
			end if;
		end if;
	end process;
	

	
	
end Behavioral;
