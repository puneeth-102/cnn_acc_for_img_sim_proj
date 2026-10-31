class jtag_test extends uvm_test;
jtag_env env;
`uvm_component_utils(jtag_test)
function new(string n,uvm_component p);super.new(n,p);endfunction
function void build_phase(uvm_phase phase); env=jtag_env::type_id::create("env",this); endfunction
endclass
