----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:52:47 06/06/2018 
-- Design Name: 
-- Module Name:    BPC_coord_gen - Behavioral 
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
use work.JypecConstants.all;


--Coordinate generator.
-- sweeps the row+col space by going through four sample strips (vertically)
-- then when finished it increases the pass counter. When all passes are done,
-- the bit plane counter is at last increased
entity BPC_coord_gen is
	generic (
		--number of strips
		STRIPS: integer := 16;
		--number of columns of the block, works w/whatever size
		COLS: integer := 64;
		--number of bitplanes must be >= 2 (sign + magnitude) (dont count sign here)
		BITPLANES: integer := 15 
		);
	Port ( 
		--control signals
		clk, rst, clk_en : in std_logic;
		--strip output
		strip_out: out natural range 0 to STRIPS - 1;
		--column output
		col_out: out natural range 0 to COLS - 1;
		--bitplane output
		bitplane_out: out natural range 0 to BITPLANES - 1;
		--pass output
		pass_out: out encoder_pass_t;
		--'1' when the last coordinate is being output
		last_coord: out std_logic	
	);
end BPC_coord_gen;

architecture Behavioral of BPC_coord_gen is
	
	signal strip : natural range 0 to STRIPS - 1;
	signal col : natural range 0 to COLS - 1;
	signal bitplane: natural range 0 to BITPLANES - 1;
	signal pass: encoder_pass_t;
	
begin

	--output inner signals
	strip_out <= strip;
	col_out <= col;
	bitplane_out <= bitplane;
	pass_out <= pass;
	last_coord <= '1' when strip = STRIPS - 1 and col = COLS - 1 and pass = CLEANUP and bitplane = BITPLANES - 1 else '0';
	
	--update state
	update_coords: process(clk, rst, clk_en)
	begin
		if (rst = '1') then
			strip <= 0;
			col <= 0;
			bitplane <= 0;
			pass <= CLEANUP; --first plane only gets cleanup, significance and refinement do NOT appear on bitplane 0
		elsif (rising_edge(clk) and clk_en = '1') then
			if (col = COLS - 1) then
				col <= 0;
				if (strip = STRIPS - 1) then
					strip <= 0;
					if (pass = CLEANUP) then
						if (bitplane = BITPLANES - 1) then
							bitplane <= 0;
							pass <= CLEANUP; --skip SIGN and REF for first pass
						else
							bitplane <= bitplane + 1;
							pass <= SIGNIFICANCE;
						end if;
					elsif (pass = SIGNIFICANCE) then
						pass <= REFINEMENT;
					else -- pass = REFINEMENT
						pass <= CLEANUP;
					end if;
				else
					strip <= strip + 1;
				end if;
			else
				col <= col + 1;
			end if;
		end if;
	
	end process;

end Behavioral;


