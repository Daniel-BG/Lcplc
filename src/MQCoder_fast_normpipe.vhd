library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.JypecConstants.all;

entity MQCoder_fast_pipe is
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
		out_byte: out std_logic_vector(7 downto 0);
		--individually enable first, second and third byte. 
		--By design out_en(2) implies out_en(1) implies out_en(0)	
		out_enable: out std_logic
	);
end MQCoder_fast_pipe;

architecture Behavioral of MQCoder_fast_pipe is
	
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
	
	signal t : unsigned(4+1 downto 0);
	signal next_t : unsigned(4+1 downto 0);
	signal t_menos_num_shifts : unsigned(5+1 downto 0);	
	
	signal clk_en_segunda_etapa : std_logic;
	signal clk_en_tercera_etapa : std_logic;
	signal clk_en_cuarta_etapa : std_logic;
	signal in_bit_retardado : std_logic;
	
	signal ultimo_byte_enviado_FF : std_logic;
	
	signal end_coding_enable_segunda_etapa : std_logic;
	signal end_coding_enable_tercera_etapa : std_logic;
	signal end_coding_enable_cuarta_etapa : std_logic;
	signal end_coding_enable_quinta_etapa : std_logic;
	
	signal prob_retardada : probability_t;
	
	
	--FIFO STUFF
	signal fifonorm_wren, fifonorm_readen, fifonorm_empty, fifonorm_full: std_logic;
	signal fifonorm_in, fifonorm_out: std_logic_vector(16+1+1+4-1 downto 0);
	signal fifonorm_in_prob, fifonorm_out_prob: std_logic_vector(15 downto 0);
	signal fifonorm_in_hit, fifonorm_out_hit: std_logic;
	signal fifonorm_in_end, fifonorm_out_end: std_logic;
	signal fifonorm_in_shift, fifonorm_out_shift: std_logic_vector(3 downto 0);
		
	--AFTER FIFO STUFF
	signal clk_en_after_fifo: std_logic;
	
	subtype countdown_timer_t is natural range 0 to 12;
	signal countdown_timer, next_countdown_timer: countdown_timer_t;
	
	subtype number_of_shifts_t is natural range 0 to 15;
	signal number_of_shifts, next_number_of_shifts, shifts_to_perform: number_of_shifts_t;
	
	type outputter_state_t is (IDLE, VALUES_READ, ITERATE);
	signal output_state_curr, output_state_next: outputter_state_t;
	
	signal temp_byte_buffer, next_temp_byte_buffer: unsigned(7 downto 0);
	
	signal buffer_is_FF, buffer_becomes_FF: std_logic;
		
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
				clk_en_cuarta_etapa <= '0';
				in_bit_retardado <= '0';
				contexto_segunda_etapa <= CONTEXT_ZERO;
				contexto_tercera_etapa <= CONTEXT_ONE;
				num_shifts_retardada <= (others=>'0');
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
				end_coding_enable_segunda_etapa <= end_coding_enable;
				end_coding_enable_tercera_etapa <= end_coding_enable_segunda_etapa;
				end_coding_enable_cuarta_etapa <= end_coding_enable_tercera_etapa;
				end_coding_enable_quinta_etapa <= end_coding_enable_cuarta_etapa;
			end if;
		end if;
	end process;
	
	next_normalized_interval_length <= normalized_interval_length - info_a_manejar.P_ESTIMATE when (acierto_pred_ajustada = '1') else to_unsigned(info_a_manejar.P_ESTIMATE, 16);
	
	num_shifts <=  "0000" when (next_normalized_interval_length(15) = '1' and acierto_pred_ajustada = '1') else
						"0001" when (next_normalized_interval_length(14) = '1' and acierto_pred_ajustada = '1') else
						--"0010" when (next_normalized_interval_length(13) = '1' and acierto_pred_ajustada = '1') else
						"0010" when (acierto_pred_ajustada = '1') else
						to_unsigned(info_a_manejar.P_ESTIMATE_SHIFT, 4);
	
	--data that goes to the fifo
	fifonorm_in_end <= end_coding_enable_tercera_etapa;
	fifonorm_in_hit <= acierto_pred_ajustada_retardada;
	fifonorm_in_prob <= std_logic_vector(to_unsigned(prob_retardada, 16));
	fifonorm_in_shift <= std_logic_vector(num_shifts_retardada);
	fifonorm_in <= fifonorm_in_end & fifonorm_in_hit & fifonorm_in_prob & fifonorm_in_shift;
	--gets disabled if hit = 0 and shift = 0
	fifonorm_wren <= '1' when clk_en_tercera_etapa = '1' and (fifonorm_in_hit = '1' or fifonorm_in_shift /= '0') else '0';
	
	
	fifo_norm_int_len: entity work.STD_FIFO
		generic map (
			DATA_WIDTH => 16+1+1+4,
			FIFO_DEPTH => 32
		)
		port map (
			clk => clk,
			rst => rst,
			WriteEn => fifonorm_wren,
			DataIn => fifonorm_in,
			ReadEn => fifonorm_readen,
			DataOut => fifonorm_out,
			Empty => fifonorm_empty,
			Full => fifonorm_full
		);
		
	--aliases for fifonorm output
	fifonorm_out_end <= fifonorm_out(21);
	fifonorm_out_hit <= fifonorm_out(20);
	fifonorm_out_prob <= fifonorm_out(19 downto 4);
	fifonorm_out_shift <= fifonorm_out(3 downto 0);
	
	
	
	
	update_bounds: process(output_state_curr, fifonorm_empty, shifting_ending)
	
	begin
	
		output_state_next <= output_state_curr;
		fifonorm_readen <= '0';
	
		case output_state_curr is
			when IDLE => 
				if fifonorm_empty = '0' then
					output_state_next <= VALUES_READ;
					fifonorm_readen <= '1';
				end if;
			when VALUES_READ =>
				if shifting_ending = '1' then
					--in this case we can read the next value
					if fifonorm_empty = '0' then
						fifonorm_readen <= '1';
					else --nothing available, back to idle
						output_state_next <= IDLE;
					end if;
				else --still shifts to do, but from memory now
					output_state_next <= PIPELINE;
				end if;
			when PIPELINE =>
				if shifting_ending = '1' then
					--in this case we can read the next value
					if fifonorm_empty = '0' then
						fifonorm_readen <= '1';
						output_state_next <= VALUES_READ;
					else --nothing available, back to idle
						output_state_next <= IDLE;
					end if;
				else --still shifts to do, but from memory now
					output_state_next <= PIPELINE;
				end if;
		end case;
	end process;
	
	curr_probability <= fifonorm_out_prob when output_state_curr = VALUES_READ else 0;
	curr_shift <= fifonorm_out_shift when output_state_curr = VALUES_READ else last_shift; --todo
	shifting_ending <= '0' when number_of_shifts > countdown_timer else '1';

	normalized_lower_bound_add <= normalized_lower_bound + curr_probability;
	shifts_to_perform <= countdown_timer when curr_shift > countdown_timer else curr_shift;
	next_shift <= 0 when curr_shift <= countdown_timer else curr_shift - countdown_timer;
	--can be cut down to 8 only if countdown_timer is reset to 4
	shifted_normalized_lower_bound <=normalized_lower_bound_add when curr_shift = 0 else
												normalized_lower_bound_add(26 downto 0)&"0" when curr_shift = 1 else
												normalized_lower_bound_add(25 downto 0)&"00" when curr_shift = 2 else
												normalized_lower_bound_add(24 downto 0)&"000" when curr_shift = 3 else
												normalized_lower_bound_add(23 downto 0)&"0000" when curr_shift = 4 else
												normalized_lower_bound_add(22 downto 0)&"00000" when curr_shift = 5 else
												normalized_lower_bound_add(21 downto 0)&"000000" when curr_shift = 6 else
												normalized_lower_bound_add(20 downto 0)&"0000000" when curr_shift = 7 else
												normalized_lower_bound_add(19 downto 0)&"00000000" when curr_shift = 8 else
												normalized_lower_bound_add(18 downto 0)&"000000000" when curr_shift = 9 else
												normalized_lower_bound_add(17 downto 0)&"0000000000" when curr_shift = 10 else
												normalized_lower_bound_add(16 downto 0)&"00000000000" when curr_shift = 11 else
												normalized_lower_bound_add(15 downto 0)&"000000000000" when curr_shift = 12 else
												normalized_lower_bound_add(14 downto 0)&"0000000000000" when curr_shift = 13 else
												normalized_lower_bound_add(13 downto 0)&"00000000000000" when curr_shift = 14 else
												normalized_lower_bound_add(12 downto 0)&"000000000000000";-- when num_shifts = 15;
												
												
	update_byte <= '1' when curr_shift >= countdown_timer else '0';
	buffer_is_FF <= '1' when temp_byte_buffer = "11111111" else '0';
	buffer_becomes_FF <= '1' when temp_byte_buffer = "11111110" and shifted_normalized_lower_bound(27) = '1' else '0';
	
	transfer_byte: process(buffer_is_FF, temp_byte_buffer, shifted_normalized_lower_bound, buffer_becomes_FF)
	begin
		if buffer_is_FF = '1' then
			byte_output <= temp_byte_buffer;
			next_temp_byte_buffer <= shifted_normalized_lower_bound(27 downto 20);
			normalized_lower_bound_mask <= "1111111100000000000000000000";
			next_countdown_timer <= 7;
		else
			byte_output <= temp_byte_buffer + shifted_normalized_lower_bound(27);
			if buffer_becomes_FF = '1' then
				next_temp_byte_buffer <= "0" & shifted_normalized_lower_bound(26 downto 20);
				normalized_lower_bound_mask <= "1111111100000000000000000000";
				next_countdown_timer <= 7;
			else
				next_temp_byte_buffer <= shifted_normalized_lower_bound(26 downto 19);
				normalized_lower_bound_mask <= "1111111110000000000000000000";
				next_countdown_timer <= 7;
			end if;
		end if;
	end process;
	
	next_normalized_lower_bound <= shifted_normalized_lower_bound when update_byte = '0' else shifted_normalized_lower_bound and (not normalized_lower_bound_mask);
	
	
	
	clk_update: process(clk)
	
	begin
		--TODO
		if rising_edge(clk) then
			if (rst = '1') then
				last_shift <= 0;
				normalized_lower_bound <= (others => '0');
				temp_byte_buffer <= (others => '0');
				countdown_timer <= 12;
				output_state_curr <= IDLE;
			elsif (clk_en = '1') then
				last_shift <= next_shift;
				normalized_lower_bound <= next_normalized_lower_bound;
				temp_byte_buffer <= next_temp_byte_buffer;
				countdown_timer <= next_countdown_timer;
				output_state_curr <= output_state_next;
			end if;
		end if;
	end process;
	
	
	
	
	
		

	

	
end Behavioral;
