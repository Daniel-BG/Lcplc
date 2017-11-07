----------------------------------------------------------------------------------
-- Company: UCM
-- Engineer: Daniel Báscones
-- 
-- Create Date: 25.10.2017 12:02:13
-- Design Name: 
-- Module Name: CoordinateGenerator - Behavioral
-- Project Name: Vypec
-- Target Devices: 
-- Tool Versions: 
-- Description: Coordinate generator for coding blocks. Here the coordinates
-- 		are four-dimensional: row, column, bitplane and pass
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments: 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.JypecConstants.all;


--Coordinate generator.
-- sweeps the row+col space by going through four sample strips (vertically)
-- then when finished it increases the pass counter. When all passes are done,
-- the bit plane counter is at last increased
entity CoordinateGenerator is
	generic (
		--number of rows, must be multiple of 4
		ROWS: integer := 64;
		--number of columns of the block, works w/whatever size
		COLS: integer := 64;
		--number of bitplanes must be >= 2 (sign + magnitude)
		BITPLANES: integer := 15 
		);
	Port ( 
		--control signals
		clk, rst, clk_en : in std_logic;
		--row output
		row_out: out natural range 0 to ROWS - 1;
		--column output
		col_out: out natural range 0 to COLS - 1;
		--bitplane output
		bitplane_out: out natural range 0 to BITPLANES - 1;
		--pass output
		pass_out: out encoder_pass_t;
		--'1' when the last coordinate is being output
		last_coord: out std_logic	
	);
end CoordinateGenerator;

architecture Behavioral of CoordinateGenerator is
	
	signal row : natural range 0 to ROWS - 1;
	signal col : natural range 0 to COLS - 1;
	signal bitplane: natural range 0 to BITPLANES - 1;
	signal pass: encoder_pass_t;
	
begin

	--output inner signals
	row_out <= row;
	col_out <= col;
	bitplane_out <= bitplane;
	pass_out <= pass;
	last_coord <= '1' when row = ROWS - 1 and col = COLS - 1 and pass = CLEANUP and bitplane = BITPLANES - 1 else '0';
	
	--update state
	update_coords: process(clk, rst, clk_en)
	begin
		if (rst = '1') then
			row <= 0;
			col <= 0;
			bitplane <= 0;
			pass <= CLEANUP; --first plane only gets cleanup, significance and refinement do NOT appear on bitplane 0
		elsif (rising_edge(clk) and clk_en = '1') then
			if (row = ROWS - 1) then
				if (col = COLS - 1) then
					row <= 0;
					col <= 0;
					--reached end of pass, update
					if (pass = CLEANUP) then
						if (bitplane = BITPLANES - 1) then
							bitplane <= 0;
							pass <= CLEANUP;
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
