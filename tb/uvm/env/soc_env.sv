// =============================================================================
// File   : soc_env.sv
// Class  : soc_env
// Purpose: UVM Environment instantiating all 5 agents and the Scoreboard
// =============================================================================

`ifndef SOC_ENV_SV
`define SOC_ENV_SV

class soc_env extends uvm_env;
    `uvm_component_utils(soc_env)

    // 5 Dedicated Agents
    uart_agent     m_uart_agent;
    gpio_agent     m_gpio_agent;
    cnn_agent      m_cnn_agent;
    dist_agent     m_dist_agent;
    dma_agent      m_dma_agent;

    // Central Scoreboard
    soc_scoreboard m_scoreboard;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        m_uart_agent = uart_agent::type_id::create("m_uart_agent", this);
        m_gpio_agent = gpio_agent::type_id::create("m_gpio_agent", this);
        m_cnn_agent  = cnn_agent::type_id::create("m_cnn_agent",   this);
        m_dist_agent = dist_agent::type_id::create("m_dist_agent", this);
        m_dma_agent  = dma_agent::type_id::create("m_dma_agent",   this);

        m_scoreboard = soc_scoreboard::type_id::create("m_scoreboard", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect 5 Agent analysis ports to Scoreboard exports
        m_uart_agent.ap.connect(m_scoreboard.uart_export);
        m_gpio_agent.ap.connect(m_scoreboard.gpio_export);
        m_cnn_agent.ap.connect(m_scoreboard.cnn_export);
        m_dist_agent.ap.connect(m_scoreboard.dist_export);
        m_dma_agent.ap.connect(m_scoreboard.dma_export);
    endfunction

endclass : soc_env

`endif // SOC_ENV_SV
