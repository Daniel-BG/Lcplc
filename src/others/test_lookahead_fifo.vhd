--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   11:16:32 07/03/2018
-- Design Name:   
-- Module Name:   C:/Users/Daniel/Repositorios/Vypec/src/others/test_lookahead_fifo.vhd
-- Project Name:  Jypec
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: LOOKAHEAD_FIFO
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
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY test_lookahead_fifo IS
	Generic (
		constant DATA_WIDTH: positive := 64;
		constant FIFO_DEPTH: positive := 32;
		constant LOOK_AHEAD: positive := 3
	);
END test_lookahead_fifo;
 
ARCHITECTURE behavior OF test_lookahead_fifo IS 


   --Inputs
   signal clk : std_logic := '0';
   signal rst : std_logic := '0';
   signal wren : std_logic := '0';
   signal datain : std_logic_vector(63 downto 0) := (others => '0');
   signal readen : std_logic := '0';

 	--Outputs
   signal dataout : std_logic_vector(63 downto 0);
   signal empty : std_logic;
   signal full : std_logic;
   signal lah_empty : std_logic;
   signal lah_full : std_logic;

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: entity work.LOOKAHEAD_FIFO 
		GENERIC MAP (
			DATA_WIDTH => DATA_WIDTH,
			FIFO_DEPTH => FIFO_DEPTH,
			LOOK_AHEAD => LOOK_AHEAD
		)
		PORT MAP (
          clk => clk,
          rst => rst,
          wren => wren,
          datain => datain,
          readen => readen,
          dataout => dataout,
          empty => empty,
          full => full,
          lah_empty => lah_empty,
          lah_full => lah_full
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
		rst <= '1';
		datain <= (others => '0'); 
      wait for 100 ns;	
		rst <= '0';
		
		wren <= '1';
		wait for clk_period*FIFO_DEPTH;
		datain <= (others => '1');
		wait for clk_period*4;
		readen <= '1';
		wait for clk_period*FIFO_DEPTH;
		wren <= '0';
		wait for clk_period*FIFO_DEPTH;
		
      

      -- insert stimulus here 

      wait;
   end process;

END;
