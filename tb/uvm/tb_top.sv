// =============================================================================
// File   : tb_top.sv
// Purpose: Top-level SystemVerilog UVM Testbench for VeeR-EL2 CNN SoC.
//          Binds DUT to all 5 External VIP Interfaces and launches UVM.
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

import uvm_pkg::*;
`include "uvm_macros.svh"
import soc_uvm_pkg::*;

module tb_top;

    // -------------------------------------------------------------------------
    // 1. Root Master Clock Generation (100 MHz, Period = 10 ns)
    // -------------------------------------------------------------------------
    logic root_clk = 0;
    always #5 root_clk = ~root_clk;

    // -------------------------------------------------------------------------
    // 2. Instantiate the 5 External VIP Interfaces
    // -------------------------------------------------------------------------
    clk_rst_if clk_rst_vif();
    uart_if    uart_vif();
    gpio_if    gpio_vif();
    irq_if     irq_vif();
    jtag_if    jtag_vif();

    // Distribute clock and resets to all interfaces
    assign clk_rst_vif.clk = root_clk;
    assign uart_vif.clk    = root_clk;
    assign gpio_vif.clk    = root_clk;
    assign irq_vif.clk     = root_clk;

    assign uart_vif.rst_l = clk_rst_vif.rst_l;
    assign gpio_vif.rst_l = clk_rst_vif.rst_l;
    assign irq_vif.rst_l  = clk_rst_vif.rst_l;

    // Route peripheral IRQ outputs to the IRQ monitor interface
    assign irq_vif.uart_irq_o = uart_vif.uart_irq_o;
    assign irq_vif.gpio_irq_o = gpio_vif.gpio_irq_o;

    // -------------------------------------------------------------------------
    // 3. Instantiate Design Under Test (DUT: cnn_soc_top)
    // -------------------------------------------------------------------------
    cnn_soc_top u_dut (
        // Primary Clocks and Resets
        .clk                 (clk_rst_vif.clk),
        .rst_l               (clk_rst_vif.rst_l),
        .dbg_rst_l           (clk_rst_vif.dbg_rst_l),

        // UART Serial Interface
        .uart_rx_i          (uart_vif.uart_rx_i),
        .uart_tx_o          (uart_vif.uart_tx_o),
        .uart_irq_o         (uart_vif.uart_irq_o),

        // On-Chip Accelerators and Peripheral Interrupts
        .cnn_irq_o          (irq_vif.cnn_irq_o),
        .dist_irq_o         (irq_vif.dist_irq_o),
        .timer_irq_o        (irq_vif.timer_irq_o),
        .gpio_irq_o         (gpio_vif.gpio_irq_o),
        .dma_irq_o          (irq_vif.dma_irq_o),

        // Parallel GPIO Interface
        .gpio_i             (gpio_vif.gpio_i),
        .gpio_o             (gpio_vif.gpio_o),
        .gpio_dir_o         (gpio_vif.gpio_dir_o),

        // JTAG Debug Tap Interface
        .jtag_tck           (jtag_vif.jtag_tck),
        .jtag_tms           (jtag_vif.jtag_tms),
        .jtag_tdi           (jtag_vif.jtag_tdi),
        .jtag_trst_n        (jtag_vif.jtag_trst_n),
        .jtag_tdo           (jtag_vif.jtag_tdo),
        .jtag_tdoEn         (jtag_vif.jtag_tdoEn),

        // External Interrupt Lines to Core PIC
        .timer_int          (irq_vif.timer_int),
        .soft_int           (irq_vif.soft_int),

        // CPU Execution Control (Tied Off)
        .i_cpu_halt_req     (1'b0),
        .i_cpu_run_req      (1'b0),
        .o_cpu_halt_ack     (),
        .o_cpu_halt_status  (),
        .o_cpu_run_ack      (),
        .o_debug_mode_status()
    );

    // -------------------------------------------------------------------------
    // 4. Initial Stimulus, Firmware Preload & UVM Launch
    // -------------------------------------------------------------------------
    string hex_file;

    // Reset Sequence: Runs concurrently from time 0
    initial begin
        clk_rst_vif.rst_l     = 1'b0;
        clk_rst_vif.dbg_rst_l = 1'b0;

        repeat (20) @(posedge root_clk);
        clk_rst_vif.rst_l     = 1'b1;
        clk_rst_vif.dbg_rst_l = 1'b1;
        $display("[UVM_TOP] Reset deasserted; VeeR-EL2 CPU boot initiated.");
    end

    // UVM Registration & Launch at Time 0
    initial begin
        // Static Default Pin States
        uart_vif.uart_rx_i   = 1'b1;  // UART serial line idle high
        gpio_vif.gpio_i      = 32'h0;
        irq_vif.timer_int    = 1'b0;
        irq_vif.soft_int     = 1'b0;
        jtag_vif.jtag_tck    = 1'b0;
        jtag_vif.jtag_tms    = 1'b0;
        jtag_vif.jtag_tdi    = 1'b0;
        jtag_vif.jtag_trst_n = 1'b1;

        // Register All 5 Virtual Interfaces in UVM Configuration Database
        uvm_config_db#(virtual clk_rst_if)::set(null, "*", "clk_rst_vif", clk_rst_vif);
        uvm_config_db#(virtual uart_if)::set(null, "*", "uart_vif", uart_vif);
        uvm_config_db#(virtual gpio_if)::set(null, "*", "gpio_vif", gpio_vif);
        uvm_config_db#(virtual irq_if)::set(null, "*", "irq_vif", irq_vif);
        uvm_config_db#(virtual jtag_if)::set(null, "*", "jtag_vif", jtag_vif);

        // Preload Firmware into Instruction Memory
        if (!$value$plusargs("hex=%s", hex_file)) begin
            hex_file = "sw/riscv_test/simple_test.hex";
        end
        $display("[UVM_TOP] Preloading IMEM with firmware: %s", hex_file);
        $readmemh(hex_file, u_dut.u_imem.mem);

        // Setup FSDB Waveform Dumping for Synopsys Verdi
        `ifdef DUMP_FSDB
            $fsdbDumpfile("build_soc/uvm_soc_sim.fsdb");
            $fsdbDumpvars(0, tb_top);
            $fsdbDumpMDA();
        `endif

        // Hand over execution control to UVM Test at time 0
        run_test();
    end

    // Simulation Watchdog Timer (Safety limit 10 ms)
    initial begin
        #10ms;
        $display("[UVM_TOP] ERROR: Simulation Watchdog Timeout reached!");
        $finish(2);
    end

endmodule

`default_nettype wire
