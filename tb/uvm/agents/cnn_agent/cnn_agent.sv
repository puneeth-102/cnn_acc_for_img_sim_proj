// =============================================================================
// File   : cnn_agent.sv
// Class  : cnn_agent
// Purpose: UVM Agent encapsulating CNN monitor
// =============================================================================

`ifndef CNN_AGENT_SV
`define CNN_AGENT_SV

class cnn_agent extends uvm_agent;
    `uvm_component_utils(cnn_agent)

    cnn_monitor monitor;
    uvm_analysis_port #(cnn_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = cnn_monitor::type_id::create("monitor", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        ap = monitor.ap;
    endfunction

endclass : cnn_agent

`endif // CNN_AGENT_SV
