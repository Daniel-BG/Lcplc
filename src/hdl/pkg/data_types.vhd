package data_types is
    type array_of_integers is array(integer range <>) of integer;
    
    type last_policy_t is (PASS_ZERO, PASS_ONE, OR_ALL, AND_ALL); 
end package;

package body data_types is

end data_types;