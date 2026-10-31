class irq_test extends uvm_test;
irq_env env;
`uvm_component_utils(irq_test)
function new(string n,uvm_component p);super.new(n,p);endfunction
function void build_phase(uvm_phase phase); env=irq_env::type_id::create("env",this); endfunction
endclass
