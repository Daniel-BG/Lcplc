------------------------------------------------------------------------------
-- user_logic.vhd - entity/architecture pair
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 1995-2012 Xilinx, Inc.  All rights reserved.            **
-- **                                                                       **
-- ** Xilinx, Inc.                                                          **
-- ** XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS"         **
-- ** AS A COURTESY TO YOU, SOLELY FOR USE IN DEVELOPING PROGRAMS AND       **
-- ** SOLUTIONS FOR XILINX DEVICES.  BY PROVIDING THIS DESIGN, CODE,        **
-- ** OR INFORMATION AS ONE POSSIBLE IMPLEMENTATION OF THIS FEATURE,        **
-- ** APPLICATION OR STANDARD, XILINX IS MAKING NO REPRESENTATION           **
-- ** THAT THIS IMPLEMENTATION IS FREE FROM ANY CLAIMS OF INFRINGEMENT,     **
-- ** AND YOU ARE RESPONSIBLE FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE      **
-- ** FOR YOUR IMPLEMENTATION.  XILINX EXPRESSLY DISCLAIMS ANY              **
-- ** WARRANTY WHATSOEVER WITH RESPECT TO THE ADEQUACY OF THE               **
-- ** IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR        **
-- ** REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE FROM CLAIMS OF       **
-- ** INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS       **
-- ** FOR A PARTICULAR PURPOSE.                                             **
-- **                                                                       **
-- ***************************************************************************
--
------------------------------------------------------------------------------
-- Filename:          user_logic.vhd
-- Version:           1.00.a
-- Description:       User logic.
-- Date:              Tue Nov 14 11:23:07 2017 (by Create and Import Peripheral Wizard)
-- VHDL Standard:     VHDL'93
------------------------------------------------------------------------------
-- Naming Conventions:
--   active low signals:                    "*_n"
--   clock signals:                         "clk", "clk_div#", "clk_#x"
--   reset signals:                         "rst", "rst_n"
--   generics:                              "C_*"
--   user defined types:                    "*_TYPE"
--   state machine next state:              "*_ns"
--   state machine current state:           "*_cs"
--   combinatorial signals:                 "*_com"
--   pipelined or register delay signals:   "*_d#"
--   counter signals:                       "*cnt*"
--   clock enable signals:                  "*_ce"
--   internal version of output port:       "*_i"
--   device pins:                           "*_pin"
--   ports:                                 "- Names begin with Uppercase"
--   processes:                             "*_PROCESS"
--   component instantiations:              "<ENTITY_>I_<#|FUNC>"
------------------------------------------------------------------------------

-- DO NOT EDIT BELOW THIS LINE --------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library proc_common_v3_00_a;
use proc_common_v3_00_a.proc_common_pkg.all;

-- DO NOT EDIT ABOVE THIS LINE --------------------

--USER libraries added here

------------------------------------------------------------------------------
-- Entity section
------------------------------------------------------------------------------
-- Definition of Generics:
--   C_SLV_DWIDTH                 -- Slave interface data bus width
--   C_NUM_REG                    -- Number of software accessible registers
--
-- Definition of Ports:
--   Bus2IP_Clk                   -- Bus to IP clock
--   Bus2IP_Reset                 -- Bus to IP reset
--   Bus2IP_Data                  -- Bus to IP data bus
--   Bus2IP_BE                    -- Bus to IP byte enables
--   Bus2IP_RdCE                  -- Bus to IP read chip enable
--   Bus2IP_WrCE                  -- Bus to IP write chip enable
--   IP2Bus_Data                  -- IP to Bus data bus
--   IP2Bus_RdAck                 -- IP to Bus read transfer acknowledgement
--   IP2Bus_WrAck                 -- IP to Bus write transfer acknowledgement
--   IP2Bus_Error                 -- IP to Bus error response
--   IP2RFIFO_WrReq               -- IP to RFIFO : IP write request
--   IP2RFIFO_Data                -- IP to RFIFO : IP write data bus
--   RFIFO2IP_WrAck               -- RFIFO to IP : RFIFO write acknowledge
--   RFIFO2IP_AlmostFull          -- RFIFO to IP : RFIFO almost full
--   RFIFO2IP_Full                -- RFIFO to IP : RFIFO full
--   IP2WFIFO_RdReq               -- IP to WFIFO : IP read request
--   WFIFO2IP_Data                -- WFIFO to IP : WFIFO read data
--   WFIFO2IP_RdAck               -- WFIFO to IP : WFIFO read acknowledge
--   WFIFO2IP_AlmostEmpty         -- WFIFO to IP : WFIFO almost empty
--   WFIFO2IP_Empty               -- WFIFO to IP : WFIFO empty
------------------------------------------------------------------------------

