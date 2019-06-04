----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12.03.2019 09:27:07
-- Design Name: 
-- Module Name: AXIS_DIVIDER - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Divider for two integers. Shifts the divisor to align it with the 
--		dividend, and then it shifts back while substracting the scaled up version
--		of the divisor. Latency is proportional to the result's width.
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
use work.functions.all;
use work.data_types.all;
use IEEE.NUMERIC_STD.ALL;

entity AXIS_DIVIDER is
	Generic (
		DIVIDEND_WIDTH: integer := 24;
		DIVIDEND_SIGNED: boolean := false;
		DIVISOR_WIDTH: integer := 9;
		DIVISOR_SIGNED: boolean := false;
		LAST_POLICY: last_policy_t := PASS_ZERO
	);
	Port (
		clk, rst: in std_logic;
		dividend_data	: in  std_logic_vector(DIVIDEND_WIDTH - 1 downto 0);
		dividend_ready	: out std_logic;
		dividend_valid	: in  std_logic;
		dividend_last	: in  std_logic := '0';
		divisor_data	: in  std_logic_vector(DIVISOR_WIDTH - 1 downto 0);
		divisor_ready	: out std_logic;
		divisor_valid	: in  std_logic;
		divisor_last	: in  std_logic := '0';
		output_data		: out std_logic_vector(unsignedlen(DIVIDEND_WIDTH, DIVISOR_SIGNED) - 1 downto 0); --only need an extra bit when divisor is signed
		output_err		: out std_logic;
		output_valid	: out std_logic;
		output_ready	: in  std_logic;
		output_last		: out std_logic
	);
end AXIS_DIVIDER;

architecture Behavioral of AXIS_DIVIDER is
    constant INNER_DIVIDEND_WIDTH: integer := unsignedlen(DIVIDEND_WIDTH, DIVIDEND_SIGNED);
    constant INNER_DIVISOR_WIDTH:  integer := unsignedlen(DIVISOR_WIDTH, DIVISOR_SIGNED);
    constant INNER_WIDTH: integer := maxval(INNER_DIVIDEND_WIDTH, INNER_DIVISOR_WIDTH);

	--input joiner
	signal joint_valid, joint_ready: std_logic;
	signal joint_dividend: std_logic_vector(DIVIDEND_WIDTH - 1 downto 0);
	signal joint_divisor: std_logic_vector(DIVISOR_WIDTH - 1 downto 0);
	signal joint_last: std_logic;

	--state
	type divider_state_t is (IDLE, SHIFT_DIVISOR, DIVIDING, FINISHED, DIVIDE_BY_ZERO);
	signal state_curr, state_next: divider_state_t;

	--input buffers
	signal dividend_buf, dividend_buf_next: std_logic_vector(INNER_WIDTH - 1 downto 0);
	signal divisor_buf, divisor_buf_next: std_logic_vector(INNER_WIDTH - 1 downto 0);
	signal dividend_buf_signed, dividend_buf_signed_next: boolean;
	signal divisor_buf_signed, divisor_buf_signed_next: boolean;
	signal last_buf, last_buf_next: std_logic;
	
	--intermediate result buffers
	signal dividend_minus_divisor: std_logic_vector(INNER_WIDTH - 1 downto 0);
    signal result, result_next: std_logic_vector(INNER_WIDTH - 1 downto 0);
	signal shamt, shamt_next: natural range 0 to INNER_WIDTH;
	
	--qol signals
    signal dividend_bitcnt: natural range 0 to INNER_WIDTH;
    signal divisor_bitcnt: natural range 0 to INNER_WIDTH;

