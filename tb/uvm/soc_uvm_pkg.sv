// =============================================================================
// File   : soc_uvm_pkg.sv
// Package: soc_uvm_pkg
// Purpose: Master UVM package compiling all items, monitors, agents, and tests
// =============================================================================

`ifndef SOC_UVM_PKG_SV
`define SOC_UVM_PKG_SV

`timescale 1ns/1ps

package soc_uvm_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // 1. UART Agent Components
    `include "agents/uart_agent/uart_seq_item.sv"
    `include "agents/uart_agent/uart_monitor.sv"
    `include "agents/uart_agent/uart_agent.sv"

    // 2. GPIO Agent Components
    `include "agents/gpio_agent/gpio_seq_item.sv"
    `include "agents/gpio_agent/gpio_monitor.sv"
    `include "agents/gpio_agent/gpio_agent.sv"

    // 3. CNN Accelerator Agent Components
    `include "agents/cnn_agent/cnn_seq_item.sv"
    `include "agents/cnn_agent/cnn_monitor.sv"
    `include "agents/cnn_agent/cnn_agent.sv"

    // 4. Distance Engine Agent Components
    `include "agents/dist_agent/dist_seq_item.sv"
    `include "agents/dist_agent/dist_monitor.sv"
    `include "agents/dist_agent/dist_agent.sv"

    // 5. DMA Controller Agent Components
    `include "agents/dma_agent/dma_seq_item.sv"
    `include "agents/dma_agent/dma_monitor.sv"
    `include "agents/dma_agent/dma_agent.sv"

    // 6. Scoreboard & Environment
    `include "env/soc_scoreboard.sv"
    `include "env/soc_env.sv"

    // 7. UVM Tests
    `include "tests/soc_base_test.sv"
    `include "tests/soc_anomaly_test.sv"

endpackage : soc_uvm_pkg

`endif // SOC_UVM_PKG_SV
