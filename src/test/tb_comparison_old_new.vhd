--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   11:02:19 12/05/2017
-- Design Name:   
-- Module Name:   C:/Users/Daniel/Xilinx_projects/Jypec/tb_comparison_old_new.vhd
-- Project Name:  Jypec
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: logic
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use work.JypecConstants.all;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
USE ieee.numeric_std.ALL;


 
ENTITY tb_comparison_old_new IS
END tb_comparison_old_new;
 
ARCHITECTURE behavior OF tb_comparison_old_new IS 
    -- Clock period definitions
   constant clk_period : time := 10 ns;
	constant ROWS: integer := 64;
	constant STRIPS: integer := 16;
	constant COLS: integer := 64;
	constant BITPLANES: integer := 16;
	constant QUEUE_SIZE: integer := 32;
	
	
   --Inputs
   signal clk : std_logic := '0';
   signal rst : std_logic := '0';
	
	
	--uut1 signals
   signal fifoin_wren : std_logic := '0';
   signal fifoin_in : std_logic_vector(7 downto 0) := (others => '0');
   signal fifoout_readen : std_logic := '0';
   signal fifoout_empty : std_logic;
   signal fifoout_out : std_logic_vector(7 downto 0);
   signal debug : std_logic_vector(7 downto 0);
	
	--uut2 signals
	signal bpc_input: std_logic_vector((BITPLANES)*4 - 1 downto 0);
	signal bpc_input_loc: natural range 0 to COLS*ROWS/4 - 1;
	signal bpc_input_en, bpc_clk_en: std_logic;
	signal bpc_out_empty: std_logic;
	signal bpc_out_byte: std_logic_vector(7 downto 0);
	signal bpc_out_readen: std_logic;
	signal bpc_done: std_logic;


	
	
	constant PRIME: integer := 9973;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: entity work.logic 
		GENERIC MAP (
			ROWS => ROWS,
			COLS => COLS,
			BITPLANES => BITPLANES,
			QUEUE_SIZE => QUEUE_SIZE
			)
		PORT MAP (
          clk => clk,
          rst => rst,
          fifoin_wren => fifoin_wren,
          fifoin_in => fifoin_in,
          fifoout_empty => fifoout_empty,
          fifoout_out => fifoout_out,
          fifoout_readen => fifoout_readen,
          debug => debug
        );
		  
	uut2: entity work.BPC_logic
		generic map (
			STRIPS => ROWS / 4,
			COLS => COLS,
			BITPLANES => BITPLANES-1,

			--number of elements in inner queues
			BPC_OUT_QUEUE_SIZE => 512,
			BPC_CXD_QUEUE_SIZE => 32,
			BOUND_UPDATE_FIFO_DEPTH => 32,
			OUT_FIFO_DEPTH => 8
		)
		port map (
			clk => clk , rst => rst, clk_en => bpc_clk_en,
			input => bpc_input,
			input_loc => bpc_input_loc,
			input_en => bpc_input_en,
			out_empty => bpc_out_empty,
			out_byte => bpc_out_byte,
			out_readen => bpc_out_readen,
			done => bpc_done
		);



   -- Clock process definitions
   clk_process: process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
	
		--send a block generated with a given prime number
		procedure send_block_bpc(prime: in integer) is 
			variable i: integer := 0;
		begin
			while (i < COLS*STRIPS) loop
				bpc_input <= std_logic_vector(to_unsigned(((i*4+0)*PRIME) mod (2**BITPLANES), BITPLANES))
						&	std_logic_vector(to_unsigned(((i*4+1)*PRIME) mod (2**BITPLANES), BITPLANES))
						&	std_logic_vector(to_unsigned(((i*4+2)*PRIME) mod (2**BITPLANES), BITPLANES))
						&	std_logic_vector(to_unsigned(((i*4+3)*PRIME) mod (2**BITPLANES), BITPLANES));
				bpc_input_loc <= i;
				bpc_input_en <= '1';
				wait for clk_period;
				i := i + 1;
			end loop;
			bpc_input_en <= '0';
		end send_block_bpc;
		

		procedure send_block_old(prime: in integer) is
			variable i: integer := 0;
		begin
			while i <= ROWS * COLS - 1 loop
				--write first byte
				fifoin_in <= std_logic_vector(to_unsigned(((i*PRIME) / (2**8)) mod (2**8), 8));
				fifoin_wren <= '1';
				wait for clk_period;
				fifoin_wren <= '0';
				wait for clk_period;
				--write second byte
				fifoin_in <= std_logic_vector(to_unsigned((i*PRIME) mod (2**8), 8));
				fifoin_wren <= '1';
				wait for clk_period;
				fifoin_wren <= '0';
				wait for clk_period;
				i := i + 1;
			end loop;
		end send_block_old;
		

	
   begin		
		wait for clk_period*0.999;
		--assign initial values
		fifoin_in <= (others => '0');
		fifoin_wren <= '0';
		bpc_input <= (others => '0');
		bpc_input_loc <= 0;
		bpc_input_en <= '0';
		bpc_clk_en <= '0';
		rst <= '1';
      wait for 100 ns;	
		--disable reset and send blocks
		rst <= '0';
		wait for clk_period*10;
		
		send_block_bpc(PRIME);
		send_block_old(PRIME);
		--ready to process
		
		bpc_clk_en <= '1';
		
		
      wait;
   end process;
	
	
	
	take_out: process
		variable first_read_cnt: integer := 0;
		variable out_cnt: integer := 0;
	begin
--		fifoout_readen <= '1';
--		bpc_out_readen <= '1';
--		wait;
		while true loop
			wait for clk_period;
			if (first_read_cnt /= 0) then
				if (bpc_out_empty = '0') then
					bpc_out_readen <= '1';
					wait for clk_period;
					bpc_out_readen <= '0';
					first_read_cnt := first_read_cnt - 1;
				end if;
			else
				if (bpc_out_empty = '0' and fifoout_empty = '0') then
					fifoout_readen <= '1';
					bpc_out_readen <= '1';
					wait for clk_period;
					fifoout_readen <= '0';
					bpc_out_readen <= '0';
					assert bpc_out_byte = fifoout_out report "DIFFERENCE: " & integer'image(out_cnt) severity warning;
					out_cnt := out_cnt + 1;
				end if;
			end if;
		end loop;
	
	end process;


END;


