// =============================================================================
// File   : soc_uvm_pkg.sv
// Purpose: Unified package integrating all 5 VIP packages, env, and tests.
// =============================================================================

`ifndef SOC_UVM_PKG_SV
`define SOC_UVM_PKG_SV

package soc_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Import the 5 generated VIP packages
    import clk_rst_pkg::*;
    import uart_pkg::*;
    import gpio_pkg::*;
    import irq_pkg::*;
    import jtag_pkg::*;

    // Include top-level environment & tests
    `include "soc_scoreboard.sv"
    `include "soc_env.sv"
    `include "soc_base_test.sv"
    `include "soc_interactive_test.sv"
    `include "tests.svh"

endpackage : soc_uvm_pkg

`endif // SOC_UVM_PKG_SV
