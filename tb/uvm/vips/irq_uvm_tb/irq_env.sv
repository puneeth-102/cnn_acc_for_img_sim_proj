class irq_env extends uvm_env;
irq_agent agent; irq_scoreboard sb;
`uvm_component_utils(irq_env)
function new(string n,uvm_component p);super.new(n,p);endfunction
function void build_phase(uvm_phase phase); agent=irq_agent::type_id::create("agent",this); sb=irq_scoreboard::type_id::create("sb",this); endfunction
endclass