entity user_logic is
  generic
  (
    -- ADD USER GENERICS BELOW THIS LINE ---------------
    --USER generics added here
    -- ADD USER GENERICS ABOVE THIS LINE ---------------

    -- DO NOT EDIT BELOW THIS LINE ---------------------
    -- Bus protocol parameters, do not add to or delete
    C_SLV_DWIDTH                   : integer              := 32;
    C_NUM_REG                      : integer              := 1
    -- DO NOT EDIT ABOVE THIS LINE ---------------------
  );
  port
  (
    -- ADD USER PORTS BELOW THIS LINE ------------------
    --USER ports added here
    -- ADD USER PORTS ABOVE THIS LINE ------------------

    -- DO NOT EDIT BELOW THIS LINE ---------------------
    -- Bus protocol ports, do not add to or delete
    Bus2IP_Clk                     : in  std_logic;
    Bus2IP_Reset                   : in  std_logic;
    Bus2IP_Data                    : in  std_logic_vector(0 to C_SLV_DWIDTH-1);
    Bus2IP_BE                      : in  std_logic_vector(0 to C_SLV_DWIDTH/8-1);
    Bus2IP_RdCE                    : in  std_logic_vector(0 to C_NUM_REG-1);
    Bus2IP_WrCE                    : in  std_logic_vector(0 to C_NUM_REG-1);
    IP2Bus_Data                    : out std_logic_vector(0 to C_SLV_DWIDTH-1);
    IP2Bus_RdAck                   : out std_logic;
    IP2Bus_WrAck                   : out std_logic;
    IP2Bus_Error                   : out std_logic;
    IP2RFIFO_WrReq                 : out std_logic;
    IP2RFIFO_Data                  : out std_logic_vector(0 to C_SLV_DWIDTH-1);
    RFIFO2IP_WrAck                 : in  std_logic;
    RFIFO2IP_AlmostFull            : in  std_logic;
    RFIFO2IP_Full                  : in  std_logic;
    IP2WFIFO_RdReq                 : out std_logic;
    WFIFO2IP_Data                  : in  std_logic_vector(0 to C_SLV_DWIDTH-1);
    WFIFO2IP_RdAck                 : in  std_logic;
    WFIFO2IP_AlmostEmpty           : in  std_logic;
    WFIFO2IP_Empty                 : in  std_logic
    -- DO NOT EDIT ABOVE THIS LINE ---------------------
  );

  attribute MAX_FANOUT : string;
  attribute SIGIS : string;

  attribute SIGIS of Bus2IP_Clk    : signal is "CLK";
  attribute SIGIS of Bus2IP_Reset  : signal is "RST";

end entity user_logic;

------------------------------------------------------------------------------
-- Architecture section
------------------------------------------------------------------------------

architecture IMP of user_logic is

  --USER signal declarations added here, as needed for user logic

  ------------------------------------------
  -- Signals for read/write fifo loopback example
  ------------------------------------------
  signal fifo_rdreq_cmb                 : std_logic;
  signal fifo_wrreq_cmb                 : std_logic;
  
  
  -- signal for interfacing the EBCoder
  signal ebcoder_rst, ebcoder_enable, ebcoder_busy: std_logic;
  signal ebcoder_data_in: std_logic_vector(15 downto 0);
  signal ebcoder_data_in_en: std_logic;
  signal ebcoder_out_bytes: std_logic_vector(23 downto 0);
  signal ebcoder_out_enable: std_logic_vector(2 downto 0);
  
  -- signals to control peripheral state
  constant CODE_RESET: std_logic_vector(31 downto 0) := "10101010101010101010101010101010";

  
  type INPUT_STATE is (IDLE, READ_ACK, SAVING);
  signal input_state_curr, input_state_next: INPUT_STATE;
  type OUTPUT_STATE is (IDLE, PROCESSING, WRITING, WAITING_ACK);
  signal output_state_curr, output_state_next: OUTPUT_STATE;

  
  -- clk control stuff
  constant DELAY_CYCLES: integer := 8;
  signal output_delay_counter_next, output_delay_counter_curr: natural range 0 to DELAY_CYCLES;
  signal input_delay_counter_next, input_delay_counter_curr: natural range 0 to DELAY_CYCLES;

