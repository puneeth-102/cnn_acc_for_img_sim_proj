// =============================================================================
// File   : dma_agent.sv
// Class  : dma_agent
// Purpose: UVM Agent encapsulating DMA monitor
// =============================================================================

`ifndef DMA_AGENT_SV
`define DMA_AGENT_SV

class dma_agent extends uvm_agent;
    `uvm_component_utils(dma_agent)

    dma_monitor monitor;
    uvm_analysis_port #(dma_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = dma_monitor::type_id::create("monitor", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        ap = monitor.ap;
    endfunction

endclass : dma_agent

`endif // DMA_AGENT_SV
