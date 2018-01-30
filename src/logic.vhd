----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:35:04 12/05/2017 
-- Design Name: 
-- Module Name:    logic - Behavioral 
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

use work.JypecConstants.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity logic is
	generic (
		ROWS: integer := 64;
		COLS: integer := 64;
		BITPLANES: integer := 16;
		QUEUE_SIZE: integer := 32
	);
	port (
		clk, rst: 		in std_logic;
		fifoin_wren:	in std_logic; 
		fifoin_in:		in std_logic_vector(7 downto 0);
		fifoin_full:	out std_logic;
		fifoout_empty:	out std_logic; 
		fifoout_out:	out std_logic_vector(7 downto 0); 
		fifoout_readen: in std_logic; 
		ebcoder_busy:	out std_logic;
		debug:			out std_logic_vector(7 downto 0)
--		debug_enable: out std_logic;
--		debug_context: out context_label_t;
--		debug_bit: out std_logic
	);
end logic;

architecture Behavioral of logic is

	--FIFO IN (AFTER UART)
	signal fifoin_readen, fifoin_empty: std_logic;
	signal fifoin_out: std_logic_vector(7 downto 0);
	
	--FIFO FOR RAW DATA
	signal fifodata_wren, fifodata_readen, fifodata_empty, fifodata_full: std_logic;
	signal fifodata_in, fifodata_out: std_logic_vector(26 downto 0);
	
		
	--FIFO FOR UART OUTPUT
	signal fifoout_wren, fifoout_full: std_logic;
	signal fifoout_in: std_logic_vector(7 downto 0);
	
	--EBCoder
	signal ebcoder_clk_en, ebcoder_clk_en_delayed, ebcoder_data_in_en, ebcoder_out_busy: std_logic;
	signal ebcoder_data_in: std_logic_vector(15 downto 0);
	signal ebcoder_out_bytes: std_logic_vector(23 downto 0);
	signal ebcoder_out_valid: std_logic_vector(2 downto 0);
		
	--EBCoder controller
	type input_control_t is (IDLE, READ_ONE, READ_TWO, SAVING);
	signal in_control_state_curr, in_control_state_next: input_control_t;
	signal data_curr, data_next: std_logic_vector(15 downto 0);
	
	type output_control_t is (IDLE, OUTPUT_ONE, OUTPUT_TWO, OUTPUT_THREE);
	signal out_control_state_curr, out_control_state_next: output_control_t;
	signal output_data_curr, output_data_next: std_logic_vector(23 downto 0);
	signal output_data_valid_curr, output_data_valid_next: std_logic_vector(2 downto 0);
	signal outputting: std_logic;


	--debug
	signal out_debug: std_logic_vector(7 downto 0);
	signal arith_active: std_logic;
	