begin


	joint_signals: entity work.AXIS_SYNCHRONIZER_2
		generic map (
			DATA_WIDTH_0 => DIVIDEND_WIDTH,
			DATA_WIDTH_1 => DIVISOR_WIDTH,
			LATCH => false,
			LAST_POLICY => LAST_POLICY
		)
		port map (
			clk => clk, rst => rst,
			input_0_valid => dividend_valid,
			input_0_ready => dividend_ready,
			input_0_data  => dividend_data,
			input_0_last  => dividend_last,
			input_1_valid => divisor_valid,
			input_1_ready => divisor_ready,
			input_1_data  => divisor_data,
			input_1_last  => divisor_last,
			--to output axi ports
			output_valid  => joint_valid,
			output_ready  => joint_ready,
			output_data_0 => joint_dividend,
			output_data_1 => joint_divisor,
			output_last   => joint_last
		);

	seq: process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				state_curr   <= IDLE;
				dividend_buf <= (others => '0');
				divisor_buf  <= (others => '0');
				last_buf     <= '0';
                shamt        <= 0;
                result       <= (others => '0');
                dividend_buf_signed <= false;
                divisor_buf_signed	<= false;
			else
				state_curr   <= state_next;
				dividend_buf <= dividend_buf_next;
				divisor_buf  <= divisor_buf_next;
				last_buf 	 <= last_buf_next;
                shamt        <= shamt_next;
                result       <= result_next;
				dividend_buf_signed <= dividend_buf_signed_next;
                divisor_buf_signed  <= divisor_buf_signed_next;
			end if;
		end if;
	end process;

    calc_bitcnts: process(dividend_buf, divisor_buf)
    begin
        dividend_bitcnt <= 0;
        for i in dividend_buf'high downto dividend_buf'low loop
            if dividend_buf(i) = '1' then
                dividend_bitcnt <= i + 1;
                exit;
            end if;
        end loop;

        divisor_bitcnt <= 0;
        for i in divisor_buf'high downto divisor_buf'low loop
            if divisor_buf(i) = '1' then
                divisor_bitcnt <= i + 1;
                exit;
            end if;
        end loop;
    end process;

	dividend_minus_divisor <= std_logic_vector(unsigned(dividend_buf) - unsigned(divisor_buf));

	comb: process(state_curr, joint_valid, joint_dividend, joint_divisor, joint_last, dividend_minus_divisor,
		dividend_bitcnt, divisor_bitcnt, divisor_buf, dividend_buf, result, shamt,
		dividend_buf_signed, divisor_buf_signed, last_buf, output_ready)
	begin
		--i/o
		joint_ready <= '0';
		output_err <= '0';
		output_valid <= '0';
		--state
		state_next  <= state_curr;
		--others
		dividend_buf_signed_next <= dividend_buf_signed;
		divisor_buf_signed_next  <= divisor_buf_signed;
		last_buf_next <= last_buf;
		result_next <= result;
		shamt_next <= shamt;
		dividend_buf_next <= dividend_buf;
		divisor_buf_next <= divisor_buf;

		if state_curr = IDLE then
			joint_ready <= '1';
			if joint_valid = '1' then
				last_buf_next <= joint_last;
				dividend_buf_signed_next <= false;
                if DIVIDEND_SIGNED then
                    if joint_dividend(joint_dividend'high) = '1' then
                    	dividend_buf_signed_next <= true;
                        dividend_buf_next <= std_logic_vector(resize(-signed(joint_dividend), INNER_WIDTH));
                    else
                        dividend_buf_next <= std_logic_vector(resize(unsigned(joint_dividend), INNER_WIDTH));
                    end if;
                else
                    dividend_buf_next <= std_logic_vector(resize(unsigned(joint_dividend), INNER_WIDTH));
                end if;
                divisor_buf_signed_next <= false;
                if DIVISOR_SIGNED then
                    if joint_divisor(joint_divisor'high) = '1' then
                    	divisor_buf_signed_next <= true;
                        divisor_buf_next <= std_logic_vector(resize(-signed(joint_divisor), INNER_WIDTH));
                    else
                        divisor_buf_next <= std_logic_vector(resize(unsigned(joint_divisor), INNER_WIDTH));
                    end if;
                else
                    divisor_buf_next  <= std_logic_vector(resize(unsigned(joint_divisor), INNER_WIDTH));
                end if;
                if joint_divisor = (joint_divisor'range => '0') then
                	state_next 		  <= DIVIDE_BY_ZERO;
                else
                	state_next        <= SHIFT_DIVISOR;
                end if;
			end if;
			--reset result and shamt
			result_next <= (others => '0');
			shamt_next  <= 0;
        elsif state_curr = SHIFT_DIVISOR then
        	--if divisor_buf = (divisor_buf'range => '0') then
        	--	state_next <= DIVIDE_BY_ZERO;
--        	--can do a bunch of options here
--       	--elsif unsigned(dividend_buf) >= shift_left(unsigned(divisor_buf), 1) then
--        	--elsif divisor_buf(divisor_buf'high) = '0' then 
            if dividend_minus_divisor(dividend_minus_divisor'high) = '0' and divisor_buf(divisor_buf'high) = '0' then 
            	shamt_next <= shamt + 1;
            	divisor_buf_next <= std_logic_vector(shift_left(unsigned(divisor_buf), 1));
--            if divisor_buf(divisor_buf'high downto divisor_buf'high-7) = (7 downto 0 => '0') then
--            	shamt_next <= shamt + 8;
--                divisor_buf_next <= std_logic_vector(shift_left(unsigned(divisor_buf), 8));
--            elsif divisor_buf(divisor_buf'high downto divisor_buf'high-3) = (3 downto 0 => '0') then
--				shamt_next <= shamt + 4;
--				divisor_buf_next <= std_logic_vector(shift_left(unsigned(divisor_buf), 4));
--            elsif divisor_buf(divisor_buf'high downto divisor_buf'high-1) = (1 downto 0 => '0') then
--				shamt_next <= shamt + 2;
--				divisor_buf_next <= std_logic_vector(shift_left(unsigned(divisor_buf), 2));                 
--            elsif divisor_buf(divisor_buf'high downto divisor_buf'high-0) = (0 downto 0 => '0') then
--				shamt_next <= shamt + 1;
--				divisor_buf_next <= std_logic_vector(shift_left(unsigned(divisor_buf), 1));
            else
            	state_next <= DIVIDING;
            end if;
        elsif state_curr = DIVIDING then
            divisor_buf_next <= std_logic_vector(shift_right(unsigned(divisor_buf), 1));
            -- if unsigned(dividend_buf) >= unsigned(divisor_buf) then
            if dividend_minus_divisor(dividend_minus_divisor'high) = '0' then
                dividend_buf_next <= std_logic_vector(unsigned(dividend_buf) - unsigned(divisor_buf));
                result_next <= result(result'high - 1 downto 0) & '1';
            else
                result_next <= result(result'high - 1 downto 0) & '0';
            end if;
            if shamt = 0 then
                state_next <= FINISHED;
            else
                shamt_next <= shamt - 1;
            end if;
        elsif state_curr = FINISHED then
            output_err  <= '0';
            output_valid <= '1';
            if output_ready = '1' then
                state_next <= IDLE;
            end if;
        elsif state_curr = DIVIDE_BY_ZERO then
            output_err  <= '1';
            output_valid <= '1';
            if output_ready = '1' then
                state_next <= IDLE;
            end if;
		end if;
	end process;

	output_last <= last_buf;

	gen_output_dns_drs: if DIVIDEND_SIGNED and DIVISOR_SIGNED generate
    	output_data <= std_logic_vector(resize(unsigned(result), output_data'length)) when divisor_buf_signed = dividend_buf_signed
    			else   std_logic_vector(resize(-signed(result), output_data'length));
    end generate;
    gen_output_dns_dru: if DIVIDEND_SIGNED and not DIVISOR_SIGNED generate
		output_data <= std_logic_vector(resize(unsigned(result), output_data'length)) when dividend_buf_signed
				else   std_logic_vector(resize(-signed(result), output_data'length));
	end generate;
    gen_output_dnu_drs: if not DIVIDEND_SIGNED and DIVISOR_SIGNED generate
		output_data <= std_logic_vector(resize(unsigned(result), output_data'length)) when divisor_buf_signed
				else   std_logic_vector(resize(-signed(result), output_data'length));
	end generate;
    gen_output_dnu_dru: if not DIVIDEND_SIGNED and not DIVISOR_SIGNED generate
		output_data <= std_logic_vector(resize(unsigned(result), output_data'length));
	end generate;
                
             

end Behavioral;
