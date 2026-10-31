class irq_driver extends uvm_driver #(irq_item);
virtual irq_if vif;
`uvm_component_utils(irq_driver)
function new(string n,uvm_component p);super.new(n,p);endfunction
task run_phase(uvm_phase phase); forever begin seq_item_port.get_next_item(req); @(posedge vif.clk); seq_item_port.item_done(); end endtask
endclass
