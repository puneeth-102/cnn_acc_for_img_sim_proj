// =============================================================================
// File   : uart_agent.sv
// Class  : uart_agent
// Purpose: UVM Agent encapsulating UART monitor
// =============================================================================

`ifndef UART_AGENT_SV
`define UART_AGENT_SV

class uart_agent extends uvm_agent;
    `uvm_component_utils(uart_agent)

    uart_monitor monitor;
    uvm_analysis_port #(uart_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = uart_monitor::type_id::create("monitor", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        ap = monitor.ap;
    endfunction

endclass : uart_agent

`endif // UART_AGENT_SV
