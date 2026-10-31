class jtag_env extends uvm_env;
jtag_agent agent; jtag_scoreboard sb;
`uvm_component_utils(jtag_env)
function new(string n,uvm_component p);super.new(n,p);endfunction
function void build_phase(uvm_phase phase); agent=jtag_agent::type_id::create("agent",this); sb=jtag_scoreboard::type_id::create("sb",this); endfunction
endclass
