----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:42:38 11/29/2017 
-- Design Name: 
-- Module Name:    EBCoder_wrapper - Behavioral 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
-- use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
-- library UNISIM;
-- use UNISIM.VComponents.all;

entity EBCoder_wrapper is
	generic (
		KHZ_FREQUENCY: integer := 10000;
		BAUDS: integer := 9600;
		QUEUE_SIZE: integer := 32;
		ROWS: integer := 64;
		COLS: integer := 64;
		BITPLANES: integer := 16
	);
	port (
		clk_in_p, clk_in_n, sw2, rx: in std_logic; --virtex 7
		--clk_in, sw2, rx: in std_logic;	--virtex 4
		tx: out std_logic;
		LEDs: out std_logic_vector(7 downto 0)
	);
end EBCoder_wrapper;

architecture Behavioral of EBCoder_wrapper is
	
	--SHARED SIGNALS
	signal clk, rst: std_logic;
			
	signal fifoin_wren      : std_logic;
	signal fifoin_in        : std_logic_vector(7 downto 0);
	signal fifoout_empty    : std_logic;
	signal fifoout_out      : std_logic_vector(7 downto 0);
	signal fifoout_readen   : std_logic;
	signal debug            : std_logic_vector(7 downto 0);
	
	signal locked_out: std_logic;
	
	component clk_wiz_0
	port
	 (-- Clock in ports
	  -- Clock out ports
	  clk_out1          : out    std_logic;
	  clk_in1_p         : in     std_logic;
	  clk_in1_n         : in     std_logic
	 );
	end component;


begin

	--rst <= '0' when sw2 = '1' else '1'; --virtex 4
	rst <= sw2; --virtex 7
	
	--virtex 4 clk reduction
--	Inst_clk_red: entity work.clk_red PORT MAP(
--		CLKIN_IN => clk_in,
--		CLKDV_OUT => clk,
--		CLKIN_IBUFG_OUT => open,
--		CLK0_OUT =>  open,
--		LOCKED_OUT => locked_out --=1 once this is stabilized
--	);

	--virtex 7 clk reduction
	clk_red: clk_wiz_0 port map (
		clk_in1_p => clk_in_p,
		clk_in1_n => clk_in_n,
		clk_out1 => clk
	);

	
	LEDs(7) <= rst;
	LEDs(6 downto 0) <= debug(6 downto 0);
	
	


	--UART INPUT CONTROLLER
	input_uart: entity work.uart_rx_nandland
		generic map (
			g_CLKS_PER_BIT => (KHZ_FREQUENCY*1000)/BAUDS
		)
		port map (
			i_Clk => clk,
			i_RX_Serial => rx,
			o_RX_DV => fifoin_wren,
			o_RX_Byte => fifoin_in
		);
		
	--EBCODER LOGIC AND FIFOS
	ebcoder_logic: entity work.logic
		generic map (
			ROWS => ROWS,
			COLS => COLS,
			BITPLANES => BITPLANES,
			QUEUE_SIZE => QUEUE_SIZE
		)
		port map (
			clk => clk, rst => rst,
			fifoin_wren => fifoin_wren, 
			fifoin_in => fifoin_in,
			fifoin_full => open,
			fifoout_empty => fifoout_empty, 
			fifoout_out => fifoout_out, 
			fifoout_readen => fifoout_readen, 
			ebcoder_busy => open,
			debug => debug
		);
						
						
	--WRITE FROM FIFO OUT TO UART
	output_uart: entity work.output_controller
		generic map (
			g_CLKS_PER_BIT => (KHZ_FREQUENCY*1000)/BAUDS
		)
		port map (
			clk => clk, rst => rst,
			input_queue_empty => fifoout_empty,
			input_queue_out => fifoout_out,
			input_queue_rdenb => fifoout_readen,
			output_tx => tx
		);

end Behavioral;

