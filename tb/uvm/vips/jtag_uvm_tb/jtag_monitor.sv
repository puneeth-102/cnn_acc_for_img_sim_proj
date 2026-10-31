class jtag_monitor extends uvm_monitor;
virtual jtag_if vif;
uvm_analysis_port #(jtag_item) ap;
`uvm_component_utils(jtag_monitor)
function new(string n,uvm_component p); super.new(n,p); ap=new("ap",this); endfunction
endclass
