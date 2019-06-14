package lcplc_functions is
	--headers
	function lcplc_bits(invalue: integer) return integer;

end lcplc_functions;

package body lcplc_functions is
	--actual function bodies
	function lcplc_bits(invalue: integer) return integer is
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

end lcplc_functions;