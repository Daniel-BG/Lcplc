----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 21.02.2019 09:22:48
-- Design Name: 
-- Module Name: FIRSTBANDMODULE - Behavioral
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

entity FIRSTBAND_PREDICTOR is
	Generic (
		DATA_WIDTH: positive := 16;
		BLOCK_SIZE_LOG: positive := 8;
		ACC_LOG: positive := 5
	);
	Port (
		clk, rst		: in  std_logic;
		--input values
		x_valid			: in  std_logic;
		x_ready			: out std_logic;
		x_data			: in  std_logic_vector(DATA_WIDTH - 1 downto 0);
		--output mapped error, coding parameter and xhat out value
		--output prediction
		prediction_ready: in std_logic;
		prediction_valid: out std_logic;
		prediction_data : out std_logic_vector(DATA_WIDTH downto 0)
	);
end FIRSTBAND_PREDICTOR;

architecture Behavioral of FIRSTBAND_PREDICTOR is
	type firstband_state_t is (IDLE, PREDICTING_FIRST, AWAITING_REST, PREDICTING_REST);
	signal state_curr, state_next: firstband_state_t;

	--queue system for previous samples
	signal current_sample, left_sample, upper_sample: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal shift_enable: std_logic;
	
	--counter stuff
	signal counter_enable: std_logic;
	signal counter_x, counter_y: natural range 0 to 2**(BLOCK_SIZE_LOG/2) - 1;

	--prediction
	signal prediction: std_logic_vector(DATA_WIDTH downto 0);
	signal upleft_addition: std_logic_vector(DATA_WIDTH downto 0);
begin

	seq: process(clk)
	begin
		if rising_Edge(clk) then
			if rst = '1' then
				state_curr <= IDLE;
			else
				state_curr <= state_next;
				if shift_enable <= '1' then
					current_sample <= x_data;
					left_sample <= current_sample;
				end if;
			end if;
		end if;
	end process;
	
	shift_reg_prev_line: entity work.SHIFT_REG
		Generic map (
			DATA_WIDTH => DATA_WIDTH,
			DEPTH => 2**(BLOCK_SIZE_LOG/2)
		)
		Port map (
			clk => clk, enable => shift_enable,
			input => current_sample,
			output => upper_sample
		);
	
	comb: process(state_curr, prediction_ready, x_valid, prediction)
	begin
		x_ready <= '0';
		shift_enable <= '0';
		prediction_valid <= '0';
		prediction_data <= (others => '0');
		state_next <= state_curr;
		
		if state_curr = IDLE then
			x_ready <= '1';
			if x_valid = '1' then
				shift_enable <= '1';
				state_next <= PREDICTING_FIRST;
			end if;
		elsif state_curr = PREDICTING_FIRST then
			prediction_valid <= '1';
			if prediction_ready = '1' then
				prediction_data <= (others => '0');
				x_ready <= '1';
				if x_valid = '1' then
					shift_enable <= '1';
					state_next <= PREDICTING_REST;
				else
					state_next <= AWAITING_REST;
				end if;
			end if;
		elsif state_curr = AWAITING_REST then
			x_ready <= '1';
			if x_valid = '1' then
				shift_enable <= '1';
				state_next <= PREDICTING_REST;
			end if;
		elsif state_curr = PREDICTING_REST then
			prediction_valid <= '1';
			if prediction_ready = '1' then
				prediction_data <= prediction;
				x_ready <= '1';
				if x_valid = '1' then
					shift_enable <= '1';
					state_next <= PREDICTING_REST;
				else
					state_next <= AWAITING_REST;
				end if;
			end if;
		end if;
	end process;

	counter_enable <= '1' when shift_enable = '1' and state_curr /= IDLE else '0';

	counter: entity work.TWO_DIMENSIONAL_COORDINATE_TRACKER
		Generic map (
			X_SIZE => 2**(BLOCK_SIZE_LOG/2),
			Y_SIZE => 2**(BLOCK_SIZE_LOG/2)
		)
		Port map (
			clk => clk, rst => rst, enable => counter_enable,
			x_coord => counter_x,
			y_coord => counter_y
		);
		
	prediction_gen: process(counter_x, counter_y, upper_Sample, left_sample, upleft_addition)
	begin
		prediction <= (others => '0');
		--if counter_x = 0 and counter_y = 0 then
		--	prediction <= (prediction'high downto current_sample'high+1 => '0') & current_sample;
		--elsif
		--can omit that since the state already takes that into account
		if counter_x = 0 then
			prediction <= (prediction'high downto current_sample'high+1 => '0')  & upper_sample;
		elsif counter_y = 0 then
			prediction <= (prediction'high downto current_sample'high+1 => '0')  & left_sample;
		else
			prediction <= (prediction'high downto upleft_addition'high+1 => '0') & upleft_addition;
		end if;
	end process;

	upleft_addition <= std_logic_vector(unsigned("0" & upper_sample) + unsigned("0" & left_sample));

end Behavioral;
