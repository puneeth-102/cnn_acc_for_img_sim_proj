// =============================================================================
// File   : gpio_agent.sv
// Class  : gpio_agent
// Purpose: UVM Agent encapsulating GPIO monitor
// =============================================================================

`ifndef GPIO_AGENT_SV
`define GPIO_AGENT_SV

class gpio_agent extends uvm_agent;
    `uvm_component_utils(gpio_agent)

    gpio_monitor monitor;
    uvm_analysis_port #(gpio_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = gpio_monitor::type_id::create("monitor", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        ap = monitor.ap;
    endfunction

endclass : gpio_agent

`endif // GPIO_AGENT_SV
