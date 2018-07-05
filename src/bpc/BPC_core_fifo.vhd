----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:34:28 06/11/2018 
-- Design Name: 
-- Module Name:    BPC_core_fifo - Behavioral 
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

entity BPC_core_fifo is
	generic (
		QUEUE_SIZE: integer := 32
	);
	port (
		clk, rst: in std_logic;
		--flags and controls
		wr_en, rd_en: in std_logic;
		full, empty: out std_logic;
		--inputs and outputs
		in_contexts: in BPC_out_contexts_t;
		in_bits: in BPC_out_bits_t;
		in_valid: in BPC_out_valid_t;
		out_contexts: out BPC_out_contexts_t;
		out_bits: out BPC_out_bits_t;
		out_valid: out BPC_out_valid_t
	);
end BPC_core_fifo;

architecture Behavioral of BPC_core_fifo is

	signal in_fifo, out_fifo: std_logic_vector(76 downto 0);

begin

	--convert to std_logic_vector
		--11 data bits 
		--11 valid bits
		--5x11=55 context bits
	map_inout: for i in 0 to 10 generate
		in_fifo(0+7*i) <= in_valid(i);
		out_valid(i) <= out_fifo(0+7*i);
		
		in_fifo(1+7*i) <= in_bits(i);
		out_bits(i) <= out_fifo(1+7*i);
		
		in_fifo(6+7*i downto 2+7*i) <= std_logic_vector(to_unsigned(in_contexts(i), 5));
		out_contexts(i) <= to_integer(unsigned(out_fifo(6+7*i downto 2+7*i)));
	end generate;


	INNER_FIFO: entity work.LOOKAHEAD_FIFO
		generic map (
			DATA_WIDTH => 77, FIFO_DEPTH => QUEUE_SIZE, LOOK_AHEAD => 1
		)
		port map (
			clk => clk, rst => rst,
			wren => wr_en,
			datain => in_fifo,
			readen => rd_en,
			dataout => out_fifo,
			empty => empty,
			full => open,
			lah_empty => open,
			lah_full => full
		);
	


	--map to standard fifo queue	
--	INNER_FIFO: entity work.STD_FIFO
--		generic map (
--			DATA_WIDTH => 77, FIFO_DEPTH => QUEUE_SIZE
--		)
--		port map (
--			clk => clk, rst => rst,
--			WriteEn	=> wr_en,
--			datain	=> in_fifo,
--			ReadEn	=> rd_en,
--			dataout	=> out_fifo,
--			Empty		=> empty,
--			Full		=> full
--		);

end Behavioral;