begin

	ebcoder_busy <= ebcoder_out_busy;

	debug(7) <= fifoin_empty;
	debug(6) <= fifodata_full;
	debug(5) <= fifodata_empty;
	debug(4) <= fifoin_empty;
	debug(3) <= '0';
	debug(2) <= ebcoder_out_valid(0);
	debug(1) <= ebcoder_clk_en;
	debug(0) <= ebcoder_out_busy;
	
	delay: process(clk, ebcoder_clk_en)
	begin
		if (rising_edge(clk)) then
			ebcoder_clk_en_delayed <= ebcoder_clk_en;
		end if;
	
	end process;


	--FIFO that gets inputs from the UART
	FIFO_IN: entity work.STD_FIFO
		generic map (
			DATA_WIDTH => 8, FIFO_DEPTH => QUEUE_SIZE
		)
		port map (
			clk => clk, rst => rst,
			WriteEn	=> fifoin_wren,
			datain	=> fifoin_in,
			ReadEn	=> fifoin_readen,
			dataout	=> fifoin_out,
			Empty		=> fifoin_empty,
			Full		=> fifoin_full
		);
		
	--EBCoder sequential control
	update: process(clk)
	begin
		if (rising_edge(clk)) then
			if (rst = '1') then
				in_control_state_curr <= IDLE;
				out_control_state_curr <= IDLE;
				data_curr <= (others => '0');
				output_data_curr <= (others => '0');
				output_data_valid_curr <= (others => '0');
			else
				in_control_state_curr <= in_control_state_next;
				out_control_state_curr <= out_control_state_next;
				data_curr <= data_next;
				output_data_curr <= output_data_next;
				output_data_valid_curr <= output_data_valid_next;
			end if;
		end if;
	
	end process;
		
		
	--EBCoder input controller state machine
	input_control: process(in_control_state_curr, data_curr, 
		fifoin_empty, fifoin_out) 
	begin
		fifoin_readen <= '0';
		in_control_state_next <= in_control_state_curr;
		data_next <= data_curr;
		ebcoder_data_in_en <= '0';
	
		case (in_control_state_curr) is
			when IDLE => 
				if (fifoin_empty = '0') then
					fifoin_readen <= '1';
					in_control_state_next <= READ_ONE;
				end if;
			when READ_ONE =>
				data_next <= fifoin_out & data_curr(7 downto 0);
				if (fifoin_empty = '0') then
					fifoin_readen <= '1';
					in_control_state_next <= READ_TWO;
				end if;			
			when READ_TWO =>
				data_next <= data_curr(15 downto 8) & fifoin_out;
				in_control_state_next <= SAVING;
			when SAVING =>
				ebcoder_data_in_en <= '1';
				in_control_state_next <= IDLE;
		end case;
	end process;
	
	
	
	--EBCoder
	ebcoder_data_in <= data_curr;
	ebcoder_clk_en <= '1' when fifodata_full = '0' else '0';
	
	coder: entity work.EBCoder
		generic map (
			ROWS => ROWS,
			COLS => COLS,
			BITPLANES => BITPLANES
		)
		port map (
			clk => clk,
			rst => rst,
			clk_en => ebcoder_clk_en,
			data_in => ebcoder_data_in,
			data_in_en => ebcoder_data_in_en,
			busy => ebcoder_out_busy,
			out_bytes => ebcoder_out_bytes,
			valid => ebcoder_out_valid,
			out_debug => out_debug,
			arith_active => arith_active
--			debug_enable => debug_enable,
--			debug_context => debug_context,
--			debug_bit => debug_bit
		);
	
	fifodata_wren <= '1' when ebcoder_out_valid /= "000" and ebcoder_out_busy = '1' and ebcoder_clk_en = '1' else '0';
	fifodata_in <= ebcoder_out_valid & ebcoder_out_bytes;
	--fifodata_wren <= arith_active;
	--fifodata_in <= "0010000000000000000" & out_debug;
	
	FIFO_DATA: entity work.STD_FIFO
		generic map (DATA_WIDTH => 27, FIFO_DEPTH => QUEUE_SIZE)
		port map (
			clk => clk,
			rst => rst,
			WriteEn	=> fifodata_wren,
			datain	=> fifodata_in,
			ReadEn	=> fifodata_readen,
			dataout	=> fifodata_out,
			Empty		=> fifodata_empty,
			Full		=> fifodata_full
		);
		
	--coder output control
	take_out: process (out_control_state_curr, fifodata_empty, fifodata_out, fifoout_full)
	begin
		out_control_state_next <= out_control_state_curr;
		fifodata_readen <= '0';
		fifoout_wren <= '0';
		fifoout_in <= (others => '0');
	
		case (out_control_state_curr) is
			when IDLE =>
				if (fifodata_empty = '0') then
					out_control_state_next <= OUTPUT_ONE;
					fifodata_readen <= '1';
				end if;
			when OUTPUT_ONE =>
				if (fifodata_out(26) = '1') then
					if (fifoout_full = '0') then
						fifoout_wren <= '1';
						fifoout_in <= fifodata_out(23 downto 16);
						out_control_state_next <= OUTPUT_TWO;
					end if;
				else
					out_control_state_next <= OUTPUT_TWO;
				end if;
			when OUTPUT_TWO =>
				if (fifodata_out(25) = '1') then
					if (fifoout_full = '0') then
						fifoout_wren <= '1';
						fifoout_in <= fifodata_out(15 downto 8);
						out_control_state_next <= OUTPUT_THREE;
					end if;
				else
					out_control_state_next <= OUTPUT_THREE;
				end if;
			when OUTPUT_THREE =>
				if (fifodata_out(24) = '1') then
					if (fifoout_full = '0') then
						fifoout_wren <= '1';
						fifoout_in <= fifodata_out(7 downto 0);
						out_control_state_next <= IDLE;
					end if;
				else
					out_control_state_next <= IDLE;
				end if;
		end case;
	end process;
		
	

--
--	fifoin_readen <= '1' when fifoin_empty = '0' else '0';
--	
--	upd: process(clk, fifoin_readen) 
--	begin
--		if (rising_edge(clk)) then
--			fifoout_wren <= fifoin_readen;
--		end if;
--	end process;
--	
--	fifoout_in <= fifoin_out;


	
	--FIFO for storing the data that has to be sent back to the UART after coding it
	--(done below)
	FIFO_OUT: entity work.STD_FIFO
		generic map (
			DATA_WIDTH => 8, FIFO_DEPTH => QUEUE_SIZE
		)
		port map (
			clk => clk, rst => rst,
			WriteEn	=> fifoout_wren,
			datain	=> fifoout_in,
			ReadEn	=> fifoout_readen,
			dataout	=> fifoout_out,
			Empty		=> fifoout_empty,
			Full		=> fifoout_full
		);

end Behavioral;

