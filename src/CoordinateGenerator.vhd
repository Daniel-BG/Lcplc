----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 25.10.2017 12:02:13
-- Design Name: 
-- Module Name: CoordinateGenerator - Behavioral
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
use work.JypecConstants.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;


-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity CoordinateGenerator is
	generic (
		ROWS: integer := 64; --must be multiple of 4
		COLS: integer := 64; --works w/whatever size
		BITPLANES: integer := 15 --whatever size >= 2 (sign + magnitude)
	);
    Port ( clk : in std_logic;
           rst : in std_logic;
           clk_en : in std_logic;
           row_out: out natural range 0 to ROWS - 1;	--current row
           col_out: out natural range 0 to COLS - 1;	--current column
           bitplane_out: out natural range 0 to BITPLANES - 1; --current bitplane
           pass_out: out encoder_pass_t;	--current pass
           done_out: out std_logic	--'1' when all coordinates have been generated
    );
end CoordinateGenerator;

architecture Behavioral of CoordinateGenerator is
	
	signal row : natural range 0 to ROWS - 1;
	signal col : natural range 0 to COLS - 1;
	signal bitplane: natural range 0 to BITPLANES - 1;
	signal pass: encoder_pass_t;
	signal done: std_logic;
	
begin

	row_out <= row;
	col_out <= col;
	bitplane_out <= bitplane;
	pass_out <= pass;
	done_out <= done;

	update_coords: process(clk, rst, clk_en)
	begin
	
		if (rst = '1') then
			row <= 0;
			col <= 0;
			bitplane <= 0;
			pass <= CLEANUP; --first plane only gets cleanup, significance and refinement do NOT appear on bitplane 0
			done <= '0';
		elsif (rising_edge(clk) and clk_en = '1') then
			done <= '0';
			if (row = ROWS - 1) then
				if (col = COLS - 1) then
					row <= 0;
					col <= 0;
					--reached end of pass, update
					if (pass = CLEANUP) then
						if (bitplane = BITPLANES - 1) then
							bitplane <= 0;
							pass <= CLEANUP;
							done <= '1';
						else
							bitplane <= bitplane + 1;
							pass <= SIGNIFICANCE;
						end if;
					elsif (pass = SIGNIFICANCE) then
						pass <= REFINEMENT;
					else --pass = REFINEMENT
						pass <= CLEANUP;
					end if;
				else
					row <= row - 3;
					col <= col + 1;
				end if;
			else
				if ((row + 1) mod 4 = 0) then
					if (col = COLS - 1) then
						row <= row + 1;
						col <= 0;
					else
						row <= row - 3;
						col <= col + 1;
					end if;
				else
					row <= row + 1;
					col <= col;
				end if;
			end if;
		end if;
	
	end process;

end Behavioral;
