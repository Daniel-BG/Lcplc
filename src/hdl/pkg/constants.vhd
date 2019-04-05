library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package constants is
	attribute KEEP: string;
	constant KEEP_DEFAULT: string := "TRUE";

	attribute USE_DSP : string;
	constant USE_DSP_ARITH_OP: string := "YES";

	--AXI constants
	constant AXI_BRESP_WIDTH: integer := 2;
	constant AXI_LEN_WIDTH	: integer := 8;
	constant AXI_SIZE_WIDTH	: integer := 3;
	constant AXI_BURST_WIDTH: integer := 2;
	constant AXI_CACHE_WIDTH: integer := 4;
	constant AXI_PROT_WIDTH	: integer := 3;
	constant AXI_QOS_WIDTH	: integer := 4;

	constant AXI_RESP_OKAY 	: std_logic_vector(AXI_BRESP_WIDTH - 1 downto 0) := "00";
	constant AXI_RESP_EXOKAY: std_logic_vector(AXI_BRESP_WIDTH - 1 downto 0) := "01";
	constant AXI_RESP_SLVERR: std_logic_vector(AXI_BRESP_WIDTH - 1 downto 0) := "10";
	constant AXI_RESP_DECERR: std_logic_vector(AXI_BRESP_WIDTH - 1 downto 0) := "11";

	constant AXI_BURST_FIXED: std_logic_vector(AXI_BURST_WIDTH - 1 downto 0) := "00";
	constant AXI_BURST_INCR : std_logic_vector(AXI_BURST_WIDTH - 1 downto 0) := "01";
	constant AXI_BURST_WRAP : std_logic_vector(AXI_BURST_WIDTH - 1 downto 0) := "10";

	constant AXI_LOCK_LOCKED 	: std_logic := '1';
	constant AXI_LOCK_UNLOCKED	: std_logic := '0';

	constant AXI_CACHE_NORMAL_NONCACHE_NONBUFF: std_logic_vector(AXI_CACHE_WIDTH - 1 downto 0) := "0010";

	constant AXI_PROT_UNPRIVILEDGED_NONSECURE_DATA: std_logic_vector(AXI_PROT_WIDTH - 1 downto 0) := "010";

	constant AXI_QOS_EIGHT: std_logic_vector(AXI_QOS_WIDTH - 1 downto 0) := "1000";

end constants;

package body constants is

end constants;