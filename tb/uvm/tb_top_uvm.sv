// =============================================================================
// File   : tb_top_uvm.sv
// Module : tb_top_uvm
// Purpose: Top-level UVM Testbench Harness for CNN Anomaly Detection SoC.
//          Instantiates DUT, physical interface with probes, preloads firmware,
//          registers interface with uvm_config_db, and invokes run_test().
// =============================================================================

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import soc_uvm_pkg::*;

module tb_top_uvm;

    localparam real CLK_PERIOD_NS = 10.0; // 100 MHz clock

    // -------------------------------------------------------------------------
    // Clocks and Resets
    // -------------------------------------------------------------------------
    logic clk;
    logic rst_l;
    logic dbg_rst_l;

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD_NS / 2.0) clk = ~clk;
    end

    // -------------------------------------------------------------------------
    // Top-Level I/O Wires
    // -------------------------------------------------------------------------
    logic        uart_rx_i;
    wire         uart_tx_o;
    wire         uart_irq_o;
    wire         cnn_irq_o;
    wire         dist_irq_o;
    wire         timer_irq_o;
    wire         gpio_irq_o;
    wire         dma_irq_o;

    logic [31:0] gpio_i;
    wire  [31:0] gpio_o;
    wire  [31:0] gpio_dir_o;

    logic        jtag_tck, jtag_tms, jtag_tdi, jtag_trst_n;
    wire         jtag_tdo, jtag_tdoEn;
    logic        timer_int, soft_int;
    logic        i_cpu_halt_req, i_cpu_run_req;
    wire         o_cpu_halt_ack, o_cpu_halt_status, o_cpu_run_ack, o_debug_mode_status;

    // -------------------------------------------------------------------------
    // Physical UVM Interface
    // -------------------------------------------------------------------------
    soc_if vif (
        .clk   (clk),
        .rst_l (rst_l)
    );

    // -------------------------------------------------------------------------
    // DUT: CNN Anomaly Detection SoC Top
    // -------------------------------------------------------------------------
    cnn_soc_top u_soc (
        .clk                 (clk),
        .rst_l               (rst_l),
        .dbg_rst_l           (dbg_rst_l),

        .uart_rx_i           (uart_rx_i),
        .uart_tx_o           (uart_tx_o),
        .uart_irq_o          (uart_irq_o),
        .cnn_irq_o           (cnn_irq_o),
        .dist_irq_o          (dist_irq_o),
        .timer_irq_o         (timer_irq_o),
        .gpio_irq_o          (gpio_irq_o),
        .dma_irq_o           (dma_irq_o),
        .gpio_i              (gpio_i),
        .gpio_o              (gpio_o),
        .gpio_dir_o          (gpio_dir_o),

        .jtag_tck            (jtag_tck),
        .jtag_tms            (jtag_tms),
        .jtag_tdi            (jtag_tdi),
        .jtag_trst_n         (jtag_trst_n),
        .jtag_tdo            (jtag_tdo),
        .jtag_tdoEn          (jtag_tdoEn),

        .timer_int           (timer_int),
        .soft_int            (soft_int),
        .i_cpu_halt_req      (i_cpu_halt_req),
        .i_cpu_run_req       (i_cpu_run_req),
        .o_cpu_halt_ack      (o_cpu_halt_ack),
        .o_cpu_halt_status   (o_cpu_halt_status),
        .o_cpu_run_ack       (o_cpu_run_ack),
        .o_debug_mode_status (o_debug_mode_status)
    );

    // -------------------------------------------------------------------------
    // Connect Interface Probes to DUT
    // -------------------------------------------------------------------------
    assign vif.uart_tx_o   = uart_tx_o;
    assign vif.uart_rx_i   = uart_rx_i;
    assign vif.gpio_o      = gpio_o;
    assign vif.gpio_i      = gpio_i;
    assign vif.gpio_dir_o  = gpio_dir_o;

    assign vif.uart_irq_o  = uart_irq_o;
    assign vif.cnn_irq_o   = cnn_irq_o;
    assign vif.dist_irq_o  = dist_irq_o;
    assign vif.timer_irq_o = timer_irq_o;
    assign vif.gpio_irq_o  = gpio_irq_o;
    assign vif.dma_irq_o   = dma_irq_o;

    // CNN AXI Probes (M05)
    assign vif.cnn_awvalid = u_soc.m05_axi_awvalid;
    assign vif.cnn_awready = u_soc.m05_axi_awready;
    assign vif.cnn_awaddr  = u_soc.m05_axi_awaddr;
    assign vif.cnn_wvalid  = u_soc.m05_axi_wvalid;
    assign vif.cnn_wready  = u_soc.m05_axi_wready;
    assign vif.cnn_wdata   = u_soc.m05_axi_wdata;
    assign vif.cnn_wstrb   = u_soc.m05_axi_wstrb;
    assign vif.cnn_arvalid = u_soc.m05_axi_arvalid;
    assign vif.cnn_arready = u_soc.m05_axi_arready;
    assign vif.cnn_araddr  = u_soc.m05_axi_araddr;
    assign vif.cnn_rvalid  = u_soc.m05_axi_rvalid;
    assign vif.cnn_rready  = u_soc.m05_axi_rready;
    assign vif.cnn_rdata   = u_soc.m05_axi_rdata;
    assign vif.cnn_rresp   = u_soc.m05_axi_rresp;

    // Distance AXI Probes (M06)
    assign vif.dist_awvalid = u_soc.m06_axi_awvalid;
    assign vif.dist_awready = u_soc.m06_axi_awready;
    assign vif.dist_awaddr  = u_soc.m06_axi_awaddr;
    assign vif.dist_wvalid  = u_soc.m06_axi_wvalid;
    assign vif.dist_wready  = u_soc.m06_axi_wready;
    assign vif.dist_wdata   = u_soc.m06_axi_wdata;
    assign vif.dist_wstrb   = u_soc.m06_axi_wstrb;
    assign vif.dist_arvalid = u_soc.m06_axi_arvalid;
    assign vif.dist_arready = u_soc.m06_axi_arready;
    assign vif.dist_araddr  = u_soc.m06_axi_araddr;
    assign vif.dist_rvalid  = u_soc.m06_axi_rvalid;
    assign vif.dist_rready  = u_soc.m06_axi_rready;
    assign vif.dist_rdata   = u_soc.m06_axi_rdata;
    assign vif.dist_rresp   = u_soc.m06_axi_rresp;

    // DMA AXI Probes (M07 CSR)
    assign vif.dma_awvalid = u_soc.m07_axi_awvalid;
    assign vif.dma_awready = u_soc.m07_axi_awready;
    assign vif.dma_awaddr  = u_soc.m07_axi_awaddr;
    assign vif.dma_wvalid  = u_soc.m07_axi_wvalid;
    assign vif.dma_wready  = u_soc.m07_axi_wready;
    assign vif.dma_wdata   = u_soc.m07_axi_wdata;
    assign vif.dma_arvalid = u_soc.m07_axi_arvalid;
    assign vif.dma_arready = u_soc.m07_axi_arready;
    assign vif.dma_araddr  = u_soc.m07_axi_araddr;
    assign vif.dma_rvalid  = u_soc.m07_axi_rvalid;
    assign vif.dma_rready  = u_soc.m07_axi_rready;
    assign vif.dma_rdata   = u_soc.m07_axi_rdata;

    // -------------------------------------------------------------------------
    // Testbench Control, Firmware Preload & UVM Invocation
    // -------------------------------------------------------------------------
    string hex_file;

    initial begin
        // Static tie-offs
        uart_rx_i      = 1'b1; // Idle high
        gpio_i         = 32'h0;
        jtag_tck       = 1'b0;
        jtag_tms       = 1'b0;
        jtag_tdi       = 1'b0;
        jtag_trst_n    = 1'b1;
        timer_int      = 1'b0;
        soft_int       = 1'b0;
        i_cpu_halt_req = 1'b0;
        i_cpu_run_req  = 1'b0;

        // Reset asserted
        rst_l     = 1'b0;
        // Preload IMEM at time 0
        if (!$value$plusargs("hex=%s", hex_file)) begin
            hex_file = "sw/hello_uart/boot.hex";
        end
        $display("[UVM_TOP] Preloading IMEM with firmware: %s", hex_file);
        $readmemh(hex_file, u_soc.u_imem.mem);
        $display("[UVM_TOP] Preload completed successfully.");

        // Waveform dumping support for Verdi
        if ($test$plusargs("fsdb") || $test$plusargs("dump")) begin
            $display("[UVM_TOP] Enabling Verdi FSDB waveform dump -> build_uvm/soc_uvm.fsdb");
            $fsdbDumpfile("build_uvm/soc_uvm.fsdb");
            $fsdbDumpvars(0, tb_top_uvm);
        end

        // Register virtual interface into UVM config db
        uvm_config_db#(virtual soc_if)::set(null, "*", "vif", vif);

        // Kick off UVM test at time 0
        run_test();
    end

    // -------------------------------------------------------------------------
    // Parallel Hardware Reset Sequence
    // -------------------------------------------------------------------------
    initial begin
        rst_l     = 1'b0;
        dbg_rst_l = 1'b0;
        #(CLK_PERIOD_NS * 10);
        @(posedge clk);
        rst_l     = 1'b1;
        dbg_rst_l = 1'b1;
        $display("[UVM_TOP] Hardware reset deasserted. CPU begins autonomous fetch.\n");
    end

endmodule : tb_top_uvm
