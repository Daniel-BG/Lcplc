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
		CONTROLLER_ADDR_WIDTH		: integer := 32; 
		CONTROLLER_DATA_BYTES_LOG	: integer := 2;	--expected to be four
		--lcplc axis generics -- propagated to DDR3
		LCPLC_DATA_BYTES_LOG		: integer := 1;
		LCPLC_OUTPUT_BYTES_LOG		: integer := 2; 
		LCPLC_MAX_BLOCK_SAMPLE_LOG	: integer := 4;
		LCPLC_MAX_BLOCK_LINE_LOG	: integer := 4;
		LCPLC_MAX_IMAGE_SAMPLE_LOG	: integer := 12;
		LCPLC_MAX_IMAGE_LINE_LOG	: integer := 12;
		LCPLC_MAX_IMAGE_BAND_LOG	: integer := 12;
		LCPLC_ALPHA_WIDTH			: integer := 10;
		LCPLC_ACCUMULATOR_WINDOW	: integer := 32;	
		LCPLC_UPSHIFT				: integer := 1;
		LCPLC_DOWNSHIFT				: integer := 1;
		LCPLC_THRESHOLD				: std_logic_vector := "100000000000000";
		--ddr3 axi generics
		DDR3_AXI_ADDR_WIDTH			: integer := 32
	);
	Port (
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
		c_s_axi_rdata		: out std_logic_vector((2**CONTROLLER_DATA_BYTES_LOG)*8 - 1 downto 0);
		c_s_axi_rready		: in  std_logic;
		c_s_axi_rresp		: out std_logic_vector(AXI_BRESP_WIDTH - 1 downto 0);
		c_s_axi_rvalid		: out std_logic;
		--address write channel
		c_s_axi_awaddr		: in  std_logic_vector(CONTROLLER_ADDR_WIDTH - 1 downto 0);
		c_s_axi_awready		: out std_logic;
		c_s_axi_awvalid		: in  std_logic;
		--write data channel
		c_s_axi_wdata		: in  std_logic_vector((2**CONTROLLER_DATA_BYTES_LOG)*8 - 1 downto 0);
		c_s_axi_wready		: out std_logic;
		c_s_axi_wstrb		: in  std_logic_vector((2**CONTROLLER_DATA_BYTES_LOG) - 1 downto 0); --ignored
		c_s_axi_wvalid		: in  std_logic;
		--write response channel
		c_s_axi_bready		: in  std_logic;
		c_s_axi_bresp		: out std_logic_vector(AXI_BRESP_WIDTH - 1 downto 0);
		c_s_axi_bvalid		: out std_logic;
		-------------------------------------------------
		--DDR AXI MASTER INTERFACE
		--d_m_axi_<name> (lcplc master axi <signal_name>)
		-------------------------------------------------
		d_m_axi_clk	, d_m_axi_resetn	: in  std_logic;
		--address write channel
		d_m_axi_awaddr		: out std_logic_vector(DDR3_AXI_ADDR_WIDTH - 1 downto 0);
		d_m_axi_awlen		: out std_logic_vector(AXI_LEN_WIDTH - 1 downto 0);
		d_m_axi_awsize		: out std_logic_vector(AXI_SIZE_WIDTH - 1 downto 0);
		d_m_axi_awburst		: out std_logic_vector(AXI_BURST_WIDTH - 1 downto 0);
		d_m_axi_awlock		: out std_logic;
		d_m_axi_awcache		: out std_logic_vector(AXI_CACHE_WIDTH - 1 downto 0);
		d_m_axi_awprot		: out std_logic_vector(AXI_PROT_WIDTH - 1 downto 0);
		d_m_axi_awqos		: out std_logic_vector(AXI_QOS_WIDTH - 1 downto 0);
		d_m_axi_awvalid		: out std_logic;
		d_m_axi_awready		: in  std_logic;
		--data write channel
		d_m_axi_wdata		: out std_logic_vector((2**LCPLC_OUTPUT_BYTES_LOG)*8 - 1 downto 0);
		d_m_axi_wstrb		: out std_logic_vector((2**LCPLC_OUTPUT_BYTES_LOG) - 1 downto 0);
		d_m_axi_wlast		: out std_logic;
		d_m_axi_wvalid		: out std_logic;
		d_m_axi_wready		: in  std_logic;
		--write response channel
		d_m_axi_bresp		: in  std_logic_vector(AXI_BRESP_WIDTH - 1 downto 0);
		d_m_axi_bvalid		: in  std_logic;
		d_m_axi_bready		: out std_logic;
		--address read channel
		d_m_axi_araddr		: out std_logic_vector(DDR3_AXI_ADDR_WIDTH - 1 downto 0);
		d_m_axi_arlen		: out std_logic_vector(AXI_LEN_WIDTH - 1 downto 0);
		d_m_axi_arsize		: out std_logic_vector(AXI_SIZE_WIDTH - 1 downto 0);
		d_m_axi_arburst		: out std_logic_vector(AXI_BURST_WIDTH - 1 downto 0);
		d_m_axi_arlock		: out std_logic;
		d_m_axi_arcache		: out std_logic_vector(AXI_CACHE_WIDTH - 1 downto 0);
		d_m_axi_arprot		: out std_logic_vector(AXI_PROT_WIDTH - 1 downto 0);
		d_m_axi_arqos		: out std_logic_vector(AXI_QOS_WIDTH - 1 downto 0);
		d_m_axi_arvalid		: out std_logic;
		d_m_axi_arready		: in  std_logic;
		--read data channel
		d_m_axi_rdata		: in  std_logic_vector((2**LCPLC_DATA_BYTES_LOG)*8 - 1 downto 0);
		d_m_axi_rresp		: in  std_logic_vector(AXI_BRESP_WIDTH - 1 downto 0);
		d_m_axi_rlast		: in  std_logic;
		d_m_axi_rvalid		: in  std_logic;
		d_m_axi_rready		: out std_logic
	);

