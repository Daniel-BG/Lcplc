package FUNCTIONS is
	--headers
	function bits(invalue: integer) return integer;
	function minval(a, b: integer) return integer;
	function maxval(a, b: integer) return integer;
	
end FUNCTIONS;

package body FUNCTIONS is
	--actual function bodies
	function bits(invalue: integer) return integer is
		variable i: integer := 1;
	begin
		while i <= 32 loop
			if invalue <= 2**i - 1 then
				return i;
			end if;
			i := i + 1;
		end loop;
		return -1;
	end function;

	function minval(a, b: integer) return integer is
	begin
		if a > b then
			return b;
		else
			return a;
		end if;
	end function;

	function maxval(a, b: integer) return integer is
	begin
		if a > b then
			return a;
		else
			return b;
		end if;
	end function;
end FUNCTIONS;