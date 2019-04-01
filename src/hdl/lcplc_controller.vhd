----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 29.03.2019 09:44:10
-- Design Name: 
-- Module Name: lcplc_controller - Behavioral
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
use ieee.NUMERIC_STD.all;
use work.constants.all; --get axi constants from here

entity lcplc_controller is
	Generic (
		--controller axi generics
		CONTROLLER_ADDR_WIDTH	: integer := 32; 
		CONTROLLER_DATA_BYTES	: integer := 4;	--expected to be four
		--lcplc axis generics
		--LCPLC_DATA_BYTES		: integer := 2;
		--LCPLC_OUTPUT_BYTES		: integer := 4;
		--ddr3 axi generics
		--DDR3_AXI_ADDR_WIDTH		: integer := 32;
		--DDR3_AXI_DATA_BYTES		: integer := 4;
		B: integer := 2
	);
	Port (
		--clk and reset for lcplc
		--lcplc_clk, lcplc_resetn: in std_logic;
		-------------------------------------------------
		--CONTROLLER AXI SLAVE INTERFACE
		--c_s_axi_<name> (control slave axi <signal_name>
		-------------------------------------------------
		c_s_axi_clk	, c_s_axi_resetn	: in  std_logic;
		--address read channel
		c_s_axi_araddr		: in  std_logic_vector(CONTROLLER_ADDR_WIDTH - 1 downto 0);
		c_s_axi_arready		: out std_logic;
		c_s_axi_arvalid		: in  std_logic;
		--read data channel
		c_s_axi_rdata		: out std_logic_vector(CONTROLLER_DATA_BYTES*8 - 1 downto 0);
		c_s_axi_rready		: in  std_logic;
		c_s_axi_rresp		: out std_logic_vector(AXI_BRESP_WIDTH - 1 downto 0);
		c_s_axi_rvalid		: out std_logic;
		--address write channel
		c_s_axi_awaddr		: in  std_logic_vector(CONTROLLER_ADDR_WIDTH - 1 downto 0);
		c_s_axi_awready		: out std_logic;
		c_s_axi_awvalid		: in  std_logic;
		--write data channel
		c_s_axi_wdata		: in  std_logic_vector(CONTROLLER_DATA_BYTES*8 - 1 downto 0);
		c_s_axi_wready		: out std_logic;
		c_s_axi_wstrb		: in  std_logic_vector(CONTROLLER_DATA_BYTES - 1 downto 0); --ignored
		c_s_axi_wvalid		: in  std_logic;
		--write response channel
		c_s_axi_bready		: in  std_logic;
		c_s_axi_bresp		: out  std_logic_vector(AXI_BRESP_WIDTH - 1 downto 0);
		c_s_axi_bvalid		: out std_logic
		-------------------------------------------------
		--DDR AXI MASTER INTERFACE
		--d_m_axi_<name> (lcplc master axi <signal_name>)
		-------------------------------------------------
		--d_m_axi_clk	, d_m_axi_resetn	: in  std_logic;
		--address write channel
		--d_m_axi_awaddr		: out std_logic_vector(DDR3_AXI_ADDR_WIDTH - 1 downto 0);
		--d_m_axi_awlen		: out std_logic_vector(AXI_LEN_WIDTH - 1 downto 0);
		--d_m_axi_awsize		: out std_logic_vector(AXI_SIZE_WIDTH - 1 downto 0);
		--d_m_axi_awburst		: out std_logic_vector(AXI_BURST_WIDTH - 1 downto 0);
		--d_m_axi_awlock		: out std_logic_vector(AXI_LOCK_WIDTH - 1 downto 0);
		--d_m_axi_awcache		: out std_logic_vector(AXI_CACHE_WIDTH - 1 downto 0);
		--d_m_axi_awprot		: out std_logic_vector(AXI_PROT_WIDTH - 1 downto 0);
		--d_m_axi_awqos		: out std_logic_vector(AXI_QOS_WIDTH - 1 downto 0);
		--d_m_axi_awvalid		: out std_logic;
		--d_m_axi_awready		: in  std_logic;
		----data write channel
		--d_m_axi_wdata		: out std_logic_vector(DDR3_AXI_DATA_BYTES*8 - 1 downto 0);
		--d_m_axi_wstrb		: out std_logic_vector(DDR3_AXI_DATA_BYTES - 1 downto 0);
		--d_m_axi_wlast		: out std_logic;
		--d_m_axi_wvalid		: out std_logic;
		--d_m_axi_wready		: in  std_logic;
		----write response channel
		--d_m_axi_bresp		: in  std_logic_vector(AXI_BRESP_WIDTH - 1 downto 0);
		--d_m_axi_bvalid		: in  std_logic;
		--d_m_axi_bready		: out std_logic;
		----address read channel
		--d_m_axi_araddr		: out std_logic_vector(DDR3_AXI_ADDR_WIDTH - 1 downto 0);
		--d_m_axi_arlen		: out std_logic_vector(AXI_LEN_WIDTH - 1 downto 0);
		--d_m_axi_arsize		: out std_logic_vector(AXI_SIZE_WIDTH - 1 downto 0);
		--d_m_axi_arburst		: out std_logic_vector(AXI_BURST_WIDTH - 1 downto 0);
		--d_m_axi_arlock		: out std_logic_vector(AXI_LOCK_WIDTH - 1 downto 0);
		--d_m_axi_arcache		: out std_logic_vector(AXI_CACHE_WIDTH - 1 downto 0);
		--d_m_axi_arprot		: out std_logic_vector(AXI_PROT_WIDTH - 1 downto 0);
		--d_m_axi_arqos		: out std_logic_vector(AXI_QOS_WIDTH - 1 downto 0);
		--d_m_axi_arvalid		: out std_logic;
		--d_m_axi_arready		: in  std_logic;
		----read data channel
		--d_m_axi_rdata		: in  std_logic_vector(DDR3_AXI_DATA_BYTES*8 - 1 downto 0);
		--d_m_axi_rresp		: in  std_logic_vector(AXI_BRESP_WIDTH - 1 downto 0);
		--d_m_axi_rlast		: in  std_logic;
		--d_m_axi_rvalid		: in  std_logic;
		--d_m_axi_rready		: out std_logic
	);

end lcplc_controller;

architecture Behavioral of lcplc_controller is
	-------------------------------------------------
	--CONTROLLER AXI SLAVE INTERFACE
	-------------------------------------------------
	--read/write registers (local addresses)
	constant C_S_AXI_REG_CTRLRG_LOCALADDR: integer := 0;	--control register
	constant C_S_AXI_REG_STADDR_LOCALADDR: integer := 4;	--addr start of raw data
	constant C_S_AXI_REG_BYTENO_LOCALADDR: integer := 8;	--bytes per sample (1, 2, 4, ...) (always less than DDR3_BYTES)
	constant C_S_AXI_REG_SMPLNO_LOCALADDR: integer := 12;	--number of samples in image (x-dim)
	constant C_S_AXI_REG_LINENO_LOCALADDR: integer := 16;	--number of lines in image   (y-dim)
	constant C_S_AXI_REG_BANDNO_LOCALADDR: integer := 20;	--number of bands in image	 (z-dim)
	constant C_S_AXI_REG_TGADDR_LOCALADDR: integer := 24;   --addr start of output data
	--read only status registers (local addresses)
	constant C_S_AXI_REG_STATUS_LOCALADDR: integer := 128;  --status of lcplc
	constant C_S_AXI_REG_INBYTE_LOCALADDR: integer := 132;	--number of bytes read from mem so far
	constant C_S_AXI_REG_OUTBYT_LOCALADDR: integer := 136;  --number of bytes output so far
	
	signal s_axi_reg_ctrlrg, s_axi_reg_staddr, s_axi_reg_byteno, 
		s_axi_reg_smplno, s_axi_reg_lineno, s_axi_reg_bandno,
		s_axi_reg_tgaddr,
		s_axi_reg_status, s_axi_reg_inbyte, s_axi_reg_outbyt: std_logic_vector(CONTROLLER_DATA_BYTES*8 - 1 downto 0);

	signal s_axi_reg_wren, s_axi_reg_readen: std_logic; 

	type control_slave_write_state_t is (CSW_IDLE, CSW_AWAIT_ADDR_OR_DATA, CSW_AWAIT_ADDR, CSW_AWAIT_DATA, CSW_PERFORM_OP, CSW_SEND_RESPONSE);
	signal c_s_w_state_curr, c_s_w_state_next: control_slave_write_state_t;

	signal c_s_axi_writeaddr_curr, c_s_axi_writeaddr_next: std_logic_vector(CONTROLLER_ADDR_WIDTH - 1 downto 0);
	signal c_s_axi_writedata_curr, c_s_axi_writedata_next: std_logic_vector(CONTROLLER_DATA_BYTES*8 - 1 downto 0);

	signal local_c_s_axi_writeaddr: integer range 0 to 255;


	type control_slave_read_state_t is (CSR_IDLE, CSR_AWAIT_ADDR, CSR_SEND_DATA);
	signal c_s_r_state_curr, c_s_r_state_next: control_slave_read_state_t;

	signal c_s_axi_readdata: std_logic_vector(CONTROLLER_DATA_BYTES*8 - 1 downto 0);

	signal local_c_s_axi_readaddr: integer range 0 to 255;

	---------------------------------------------------
	--LCPLC AXIS MASTER INTERFACE
	--l_m_axis_<name> (lcplc master axis <signal_name>)
	---------------------------------------------------
	--write data channel
	--signal l_m_axis_wvalid	: std_logic;
	--signal l_m_axis_wready	: std_logic;
	--signal l_m_axis_wdata	: std_logic_vector(LCPLC_DATA_BYTES*8 - 1 downto 0);
	--signal l_m_axis_wlast_r	: std_logic;
	--signal l_m_axis_wlast_s	: std_logic;
	--signal l_m_axis_wlast_b	: std_logic;
	--signal l_m_axis_wlast_i	: std_logic;
	----read data channel
	--signal l_m_axis_rdata		: std_logic_vector(LCPLC_OUTPUT_BYTES*8 - 1 downto 0);
	--signal l_m_axis_rvalid		: std_logic;
	--signal l_m_axis_rready		: std_logic;
	--signal l_m_axis_rlast		: std_logic;
	

	 
begin

	------------------------------
	--CONTROLLER WRITE PROCESSES--
	------------------------------
	control_write_seq: process(c_s_axi_clk)
	begin
		if rising_edge(c_s_axi_clk) then
			if c_s_axi_resetn = '0' then
				c_s_w_state_curr <= CSW_IDLE;
			else
				c_s_w_state_curr <= c_s_w_state_next;
				c_s_axi_writeaddr_curr <= c_s_axi_writeaddr_next;
				c_s_axi_writedata_curr <= c_s_axi_writedata_next;

				if s_axi_reg_wren = '1' then
					if local_c_s_axi_writeaddr = C_S_AXI_REG_CTRLRG_LOCALADDR then
						s_axi_reg_ctrlrg <= c_s_axi_writedata_curr;
					elsif local_c_s_axi_writeaddr = C_S_AXI_REG_STADDR_LOCALADDR then
						s_axi_reg_staddr <= c_s_axi_writedata_curr;
					elsif local_c_s_axi_writeaddr = C_S_AXI_REG_BYTENO_LOCALADDR then
						s_axi_reg_byteno <= c_s_axi_writedata_curr;
					elsif local_c_s_axi_writeaddr = C_S_AXI_REG_SMPLNO_LOCALADDR then
						s_axi_reg_smplno <= c_s_axi_writedata_curr;
					elsif local_c_s_axi_writeaddr = C_S_AXI_REG_LINENO_LOCALADDR then
						s_axi_reg_lineno <= c_s_axi_writedata_curr;
					elsif local_c_s_axi_writeaddr = C_S_AXI_REG_BANDNO_LOCALADDR then
						s_axi_reg_bandno <= c_s_axi_writedata_curr;
					elsif local_c_s_axi_writeaddr = C_S_AXI_REG_TGADDR_LOCALADDR then
						s_axi_reg_tgaddr <= c_s_axi_writedata_curr;
					end if;
				end if;
			end if;
		end if;
	end process;

	local_c_s_axi_writeaddr <= to_integer(unsigned(c_s_axi_writeaddr_curr(7 downto 0)));

	control_write_comb: process(c_s_w_state_curr,
		c_s_axi_writeaddr_curr, c_s_axi_writedata_curr, c_s_axi_awvalid, c_s_axi_wvalid,
		c_s_axi_awaddr, c_s_axi_wdata, c_s_axi_bready)
	begin
		--keep old values unless changed
		c_s_w_state_next <= c_s_w_state_curr;
		c_s_axi_awready <= '0';
		c_s_axi_wready  <= '0';
		c_s_axi_writeaddr_next <= c_s_axi_writeaddr_curr;
		c_s_axi_writedata_next <= c_s_axi_writedata_curr;
		s_axi_reg_wren <= '0';
		c_s_axi_bresp <= AXI_RESP_OKAY;
		c_s_axi_bvalid <= '0';

		if c_s_w_state_curr = CSW_IDLE then
			--use this state as reset to keep AXI signals low
			--during resets so as to not introduce phantom transactions
			c_s_w_state_next <= CSW_AWAIT_ADDR_OR_DATA;
		elsif c_s_w_state_curr = CSW_AWAIT_ADDR_OR_DATA then
			--await either address or data.
			c_s_axi_awready <= '1';
			c_s_axi_wready  <= '1';
			if c_s_axi_awvalid = '1' and c_s_axi_wvalid = '1' then
				c_s_axi_writeaddr_next <= c_s_axi_awaddr;
				c_s_axi_writedata_next <= c_s_axi_wdata;
				c_s_w_state_next <= CSW_PERFORM_OP;
			elsif c_s_axi_awvalid = '1' then
				c_s_axi_writeaddr_next <= c_s_axi_awaddr;
				c_s_w_state_next <= CSW_AWAIT_DATA;
			elsif c_s_axi_wvalid = '1' then
				c_s_axi_writedata_next <= c_s_axi_wdata;
				c_s_w_state_next <= CSW_AWAIT_ADDR;
			end if;
		elsif c_s_w_state_curr = CSW_AWAIT_ADDR then
			--await for address on bus
			c_s_axi_awready <= '1';
			if c_s_axi_awvalid = '1' then
				c_s_axi_writeaddr_next <= c_s_axi_awaddr;
				c_s_w_state_next <= CSW_PERFORM_OP;
			end if;
		elsif c_s_w_state_curr = CSW_AWAIT_DATA then
			--await for data on bus
			c_s_axi_wready <= '1';
			if c_s_axi_wvalid = '1' then
				c_s_axi_writedata_next <= c_s_axi_wdata;
				c_s_w_state_next <= CSW_PERFORM_OP;
			end if;
		elsif c_s_w_state_curr = CSW_PERFORM_OP then
			--enable reg write (which will be done in one cycle)
			s_axi_reg_wren <= '1';
			c_s_w_state_next <= CSW_SEND_RESPONSE;
		elsif c_s_w_state_curr = CSW_SEND_RESPONSE then
			--assert bresp signals and wait for master ack
			c_s_axi_bresp <= AXI_RESP_OKAY;
			c_s_axi_bvalid <= '1';
			if c_s_axi_bready = '1' then
				c_s_w_state_next <= CSW_AWAIT_ADDR_OR_DATA;
			end if;
		end if;
	end process;

	-----------------------------
	--CONTROLLER READ PROCESSES--
	-----------------------------
	control_read_seq: process(c_s_axi_clk)
	begin
		if rising_edge(c_s_axi_clk) then
			if c_s_axi_resetn = '0' then
				c_s_r_state_curr <= CSR_IDLE;
			else
				c_s_r_state_curr <= c_s_r_state_next;
				if s_axi_reg_readen = '1' then
					if local_c_s_axi_readaddr = C_S_AXI_REG_CTRLRG_LOCALADDR then
						c_s_axi_readdata <= s_axi_reg_ctrlrg;
					elsif local_c_s_axi_readaddr = C_S_AXI_REG_STADDR_LOCALADDR then
						c_s_axi_readdata <= s_axi_reg_staddr;
					elsif local_c_s_axi_readaddr = C_S_AXI_REG_BYTENO_LOCALADDR then
						c_s_axi_readdata <= s_axi_reg_byteno;
					elsif local_c_s_axi_readaddr = C_S_AXI_REG_SMPLNO_LOCALADDR then
						c_s_axi_readdata <= s_axi_reg_smplno;
					elsif local_c_s_axi_readaddr = C_S_AXI_REG_LINENO_LOCALADDR then
						c_s_axi_readdata <= s_axi_reg_lineno;
					elsif local_c_s_axi_readaddr = C_S_AXI_REG_BANDNO_LOCALADDR then
						c_s_axi_readdata <= s_axi_reg_bandno;
					elsif local_c_s_axi_readaddr = C_S_AXI_REG_TGADDR_LOCALADDR then
						c_s_axi_readdata <= s_axi_reg_tgaddr;
					elsif local_c_s_axi_readaddr = C_S_AXI_REG_STATUS_LOCALADDR then
						c_s_axi_readdata <= s_axi_reg_status;
					elsif local_c_s_axi_readaddr = C_S_AXI_REG_INBYTE_LOCALADDR then
						c_s_axi_readdata <= s_axi_reg_inbyte;
					elsif local_c_s_axi_readaddr = C_S_AXI_REG_OUTBYT_LOCALADDR then
						c_s_axi_readdata <= s_axi_reg_outbyt;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	s_axi_reg_status <= x"cafebabe";
	s_axi_reg_inbyte <= x"deadbeef";
	s_axi_reg_outbyt <= x"01010101";

	local_c_s_axi_readaddr <= to_integer(unsigned(c_s_axi_araddr(7 downto 0)));

	control_read_comb: process(c_s_r_state_curr,
		c_s_axi_arvalid, c_s_axi_rready)
	begin
		c_s_r_state_next <= c_s_r_state_curr;
		c_s_axi_arready <= '0';
		s_axi_reg_readen <= '0';
		c_s_axi_rvalid <= '0';
		c_s_axi_rresp <= AXI_RESP_OKAY;

		if c_s_r_state_curr = CSR_IDLE then
			c_s_r_state_next <= CSR_AWAIT_ADDR;
		elsif c_s_r_state_curr = CSR_AWAIT_ADDR then
			c_s_axi_arready <= '1';
			if c_s_axi_arvalid = '1' then
				s_axi_reg_readen <= '1';
				c_s_r_state_next <= CSR_SEND_DATA;
			end if;
		elsif c_s_r_state_curr = CSR_SEND_DATA then
			c_s_axi_rvalid <= '1';
			c_s_axi_rresp <= AXI_RESP_OKAY;
			if c_s_axi_rready = '1' then
				--done, wait for next transaction
				c_s_r_state_next <= CSR_AWAIT_ADDR;
			end if;
		end if;
	end process;
	--could be directly routed but then we'd have a mux in front of the bus, so this way is better
	c_s_axi_rdata <= c_s_axi_readdata; 







	
	--a process looks at the control register and, when the adequante sequence is triggered, starts moving through the compression process
	--asserts start/stop signals for other processes, and then waits for end signals from other processes, indicating this in the status register
	--that can be read from the controller
	--should this have some sort of pause/reset?? probably would be useful
	
	--another process waits for the start signal to be asserted and starts reading from ddr and sending results to lcplc. Maybe this would be interesting to do in bursts
	--so that we can ask for, lets say, 256 bytes and put them all as fast as possible in a queue, and then do the same when the queue is almost empty
	
	--another process waits for data to be output (after the module has started). 
	--Maybe also wait for a certain amount (or a termination to be seen) before initiating a burst with many beats 
	--when finished, asserts end of compression so that the main process can be reset  


end Behavioral;