begin

  --USER logic implementation added here
  
	coder: entity codificacion_bloques_v1_00_a.EBCoder
		generic map (ROWS => 64, COLS => 64, BITPLANES => 16)
		port map (
			clk => Bus2IP_Clk, rst => ebcoder_rst, clk_en => ebcoder_enable,
			data_in => ebcoder_data_in, data_in_en => ebcoder_data_in_en,
			busy => ebcoder_busy, out_bytes => ebcoder_out_bytes, valid => ebcoder_out_enable);


  ------------------------------------------
  -- Example code to transfer data between read/write fifo
  -- 
  -- Note:
  -- The example code presented here is to show you one way of operating on
  -- the read/write FIFOs provided for you. There's a set of IPIC ports
  -- dedicated to the FIFO operations, beginning with RFIFO2IP_* or IP2RFIFO_*
  -- or WFIFO2IP_* or IP2WFIFO_*. Some FIFO ports are only available when
  -- certain FIFO services are present, s.t. vacancy calculation, etc.
  -- Typically you will need to have a state machine to read data from the
  -- write FIFO or write data to the read FIFO. This code snippet simply
  -- transfer the data from the write FIFO to the read FIFO.
  ------------------------------------------
  
	--process for inputting data from processor to peripheral
	data_input: process (input_state_curr, WFIFO2IP_empty, WFIFO2IP_RdAck, WFIFO2IP_Data, input_delay_counter_curr) is
	begin
		ebcoder_rst				<= '0';
		ebcoder_data_in_en	<= '0';
		ebcoder_data_in		<= (others => '0');
		input_state_next 		<= input_state_curr;
		fifo_rdreq_cmb <= '0';
		input_delay_counter_next <= 0;
		
		case (input_state_curr) is
			when IDLE =>
				if ( WFIFO2IP_empty = '0') then
					fifo_rdreq_cmb		<= '1';
					input_state_next	<= READ_ACK;
				end if;
			when READ_ACK => 
				-- data has been read from the write fifo,
				-- so we can tell the EBCODER
				if ( WFIFO2IP_RdAck = '1' ) then
					input_state_next  <= SAVING;
					input_delay_counter_next <= DELAY_CYCLES - 1;
				end if;
			WHEN SAVING => --maintain for as many cycles as needed by the divisor, to ensure saving
				if (WFIFO2IP_Data = CODE_RESET) then
					ebcoder_rst <= '1';
				else
					ebcoder_data_in_en <= '1';
					ebcoder_data_in <= WFIFO2IP_Data(0 to 15);
				end if;
				if (input_delay_counter_curr = 0) then
					input_state_next <= IDLE;
				else
					input_delay_counter_next <= input_delay_counter_curr - 1;
				end if;
		end case;
	end process;
	
	
	--the structure is:
	-- xxxxxeee aaaaaaaa bbbbbbbb cccccccc
	-- where e is the enable bit of the A, B and C bytes
	IP2RFIFO_Data <= "00000" & ebcoder_out_enable & ebcoder_out_bytes;
	
	--process for outputting data from peripheral to processor
	data_output: process (output_state_curr, RFIFO2IP_full, output_delay_counter_curr, RFIFO2IP_WrAck) is
	begin
		output_delay_counter_next	<= 0;
		output_state_next				<= output_state_curr;
		ebcoder_enable					<= '0';
	
		case (output_state_curr) is
			when IDLE => --advance state only if there is room in the output queue
				if (RFIFO2IP_full = '0') then
					output_state_next <= PROCESSING;
					output_delay_counter_next <= DELAY_CYCLES - 1; --delay 10 cycles to allow for signal propagation before enabling clock
				end if;
			when PROCESSING =>
				ebcoder_enable <= '1';
				if (output_delay_counter_curr = 0) then
					output_state_next <= WRITING;
					output_delay_counter_next <= (DELAY_CYCLES / 2) - 1;
				else
					output_delay_counter_next <= output_delay_counter_curr - 1;
				end if;
			when WRITING =>
				if (output_delay_counter_curr = 0) then
					fifo_wrreq_cmb <= '1';
					output_state_next <= WAITING_ACK;
				else
					output_delay_counter_next <= output_delay_counter_curr - 1;
				end if;
			when WAITING_ACK =>
				if (RFIFO2IP_WrAck = '1') then
					output_state_next <= IDLE;
				end if;
		end case;
	end process;
  
  

  FIFO_CNTL_SM_SEQ : process( Bus2IP_Clk ) is
  begin

    if ( rising_edge(Bus2IP_Clk) ) then
      if ( Bus2IP_Reset = '1' ) then
        IP2WFIFO_RdReq		<= '0';
        IP2RFIFO_WrReq		<= '0';
        output_state_curr	<= IDLE;
		  input_state_curr	<= IDLE;
		  output_delay_counter_curr <= 0;
		  input_delay_counter_curr <= 0;
      else
        IP2WFIFO_RdReq		<= fifo_rdreq_cmb;
        IP2RFIFO_WrReq		<= fifo_wrreq_cmb;
        output_state_curr	<= output_state_next;
		  input_state_curr	<= input_state_next;
		  output_delay_counter_curr <= output_delay_counter_next;
		  input_delay_counter_curr <= input_delay_counter_next;
      end if;
    end if;

  end process FIFO_CNTL_SM_SEQ;


  ------------------------------------------
  -- Example code to drive IP to Bus signals
  ------------------------------------------
  IP2Bus_Data  <= (others => '0');

  IP2Bus_WrAck <= '0';
  IP2Bus_RdAck <= '0';
  IP2Bus_Error <= '0';

