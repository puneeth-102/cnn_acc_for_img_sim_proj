// =============================================================================
// File   : soc_env.sv
// Purpose: Top-level UVM Environment integrating all 5 External VIPs & Scoreboard.
// =============================================================================

`ifndef SOC_ENV_SV
`define SOC_ENV_SV

class soc_env extends uvm_env;
    `uvm_component_utils(soc_env)

    // Five External VIP Agents
    clk_rst_agent  clk_rst_agt;
    uart_agent     uart_agt;
    gpio_agent     gpio_agt;
    irq_agent      irq_agt;
    jtag_agent     jtag_agt;

    // Central Scoreboard
    soc_scoreboard sb;

    // Virtual Interface Handles
    virtual clk_rst_if clk_rst_vif;
    virtual uart_if    uart_vif;
    virtual gpio_if    gpio_vif;
    virtual irq_if     irq_vif;
    virtual jtag_if    jtag_vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Instantiate VIP Agents
        clk_rst_agt = clk_rst_agent::type_id::create("clk_rst_agt", this);
        uart_agt    = uart_agent::type_id::create("uart_agt", this);
        gpio_agt    = gpio_agent::type_id::create("gpio_agt", this);
        irq_agt     = irq_agent::type_id::create("irq_agt", this);
        jtag_agt    = jtag_agent::type_id::create("jtag_agt", this);

        // Instantiate Scoreboard
        sb = soc_scoreboard::type_id::create("sb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Fetch virtual interfaces from uvm_config_db and assign to Agent drivers/monitors
        if (uvm_config_db#(virtual clk_rst_if)::get(this, "", "clk_rst_vif", clk_rst_vif)) begin
            clk_rst_agt.drv.vif = clk_rst_vif;
            clk_rst_agt.mon.vif = clk_rst_vif;
        end

        if (uvm_config_db#(virtual uart_if)::get(this, "", "uart_vif", uart_vif)) begin
            uart_agt.drv.vif = uart_vif;
            uart_agt.mon.vif = uart_vif;
        end

        if (uvm_config_db#(virtual gpio_if)::get(this, "", "gpio_vif", gpio_vif)) begin
            gpio_agt.drv.vif = gpio_vif;
            gpio_agt.mon.vif = gpio_vif;
        end

        if (uvm_config_db#(virtual irq_if)::get(this, "", "irq_vif", irq_vif)) begin
            irq_agt.drv.vif = irq_vif;
            irq_agt.mon.vif = irq_vif;
        end

        if (uvm_config_db#(virtual jtag_if)::get(this, "", "jtag_vif", jtag_vif)) begin
            jtag_agt.drv.vif = jtag_vif;
            jtag_agt.mon.vif = jtag_vif;
        end

        // Connect Agent Monitor Analysis Ports to Scoreboard Exports
        uart_agt.mon.ap.connect(sb.uart_export);
        gpio_agt.mon.ap.connect(sb.gpio_export);
        irq_agt.mon.ap.connect(sb.irq_export);
    endfunction
endclass

`endif // SOC_ENV_SV
