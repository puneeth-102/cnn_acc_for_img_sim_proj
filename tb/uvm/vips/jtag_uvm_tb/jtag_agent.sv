class jtag_agent extends uvm_agent;
jtag_driver drv; jtag_monitor mon; jtag_sequencer seqr;
`uvm_component_utils(jtag_agent)
function new(string n,uvm_component p);super.new(n,p);endfunction
function void build_phase(uvm_phase phase); drv=jtag_driver::type_id::create("drv",this); mon=jtag_monitor::type_id::create("mon",this); seqr=jtag_sequencer::type_id::create("seqr",this); endfunction
function void connect_phase(uvm_phase phase); drv.seq_item_port.connect(seqr.seq_item_export); endfunction
endclass