end IMP;





--  FIFO_CNTL_SM_COMB : process( WFIFO2IP_empty, WFIFO2IP_RdAck, RFIFO2IP_full, RFIFO2IP_WrAck, fifo_cntl_cs ) is
--  begin
--
--    -- set defaults
--    fifo_rdreq_cmb <= '0';
--    fifo_wrreq_cmb <= '0';
--    fifo_cntl_ns   <= fifo_cntl_cs;
--		
--	 
--
--    case fifo_cntl_cs is
--      when IDLE =>
--        -- data is available in the write fifo and there's space in the read fifo,
--        -- so we can start transfering the data from write fifo to read fifo
--        if ( WFIFO2IP_empty = '0' and RFIFO2IP_full = '0' ) then
--          fifo_rdreq_cmb <= '1';
--          fifo_cntl_ns   <= RD_REQ;
--        end if;
--      when RD_REQ =>
--        -- data has been read from the write fifo,
--        -- so we can write it to the read fifo
--        if ( WFIFO2IP_RdAck = '1' ) then
--          fifo_wrreq_cmb <= '1';
--          fifo_cntl_ns   <= WR_REQ;
--        end if;
--      when WR_REQ =>
--        -- data has been written to the read fifo,
--        -- so data transfer is done
--        if ( RFIFO2IP_WrAck = '1' ) then
--          fifo_cntl_ns <= IDLE;
--        end if;
--      when others =>
--        fifo_cntl_ns <= IDLE;
--    end case;
--
--  end process FIFO_CNTL_SM_COMB;
--
--  FIFO_CNTL_SM_SEQ : process( Bus2IP_Clk ) is
--  begin
--
--    if ( rising_edge(Bus2IP_Clk) ) then
--      if ( Bus2IP_Reset = '1' ) then
--        IP2WFIFO_RdReq <= '0';
--        IP2RFIFO_WrReq <= '0';
--        fifo_cntl_cs   <= IDLE;
--      else
--        IP2WFIFO_RdReq <= fifo_rdreq_cmb;
--        IP2RFIFO_WrReq <= fifo_wrreq_cmb;
--        fifo_cntl_cs   <= fifo_cntl_ns;
--      end if;
--    end if;
--
--  end process FIFO_CNTL_SM_SEQ;