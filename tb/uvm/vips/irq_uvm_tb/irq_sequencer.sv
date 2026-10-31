class irq_sequencer extends uvm_sequencer #(irq_item);
`uvm_component_utils(irq_sequencer)
function new(string n,uvm_component p);super.new(n,p);endfunction
endclass
