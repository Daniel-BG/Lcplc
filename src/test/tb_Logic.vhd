--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   11:02:19 12/05/2017
-- Design Name:   
-- Module Name:   C:/Users/Daniel/Xilinx_projects/Jypec/tb_Logic.vhd
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
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
USE ieee.numeric_std.ALL;
 
ENTITY tb_Logic IS
END tb_Logic;
 
ARCHITECTURE behavior OF tb_Logic IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT logic
		generic (
			ROWS: integer := 64;
			COLS: integer := 64;
			BITPLANES: integer := 16;
			QUEUE_SIZE: integer := 32
		);
    PORT(
         clk : IN  std_logic;
         rst : IN  std_logic;
         fifoin_wren : IN  std_logic;
         fifoin_in : IN  std_logic_vector(7 downto 0);
         fifoout_empty : OUT  std_logic;
         fifoout_out : OUT  std_logic_vector(7 downto 0);
         fifoout_readen : IN  std_logic;
         debug : OUT  std_logic_vector(7 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal rst : std_logic := '0';
   signal fifoin_wren : std_logic := '0';
   signal fifoin_in : std_logic_vector(7 downto 0) := (others => '0');
   signal fifoout_readen : std_logic := '0';

 	--Outputs
   signal fifoout_empty : std_logic;
   signal fifoout_out : std_logic_vector(7 downto 0);
   signal debug : std_logic_vector(7 downto 0);

   -- Clock period definitions
   constant clk_period : time := 10 ns;
	constant ROWS: integer := 64;
	constant COLS: integer := 64;
	constant BITPLANES: integer := 16;
	constant QUEUE_SIZE: integer := 32;
	
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: logic 
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
		
		variable i: integer := 0;
		variable PRIME: integer := 9973;
	
   begin		
		wait for clk_period*0.999;
		--assign initial values
		fifoin_in <= (others => '0');
		fifoin_wren <= '0';
		fifoout_readen <= '0';
		
		rst <= '0';
      wait for 100 ns;	
		--reset for only one cycle
		rst <= '1';
      wait for clk_period;
		rst <= '0';
		wait for clk_period*10;
		--enable reading of output queue by default
		fifoout_readen <= '1';
		

		while i <= ROWS * COLS loop
			--write first byte
			fifoin_in <= std_logic_vector(to_unsigned(((i*PRIME) / (2**8)) mod (2**8), 8));
			fifoin_wren <= '1';
			wait for clk_period;
			fifoin_wren <= '0';
			wait for clk_period*20;
			--write second byte
			fifoin_in <= std_logic_vector(to_unsigned((i*PRIME) mod (2**8), 8));
			fifoin_wren <= '1';
			wait for clk_period;
			fifoin_wren <= '0';
			wait for clk_period*20;
			i := i + 1;
		end loop;

      wait;
   end process;

END;
