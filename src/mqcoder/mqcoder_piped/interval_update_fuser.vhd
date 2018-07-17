----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:54:27 07/17/2018 
-- Design Name: 
-- Module Name:    interval_update_fuser - Behavioral 
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

entity interval_update_fuser is
		port (
			clk, rst: in std_logic;
			in_empty: in std_logic;
			in_readen:out std_logic;
			in_hit: in std_logic;
			in_prob: in unsigned(15 downto 0);
			in_shift: in unsigned(3 downto 0);
			out_full: in std_logic;
			out_wren: out std_logic;
			out_hit: out std_logic;
			out_prob: out unsigned(15 downto 0);
			out_shift: out unsigned(3 downto 0);
			no_more_data: in std_logic;
			out_finished: out std_logic
		);
end interval_update_fuser;

architecture Behavioral of interval_update_fuser is
	--avoid numbers down the line
	constant DATA_WIDTH: integer := 16+4+1;
	
	--main control
	type FUSER_STATE_T is (IDLE, DATA_READ, FLUSH, FINISHED);
	signal state_fuser_curr, state_fuser_next: FUSER_STATE_T;


	--control signals:
	signal clk_en: std_logic;
	signal joining: std_logic;
	signal can_join_shifts, can_join_probshift: std_logic;

	--buffer signals
	signal datain, data_buffer, data_buffer_joint: std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal data_buffer_next: std_logic_vector(DATA_WIDTH - 1 downto 0);
	
	signal datain_hit, data_buffer_hit, data_buffer_joint_hit: std_logic;
	signal datain_prob, data_buffer_prob: unsigned(15 downto 0);
	signal data_buffer_joint_prob: unsigned(16 downto 0);
	signal datain_shift, data_buffer_shift: unsigned(3 downto 0);
	signal data_buffer_joint_shift: unsigned(4 downto 0);
	
begin

	--filter input
	datain_hit <= in_hit;
	datain_prob <= in_prob when in_hit = '1' else (others => '0');
	datain_shift <= in_shift;
	---------------

	--aliases 
	data_buffer_joint <= data_buffer_joint_hit & std_logic_vector(data_buffer_joint_prob(15 downto 0) & data_buffer_joint_shift(3 downto 0));
	datain <= datain_hit & std_logic_vector(datain_prob & datain_shift);
	data_buffer_hit <= data_buffer(20);
	data_buffer_prob <= unsigned(data_buffer(19 downto 4));
	data_buffer_shift <= unsigned(data_buffer(3 downto 0));
	
	out_hit <= data_buffer_hit;
	out_prob <= data_buffer_prob;
	out_shift <= data_buffer_shift;
	-------------
	

	
	--fusing and flags
	can_join_shifts <= '1' when
			datain_hit = '0' and data_buffer_hit = '0' and
			data_buffer_joint_shift(4) = '0' --< unsigned("10000")
		else '0';
		
	can_join_probshift <= '1' when
			data_buffer_shift = "0000" and
			data_buffer_joint_prob(16) = '0' --< unsigned("10000000000000000")
		else '0';
		
	data_buffer_joint_prob <= ("0" & datain_prob) + ("0" & data_buffer_prob);
	data_buffer_joint_shift <= ("0" & datain_shift) + ("0" & data_buffer_shift);
	data_buffer_joint_hit <= '1' when datain_hit = '1' or data_buffer_hit = '1' else '0';
	
	joining <= '1' when (can_join_shifts = '1' or can_join_probshift = '1') else '0';
	-------------------
	
	
	state_machine_update: process(state_fuser_curr, in_empty, no_more_data, out_full, joining, data_buffer, data_buffer_joint, datain)
	begin
		
		in_readen <= '0';
		state_fuser_next <= state_fuser_curr;
		data_buffer_next <= data_buffer;
		out_wren <= '0';
		out_finished <= '0';
	
		case state_fuser_curr is
			--buffer contains latest result. if just reset, it has all zeroes
			--so any reads will merge into it and we will not generate extra 
			--interval updates
			--input has no valid data in this state
			when IDLE =>
				if in_empty = '0' then
					in_readen <= '1';
					state_fuser_next <= DATA_READ;
				elsif no_more_data = '1' then
					state_fuser_next <= FLUSH;
				end if;
			--buffer is full and input has valid data
			when DATA_READ =>
				--wait till output is not full
				if out_full = '0' then
					if joining = '1' then
						--join both results
						data_buffer_next <= data_buffer_joint;
					else
						--buffer goes to output and gets latest data
						data_buffer_next <= datain;
						out_wren <= '1';
					end if;
					if in_empty = '0' then
						in_readen <= '1';
						state_fuser_next <= DATA_READ;
					else
						state_fuser_next <= IDLE;
					end if;
				end if;
			--only buffer has valid info, just flush it out
			when FLUSH =>
				if out_full = '0' then
					out_wren <= '1';
					state_fuser_next <= FINISHED;
				end if;
			--buffer is flushed, indicate finished flag to the outside
			--stay here until reset
			when FINISHED =>
				out_finished <= '1';
		end case;
	end process;
	
	
	--update processes
	update_buffers: process(clk, rst)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				data_buffer <= (others => '0');
				state_fuser_curr <= IDLE;
			else
				data_buffer <= data_buffer_next;
				state_fuser_curr <= state_fuser_next;
			end if;
		end if;
	end process;
	

end Behavioral;