end lcplc_controller;

architecture Behavioral of lcplc_controller is
	-------------------------------------------------
	--CONTROLLER AXI SLAVE INTERFACE
	-------------------------------------------------
	--read/write registers (local addresses)
	constant C_S_AXI_REG_CTRLRG_LOCALADDR: integer := 0;	--control register
	constant C_S_AXI_REG_STADDR_LOCALADDR: integer := 4;	--addr start of raw data
	constant C_S_AXI_REG_SMPLWI_LOCALADDR: integer := 8;	--width of samples (1, 2, 4, ...) (always less than DDR3_BYTES)
	constant C_S_AXI_REG_BYTENO_LOCALADDR: integer := 12;	--total bytes to be read (BYTES, not samples)
	constant C_S_AXI_REG_SMPLNO_LOCALADDR: integer := 16;	--number of samples in image (x-dim)
	constant C_S_AXI_REG_LINENO_LOCALADDR: integer := 20;	--number of lines in image   (y-dim)
	constant C_S_AXI_REG_BANDNO_LOCALADDR: integer := 24;	--number of bands in image	 (z-dim)
	constant C_S_AXI_REG_TGADDR_LOCALADDR: integer := 28;   --addr start of output data
	constant C_S_AXI_REG_BCKSMP_LOCALADDR: integer := 32; 	--number of samples in block
	constant C_S_AXI_REG_BCKLIN_LOCALADDR: integer := 36;	--number of lines in block
	--read only status registers (local addresses)
	constant C_S_AXI_REG_STATUS_LOCALADDR: integer := 128;  --status of lcplc
	constant C_S_AXI_REG_INBYTE_LOCALADDR: integer := 132;	--number of bytes read from mem so far
	constant C_S_AXI_REG_OUTBYT_LOCALADDR: integer := 136;  --number of bytes output so far
	--codes for running the core by writing to status registe
	constant CONTROL_CODE_RESET		: std_logic_vector((2**CONTROLLER_DATA_BYTES_LOG)*8 - 1 downto 0) := std_logic_vector(to_unsigned(127, (2**CONTROLLER_DATA_BYTES_LOG)*8));
	constant CONTROL_CODE_START_0	: std_logic_vector((2**CONTROLLER_DATA_BYTES_LOG)*8 - 1 downto 0) := std_logic_vector(to_unsigned(62, (2**CONTROLLER_DATA_BYTES_LOG)*8));
	constant CONTROL_CODE_START_1	: std_logic_vector((2**CONTROLLER_DATA_BYTES_LOG)*8 - 1 downto 0) := std_logic_vector(to_unsigned(63, (2**CONTROLLER_DATA_BYTES_LOG)*8));

	signal s_axi_reg_ctrlrg, s_axi_reg_staddr, s_axi_reg_smplwi,
		s_axi_reg_byteno, s_axi_reg_smplno, s_axi_reg_lineno, s_axi_reg_bandno,
		s_axi_reg_tgaddr,
		s_axi_reg_bcksmp, s_axi_reg_bcklin,
		s_axi_reg_status, s_axi_reg_inbyte, s_axi_reg_outbyt,
		s_axi_reg_inbyte_next, s_axi_reg_outbyt_next: std_logic_vector((2**CONTROLLER_DATA_BYTES_LOG)*8 - 1 downto 0);


	signal s_axi_reg_wren, s_axi_reg_readen: std_logic; 

	--control registers write state and signals
	type control_slave_write_state_t is (CSW_IDLE, CSW_AWAIT_ADDR_OR_DATA, CSW_AWAIT_ADDR, CSW_AWAIT_DATA, CSW_PERFORM_OP, CSW_SEND_RESPONSE);
	signal c_s_w_state_curr, c_s_w_state_next: control_slave_write_state_t;

	signal c_s_axi_writeaddr_curr, c_s_axi_writeaddr_next: std_logic_vector(CONTROLLER_ADDR_WIDTH - 1 downto 0);
	signal c_s_axi_writedata_curr, c_s_axi_writedata_next: std_logic_vector((2**CONTROLLER_DATA_BYTES_LOG)*8 - 1 downto 0);

	signal local_c_s_axi_writeaddr: integer range 0 to 255;

	--control registers read state and signals
	type control_slave_read_state_t is (CSR_IDLE, CSR_AWAIT_ADDR, CSR_SEND_DATA);
	signal c_s_r_state_curr, c_s_r_state_next: control_slave_read_state_t;

	signal c_s_axi_readdata: std_logic_vector((2**CONTROLLER_DATA_BYTES_LOG)*8 - 1 downto 0);

	signal local_c_s_axi_readaddr: integer range 0 to 255;

	--control state machine and control signals for other processes
	type control_main_state_t is (CONTROL_IDLE, CONTROL_RESET, CONTROL_WAIT_START_1, CONTROL_START, CONTROL_END);
	signal control_main_state_curr, control_main_state_next: control_main_state_t;

	signal control_input_transfer_enable, control_output_transfer_enable: std_logic;
	signal control_input_transfer_done, control_output_transfer_done: std_logic;
	signal control_input_reset, control_output_reset: std_logic;
	signal control_input_idle, control_output_idle: std_logic;

	--ddr read states
	type ddr_read_state_t is (DDR_READ_IDLE, DDR_READ_REQUEST, DDR_READ_TRANSFER);
	signal ddr_read_state_curr, ddr_read_state_next: ddr_read_state_t;

	signal ddr_read_bytes_remaining_next, ddr_read_bytes_remaining_curr: std_logic_vector((2**CONTROLLER_DATA_BYTES_LOG)*8 - 1 downto 0);
	signal ddr_read_addr_next, ddr_read_addr_curr: std_logic_vector(DDR3_AXI_ADDR_WIDTH - 1 downto 0);

	signal ififo_rst: std_logic;
	signal ififo_input_valid, ififo_input_ready, ififo_output_ready, ififo_output_valid: std_logic;
	signal ififo_input_data, ififo_output_data: std_logic_vector((2**LCPLC_DATA_BYTES_LOG)*8 - 1 downto 0);

	--ddr write states
	type ddr_write_state_t is (DDR_WRITE_IDLE, DDR_WRITE_REQUEST, DDR_WRITE_TRANSFER, DDR_WRITE_TRANSFER_NOSTRB, DDR_WRITE_RESPONSE, DDR_WRITE_LAST_RESPONSE, DDR_WRITE_FINISH);
	signal ddr_write_state_curr, ddr_write_state_next: ddr_write_state_t;
	
	signal ddr_write_addr_curr, ddr_write_addr_next: std_logic_vector(DDR3_AXI_ADDR_WIDTH - 1 downto 0);
	signal ddr_write_transactions_left_curr, ddr_write_transactions_left_next: std_logic_vector(AXI_LEN_WIDTH - 1 downto 0);

	---------------------------------------------------
	--LCPLC SIGNALS
	---------------------------------------------------
	signal lcplc_clk, lcplc_rst: std_logic;

	signal core_input_data: std_logic_vector((2**LCPLC_DATA_BYTES_LOG)*8 - 1 downto 0);
	signal core_input_last_r, core_input_last_s, core_input_last_b, core_input_last_i: std_logic;
	signal core_input_ready, core_input_valid: std_logic;

	signal core_output_data: std_logic_vector((2**LCPLC_OUTPUT_BYTES_LOG)*8 - 1 downto 0);
	signal core_output_ready, core_output_valid: std_logic;
	signal core_output_last: std_logic;
	 
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
					elsif local_c_s_axi_writeaddr = C_S_AXI_REG_SMPLWI_LOCALADDR then
						s_axi_reg_smplwi <= c_s_axi_writedata_curr;
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
					elsif local_c_s_axi_writeaddr = C_S_AXI_REG_BCKSMP_LOCALADDR then
						s_axi_reg_bcksmp <= c_s_axi_writedata_curr;
					elsif local_c_s_axi_writeaddr = C_S_AXI_REG_BCKLIN_LOCALADDR then
						s_axi_reg_bcklin <= c_s_axi_writedata_curr;
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
					elsif local_c_s_axi_readaddr = C_S_AXI_REG_SMPLWI_LOCALADDR then
						c_s_axi_readdata <= s_axi_reg_smplwi;
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
					elsif local_c_s_axi_readaddr = C_S_AXI_REG_BCKSMP_LOCALADDR then
						c_s_axi_readdata <= s_axi_reg_bcksmp;
					elsif local_c_s_axi_readaddr = C_S_AXI_REG_BCKLIN_LOCALADDR then
						c_s_axi_readdata <= s_axi_reg_bcklin;
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


	---------------------------
	--CONTROLLER MAIN PROCESS--
	---------------------------
	controller_main_seq: process(c_s_axi_clk)
	begin
		if rising_edge(c_s_axi_clk) then
			if c_s_axi_resetn = '0' then
				control_main_state_curr <= CONTROL_IDLE;
			else
				control_main_state_curr <= control_main_state_next;
			end if;
		end if;
	end process;


	controller_main_comb: process(control_main_state_curr, s_axi_reg_ctrlrg, 
		control_input_transfer_done, control_output_transfer_done, control_input_idle, control_output_idle)
	begin
		control_main_state_next <= control_main_state_curr;
		lcplc_rst <= '0';
		control_input_transfer_enable	<= '0';
		control_output_transfer_enable	<= '0';
		control_input_reset    <= '0';
		control_output_reset   <= '0';
		s_axi_reg_status <= (others => '0');

		if control_main_state_curr = CONTROL_IDLE then
			s_axi_reg_status <= x"00000001";
			if s_axi_reg_ctrlrg = CONTROL_CODE_RESET then
				control_main_state_next <= CONTROL_RESET;
			elsif s_axi_reg_ctrlrg = CONTROL_CODE_START_0 then
				control_main_state_next <= CONTROL_WAIT_START_1;
			end if;
		elsif control_main_state_curr = CONTROL_RESET then
			s_axi_reg_status <= x"00000010";
			lcplc_rst <= '1';
			--get out of reset state
			if s_axi_reg_ctrlrg /= CONTROL_CODE_RESET then
				control_main_state_next <= CONTROL_IDLE;
			end if;
		elsif control_main_state_curr = CONTROL_WAIT_START_1 then
			s_axi_reg_status <= x"00000100";
			if s_axi_reg_ctrlrg = CONTROL_CODE_START_0 then
				--stay here
			elsif s_axi_reg_ctrlrg = CONTROL_CODE_START_1 then
				control_main_state_next <= CONTROL_START;
			else
				--go back to idle, start sequence was wrong
				control_main_state_next <= CONTROL_IDLE;
			end if;
		elsif control_main_state_curr = CONTROL_START then
			s_axi_reg_status <= x"00001000";
			control_input_transfer_enable	<= '1';
			control_output_transfer_enable	<= '1';
			if control_input_transfer_done = '1' and control_output_transfer_done = '1' then
				control_main_state_next <= CONTROL_END;
			end if;
		elsif control_main_state_curr = CONTROL_END then
			s_axi_reg_status <= x"00010000";
			control_input_reset    <= '1';
			control_output_reset   <= '1';
			if control_input_idle = '1' and control_output_idle = '1' then
				control_main_state_next <= CONTROL_IDLE;
			end if;
		end if;
	end process;



	-------------------------------
	--DDR TO CORE INPUT PROCESSES--
	-------------------------------
	ddr_read_seq: process(d_m_axi_clk)
	begin
		if rising_edge(d_m_axi_clk) then
			if d_m_axi_resetn = '0' then
				ddr_read_state_curr <= DDR_READ_IDLE;
				s_axi_reg_inbyte	<= (others => '0');
			else
				ddr_read_state_curr <= ddr_read_state_next;
				ddr_read_bytes_remaining_curr <= ddr_read_bytes_remaining_next;
				ddr_read_addr_curr <= ddr_read_addr_next;
				s_axi_reg_inbyte <= s_axi_reg_inbyte_next;
			end if;
		end if;
	end process;


	--fixed AXI signals
	d_m_axi_arsize	<= std_logic_vector(to_unsigned(LCPLC_DATA_BYTES_LOG, d_m_axi_arsize'length));
	d_m_axi_arburst	<= AXI_BURST_INCR;
	d_m_axi_arlock  <= AXI_LOCK_UNLOCKED;
	d_m_axi_arcache <= AXI_CACHE_NORMAL_NONCACHE_NONBUFF;
	d_m_axi_arprot  <= AXI_PROT_UNPRIVILEDGED_NONSECURE_DATA;
	d_m_axi_arqos   <= AXI_QOS_EIGHT;
	d_m_axi_araddr	<= ddr_read_addr_curr;
	--end fixed AXI signals
	ddr_read_comb: process(ddr_read_state_curr, 
		ddr_read_bytes_remaining_curr, ddr_read_addr_curr,
		control_input_transfer_enable, control_input_reset,
		s_axi_reg_byteno, s_axi_reg_staddr, s_axi_reg_inbyte,
		d_m_axi_arready, d_m_axi_rvalid, d_m_axi_rlast, ififo_input_ready)
	begin
		--control signals defaults
		ddr_read_state_next <= ddr_read_state_curr;
		control_input_transfer_done <= '0';
		control_input_idle <= '0';
		ddr_read_bytes_remaining_next <= ddr_read_bytes_remaining_curr;
		ddr_read_addr_next <= ddr_read_addr_curr;
		--axi defaults
		d_m_axi_arvalid	<= '0';
		d_m_axi_arlen	<= (others => '0');
		d_m_axi_rready 	<= '0';
		--
		ififo_input_valid <= '0';
		--
		s_axi_reg_inbyte_next <= s_axi_reg_inbyte;

		if ddr_read_state_curr = DDR_READ_IDLE then
			control_input_idle <= '1';
			--wait for central control to enable us
			if control_input_transfer_enable = '1' then
				ddr_read_state_next <= DDR_READ_REQUEST;
				ddr_read_bytes_remaining_next <= s_axi_reg_byteno;
				ddr_read_addr_next <= s_axi_reg_staddr;
			end if;
		elsif ddr_read_state_curr = DDR_READ_REQUEST then
			--if we still have more than the max transaction of bytes left, perform a transaction
			if ddr_read_bytes_remaining_curr(ddr_read_bytes_remaining_curr'high downto AXI_LEN_WIDTH + LCPLC_DATA_BYTES_LOG)
					/= (ddr_read_bytes_remaining_curr'high downto AXI_LEN_WIDTH + LCPLC_DATA_BYTES_LOG => '0') then
				d_m_axi_arvalid 		<= '1';
				d_m_axi_arlen 			<= (others => '1');
				if d_m_axi_arready = '1' then
					s_axi_reg_inbyte_next <= std_logic_vector(unsigned(s_axi_reg_inbyte) + to_unsigned(1, s_axi_reg_inbyte'length));
					ddr_read_bytes_remaining_next <= std_logic_vector(unsigned(ddr_read_bytes_remaining_curr) - to_unsigned(2**(AXI_LEN_WIDTH+LCPLC_DATA_BYTES_LOG), ddr_read_bytes_remaining_curr'length));
					ddr_read_addr_next			  <= std_logic_vector(unsigned(ddr_read_addr_curr) 			  + to_unsigned(2**(AXI_LEN_WIDTH+LCPLC_DATA_BYTES_LOG), 			ddr_read_addr_curr'length));
					ddr_read_state_next 		  <= DDR_READ_TRANSFER;
				end if;
			--we have less than max, but still have some
			elsif ddr_read_bytes_remaining_curr(AXI_LEN_WIDTH + LCPLC_DATA_BYTES_LOG - 1 downto LCPLC_DATA_BYTES_LOG)
					/= (AXI_LEN_WIDTH - 1 downto 0 => '0') then
				d_m_axi_arvalid 		<= '1';
				d_m_axi_arlen 			<= std_logic_vector(unsigned(ddr_read_bytes_remaining_curr(AXI_LEN_WIDTH + LCPLC_DATA_BYTES_LOG - 1 downto LCPLC_DATA_BYTES_LOG)) - to_unsigned(1, AXI_LEN_WIDTH));
				if d_m_axi_arready = '1' then
					s_axi_reg_inbyte_next <= std_logic_vector(unsigned(s_axi_reg_inbyte) + to_unsigned(1, s_axi_reg_inbyte'length));
					ddr_read_bytes_remaining_next <= (others => '0');
					ddr_read_state_next 		  <= DDR_READ_TRANSFER;
				end if;
				--ddr_read_addr_next; --don't care for this value since it won't be used again
			--we have run out of bytes to ask for
			else
				control_input_transfer_done <= '1';
				if control_input_reset = '1' then
					ddr_read_state_next <= DDR_READ_IDLE;
				end if;
			end if;
		elsif ddr_read_state_curr = DDR_READ_TRANSFER then
			ififo_input_valid <= d_m_axi_rvalid;
			d_m_axi_rready <= ififo_input_ready;
			if d_m_axi_rlast = '1' then
				--burst is finished, go back to requesting transactions
				ddr_read_state_next <= DDR_READ_REQUEST;
			end if;
		end if;
	end process;

	ififo_input_data <= d_m_axi_rdata;
	ififo_rst <= not d_m_axi_resetn;
	input_sample_fifo: entity work.AXIS_FIFO
		Generic map (
			DATA_WIDTH => (2**LCPLC_DATA_BYTES_LOG)*8,
			FIFO_DEPTH => 512 --leave room
		)
		Port map ( 
			clk	=> d_m_axi_clk, rst => ififo_rst,
			--input axi port
			input_valid		=> ififo_input_valid,
			input_ready		=> ififo_input_ready,
			input_data		=> ififo_input_data,
			--out axi port
			output_ready	=> ififo_output_ready,
			output_data		=> ififo_output_data,
			output_valid	=> ififo_output_valid
		);

	flag_gen: entity work.FLAG_GENERATOR
		Generic map (
			DATA_WIDTH				=> (2**LCPLC_DATA_BYTES_LOG)*8,
			MAX_BLOCK_SAMPLE_LOG	=> LCPLC_MAX_BLOCK_SAMPLE_LOG,
			MAX_BLOCK_LINE_LOG		=> LCPLC_MAX_BLOCK_LINE_LOG,
			MAX_IMAGE_SAMPLE_LOG	=> LCPLC_MAX_IMAGE_SAMPLE_LOG,
			MAX_IMAGE_LINE_LOG		=> LCPLC_MAX_IMAGE_LINE_LOG,
			MAX_IMAGE_BAND_LOG		=> LCPLC_MAX_IMAGE_BAND_LOG
		)
		port map (
			clk => d_m_axi_clk, rst => ififo_rst,
			config_block_samples	=> s_axi_reg_bcksmp(LCPLC_MAX_BLOCK_SAMPLE_LOG - 1 downto 0),
			config_block_lines		=> s_axi_reg_bcklin(LCPLC_MAX_BLOCK_LINE_LOG - 1 downto 0),
			config_image_samples	=> s_axi_reg_smplno(LCPLC_MAX_IMAGE_SAMPLE_LOG - 1 downto 0),
			config_image_lines		=> s_axi_reg_lineno(LCPLC_MAX_IMAGE_LINE_LOG - 1 downto 0),
			config_image_bands		=> s_axi_reg_bandno(LCPLC_MAX_IMAGE_BAND_LOG - 1 downto 0),
			raw_input_data			=> ififo_output_data,
			raw_input_ready			=> ififo_output_ready,
			raw_input_valid			=> ififo_output_valid,
			output_data 			=> core_input_data,
			output_last_r			=> core_input_last_r,
			output_last_s			=> core_input_last_s,
			output_last_b			=> core_input_last_b,
			output_last_i			=> core_input_last_i,
			output_ready 			=> core_input_ready,
			output_valid 			=> core_input_valid
		);

	lcplc_clk <= d_m_axi_clk;
	--core: entity work.LCPLC
	--	Generic map (
	--		DATA_WIDTH => (2**LCPLC_DATA_BYTES_LOG)*8,
	--		WORD_WIDTH_LOG => LCPLC_OUTPUT_BYTES_LOG+3,
	--		MAX_SLICE_SIZE_LOG => LCPLC_MAX_BLOCK_SAMPLE_LOG + LCPLC_MAX_BLOCK_LINE_LOG,
	--		ALPHA_WIDTH => LCPLC_ALPHA_WIDTH,
	--		ACCUMULATOR_WINDOW => LCPLC_ACCUMULATOR_WINDOW,
	--		UPSHIFT => LCPLC_UPSHIFT,
	--		DOWNSHIFT => LCPLC_DOWNSHIFT,
	--		THRESHOLD => LCPLC_THRESHOLD
	--	)
	--	Port map (
	--		clk => lcplc_clk, rst => lcplc_rst,
	--		x_valid 	=> core_input_valid,
	--		x_ready 	=> core_input_ready,
	--		x_data 		=> core_input_data,
	--		x_last_r	=> core_input_last_r,
	--		x_last_s	=> core_input_last_s,
	--		x_last_b	=> core_input_last_b,
	--		x_last_i 	=> core_input_last_i,
	--		output_data => core_output_data,
	--		output_ready=> core_output_ready,
	--		output_valid=> core_output_valid,
	--		output_last => core_output_last
	--	);
	core_output_data	<= x"0000" & core_input_data;
	core_input_ready    <= core_output_ready;
	core_output_valid	<= core_input_valid;
	core_output_last	<= core_input_last_i;

	--TODO
	--axi thing that takes inputs and counts and asserts signals as needed counting for irregular borders
	--the output from that thing outside
	--we just output that with the last signal being the last_i from the generator, and then hope
	--that plugging the coder in the middle will work

	--------------------------------
	--CORE TO DDR OUTPUT PROCESSES--
	--------------------------------
	ddr_write_seq: process(d_m_axi_clk)
	begin
		if rising_edge(d_m_axi_clk) then
			if d_m_axi_resetn = '0' then
				ddr_write_state_curr <= DDR_WRITE_IDLE;
				s_axi_reg_outbyt <= (others => '0');
			else
				ddr_write_state_curr <= ddr_write_state_next;
				ddr_write_addr_curr  <= ddr_write_addr_next;
				ddr_write_transactions_left_curr <= ddr_write_transactions_left_next;
				s_axi_reg_outbyt     <= s_axi_reg_outbyt_next;
			end if;
		end if;
	end process;

	--fixed signals
	d_m_axi_awlen	<= (others => '1'); --set all by default (we don't know how many we'll have) (when we run out set wstrb to zero)
	d_m_axi_awsize	<= std_logic_vector(to_unsigned(LCPLC_OUTPUT_BYTES_LOG, d_m_axi_arsize'length));
	d_m_axi_awburst	<= AXI_BURST_INCR;
	d_m_axi_awlock  <= AXI_LOCK_UNLOCKED;
	d_m_axi_awcache <= AXI_CACHE_NORMAL_NONCACHE_NONBUFF;
	d_m_axi_awprot  <= AXI_PROT_UNPRIVILEDGED_NONSECURE_DATA;
	d_m_axi_awqos   <= AXI_QOS_EIGHT;
	d_m_axi_awaddr	<= ddr_write_addr_curr;
	--
	d_m_axi_wdata  <= core_output_data;
	ddr_write_comb: process(ddr_write_state_curr, ddr_write_addr_curr, ddr_write_transactions_left_curr,
			control_output_transfer_enable, control_output_reset, s_axi_reg_outbyt,
			s_axi_reg_tgaddr, d_m_axi_awready, d_m_axi_wready, d_m_axi_bvalid, core_output_valid, core_output_last)
	begin
		ddr_write_state_next <= ddr_write_state_curr;
		control_output_idle <= '0';
		ddr_write_addr_next <= ddr_write_addr_curr;
		d_m_axi_awvalid 	<= '0';
		ddr_write_transactions_left_next <= ddr_write_transactions_left_curr;
		core_output_ready	<= '0';
		d_m_axi_wvalid 		<= '0';
		d_m_axi_wlast 		<= '0';
		d_m_axi_wstrb		<= (others => '0');
		d_m_axi_bready 		<= '0';

		control_output_transfer_done <= '0';
		
		s_axi_reg_outbyt_next <= s_axi_reg_outbyt;

		if ddr_write_state_curr = DDR_WRITE_IDLE then
			control_output_idle <= '1';
			if control_output_transfer_enable = '1' then
				ddr_write_state_next <= DDR_WRITE_REQUEST;
				ddr_write_addr_next  <= s_axi_reg_tgaddr;
			end if;
		elsif ddr_write_state_curr = DDR_WRITE_REQUEST then
			d_m_axi_awvalid <= '1';
			if d_m_axi_awready = '1' then
				ddr_write_state_next <= DDR_WRITE_TRANSFER;
				ddr_write_transactions_left_next <= (others => '1');
			end if;
		elsif ddr_write_state_curr = DDR_WRITE_TRANSFER then
			core_output_ready	<= d_m_axi_wready;
			d_m_axi_wvalid 		<= core_output_valid;
			d_m_axi_wstrb		<= (others => '1');
			if core_output_valid = '1' and d_m_axi_wready = '1' then
				s_axi_reg_outbyt_next <= std_logic_vector(unsigned(s_axi_reg_outbyt) + to_unsigned(1, s_axi_reg_outbyt'length));
				if ddr_write_transactions_left_curr = (ddr_write_transactions_left_curr'range => '0') then
					d_m_axi_wlast <= '1';
					if core_output_last = '0' then
						ddr_write_state_next <= DDR_WRITE_RESPONSE;
					else
						ddr_write_state_next <= DDR_WRITE_LAST_RESPONSE;
					end if;
				else
					ddr_write_transactions_left_next <= std_logic_vector(unsigned(ddr_write_transactions_left_curr) - to_unsigned(1, ddr_write_transactions_left_curr'length));
					if core_output_last = '1' then
						--last word but we still are on the write transaction. Change state to go to disable strobing
						ddr_write_state_next <= DDR_WRITE_TRANSFER_NOSTRB;
					end if;
				end if;
			end if;
		--finishing transaction with empty bytes to avoid overwriting of stuff
		elsif ddr_write_state_curr = DDR_WRITE_TRANSFER_NOSTRB then
			d_m_axi_wvalid <= '1';
			d_m_axi_wstrb <= (others => '0');
			if d_m_axi_wready = '1' then
				s_axi_reg_outbyt_next <= std_logic_vector(unsigned(s_axi_reg_outbyt) + to_unsigned(1, s_axi_reg_outbyt'length));
				if ddr_write_transactions_left_curr = (ddr_write_transactions_left_curr'range => '0') then
					d_m_axi_wlast <= '1';
					ddr_write_state_next <= DDR_WRITE_LAST_RESPONSE;
				else
					ddr_write_transactions_left_next <= std_logic_vector(unsigned(ddr_write_transactions_left_curr) - to_unsigned(1, ddr_write_transactions_left_curr'length));
				end if;
			end if;
		elsif ddr_write_state_curr = DDR_WRITE_RESPONSE then
			d_m_axi_bready <= '1';
			if d_m_axi_bvalid = '1' then
				ddr_write_state_next <= DDR_WRITE_REQUEST;
			end if;
		elsif ddr_write_state_curr = DDR_WRITE_LAST_RESPONSE then
			d_m_axi_bready <= '1';
			if d_m_axi_bvalid = '1' then
				ddr_write_state_next <= DDR_WRITE_FINISH;
			end if;
		elsif ddr_write_state_curr = DDR_WRITE_FINISH then
			control_output_transfer_done <= '1';
			if control_output_reset = '1' then
				ddr_write_state_next <= DDR_WRITE_IDLE;
			end if;
		end if;
	end process;



end Behavioral;

	--a process to input/output data from registers

	--a process looks at the control register and, when the adequante sequence is triggered, starts moving through the compression process
	--asserts start/stop signals for other processes, and then waits for end signals from other processes, indicating this in the status register
	--that can be read from the controller
	--should this have some sort of pause/reset?? probably would be useful
	
	--another process waits for the start signal to be asserted and starts reading from ddr and sending results to lcplc. Maybe this would be interesting to do in bursts
	--so that we can ask for, lets say, 256 bytes and put them all as fast as possible in a queue, and then do the same when the queue is almost empty
	
	--another process waits for data to be output (after the module has started). 
	--Maybe also wait for a certain amount (or a termination to be seen) before initiating a burst with many beats 
	--when finished, asserts end of compression so that the main process can be reset  