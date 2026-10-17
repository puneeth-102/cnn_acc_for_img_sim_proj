// =============================================================================
// File   : dist_agent.sv
// Class  : dist_agent
// Purpose: UVM Agent encapsulating Distance Engine monitor
// =============================================================================

`ifndef DIST_AGENT_SV
`define DIST_AGENT_SV

class dist_agent extends uvm_agent;
    `uvm_component_utils(dist_agent)

    dist_monitor monitor;
    uvm_analysis_port #(dist_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = dist_monitor::type_id::create("monitor", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        ap = monitor.ap;
    endfunction

endclass : dist_agent

`endif // DIST_AGENT_SV
