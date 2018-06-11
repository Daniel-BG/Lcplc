----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:14:19 06/11/2018 
-- Design Name: 
-- Module Name:    BPC_cxd_fifo - Behavioral 
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

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity BPC_cxd_fifo is
	generic (
		QUEUE_SIZE: integer := 32
	);
	port (
		clk, rst: in std_logic;
		--flags and controls
		wr_en, rd_en: in std_logic;
		full, empty: out std_logic;
		--inputs and outputs
		in_context: in context_label_t;
		in_bit: in std_logic;
		out_context: out context_label_t;
		out_bit: out std_logic
	);
end BPC_cxd_fifo;

architecture Behavioral of BPC_cxd_fifo is

	signal in_fifo, out_fifo: std_logic_vector(5 downto 0);

begin

	--convert to std_logic_vector		
	in_fifo(5) <= in_bit;
	out_bit <= out_fifo(5);
	
	in_fifo(4 downto 0) <= std_logic_vector(to_unsigned(in_context, 5));
	out_context <= to_integer(unsigned(out_fifo(4 downto 0)));



	--map to standard fifo queue	
	INNER_FIFO: entity work.STD_FIFO
		generic map (
			DATA_WIDTH => 6, FIFO_DEPTH => QUEUE_SIZE
		)
		port map (
			clk => clk, rst => rst,
			WriteEn	=> wr_en,
			datain	=> in_fifo,
			ReadEn	=> rd_en,
			dataout	=> out_fifo,
			Empty		=> empty,
			Full		=> full
		);

end Behavioral;

