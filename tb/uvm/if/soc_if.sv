// =============================================================================
// File   : soc_if.sv
// Module : soc_if
// Purpose: Unified SystemVerilog physical interface for CNN Anomaly Detection SoC.
//          Binds top-level ports and internal AXI bus probes for UVM verification.
// =============================================================================

`timescale 1ns/1ps

interface soc_if (
    input logic clk,
    input logic rst_l
);

    // -------------------------------------------------------------------------
    // Top-Level External I/O Signals
    // -------------------------------------------------------------------------
    logic        uart_tx_o;
    logic        uart_rx_i;

    logic [31:0] gpio_o;
    logic [31:0] gpio_i;
    logic [31:0] gpio_dir_o;

    logic        uart_irq_o;
    logic        cnn_irq_o;
    logic        dist_irq_o;
    logic        timer_irq_o;
    logic        gpio_irq_o;
    logic        dma_irq_o;

    // -------------------------------------------------------------------------
    // Internal AXI Bus Probes: CNN Accelerator (Interconnect M05)
    // -------------------------------------------------------------------------
    logic        cnn_awvalid;
    logic        cnn_awready;
    logic [31:0] cnn_awaddr;
    logic        cnn_wvalid;
    logic        cnn_wready;
    logic [31:0] cnn_wdata;
    logic [3:0]  cnn_wstrb;

    logic        cnn_arvalid;
    logic        cnn_arready;
    logic [31:0] cnn_araddr;
    logic        cnn_rvalid;
    logic        cnn_rready;
    logic [31:0] cnn_rdata;
    logic [1:0]  cnn_rresp;

    // -------------------------------------------------------------------------
    // Internal AXI Bus Probes: Distance Engine (Interconnect M06)
    // -------------------------------------------------------------------------
    logic        dist_awvalid;
    logic        dist_awready;
    logic [31:0] dist_awaddr;
    logic        dist_wvalid;
    logic        dist_wready;
    logic [31:0] dist_wdata;
    logic [3:0]  dist_wstrb;

    logic        dist_arvalid;
    logic        dist_arready;
    logic [31:0] dist_araddr;
    logic        dist_rvalid;
    logic        dist_rready;
    logic [31:0] dist_rdata;
    logic [1:0]  dist_rresp;

    // -------------------------------------------------------------------------
    // Internal AXI Bus Probes: DMA Controller (Interconnect M07 CSR)
    // -------------------------------------------------------------------------
    logic        dma_awvalid;
    logic        dma_awready;
    logic [31:0] dma_awaddr;
    logic        dma_wvalid;
    logic        dma_wready;
    logic [31:0] dma_wdata;

    logic        dma_arvalid;
    logic        dma_arready;
    logic [31:0] dma_araddr;
    logic        dma_rvalid;
    logic        dma_rready;
    logic [31:0] dma_rdata;

    // -------------------------------------------------------------------------
    // Mailbox Probe (from DMEM location 0x1000_FF00)
    // -------------------------------------------------------------------------
    logic [31:0] mailbox_val;

endinterface : soc_if
