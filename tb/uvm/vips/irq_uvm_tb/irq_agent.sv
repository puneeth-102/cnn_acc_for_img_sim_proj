class irq_agent extends uvm_agent;
irq_driver drv; irq_monitor mon; irq_sequencer seqr;
`uvm_component_utils(irq_agent)
function new(string n,uvm_component p);super.new(n,p);endfunction
function void build_phase(uvm_phase phase); drv=irq_driver::type_id::create("drv",this); mon=irq_monitor::type_id::create("mon",this); seqr=irq_sequencer::type_id::create("seqr",this); endfunction
function void connect_phase(uvm_phase phase); drv.seq_item_port.connect(seqr.seq_item_export); endfunction
endclass
