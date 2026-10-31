class jtag_sequencer extends uvm_sequencer #(jtag_item);
`uvm_component_utils(jtag_sequencer)
function new(string n,uvm_component p);super.new(n,p);endfunction
endclass
