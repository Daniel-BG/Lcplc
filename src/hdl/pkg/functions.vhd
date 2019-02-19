package FUNCTIONS is
	--headers
	function bits(input: integer) return integer;
	
end FUNCTIONS;

package body FUNCTIONS is
	--actual function bodies
	function bits(input: integer) return integer is
		variable i: integer := 1;
	begin
		while i <= 32 loop
			if input <= 2**i - 1 then
				return i;
			end if;
			i := i + 1;
		end loop;
		return -1;
	end function;
end FUNCTIONS;