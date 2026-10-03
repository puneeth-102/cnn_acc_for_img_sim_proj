// =============================================================================
// CNN Anomaly Detection SoC — Top-Level Integration
// File   : cnn_soc_top.sv
// Purpose: Connects el2_veer_wrapper (RISC-V CPU) to axi_interconnect_wrap_2x8
//          via Option-A routing:
//            • IFU (instruction fetch) → direct 64→32-bit adapter → IMEM slave
//            • LSU (load/store)        → 64→32-bit adapter → interconnect s00
//          Eight decoded slave ports:
//            m00 → IMEM           (0x0000_0000 – 0x0000_FFFF)
//            m01 → DMEM           (0x1000_0000 – 0x1000_FFFF)
//            m02 → UART           (0x2000_0000 – 0x2000_0FFF)
//            m03 → Timer stub     (0x2000_1000 – 0x2000_1FFF)
//            m04 → GPIO stub      (0x2000_2000 – 0x2000_2FFF)
//            m05 → CNN AXI wrapper(0x2000_3000 – 0x2000_3FFF)
//            m06 → Distance stub  (0x2000_4000 – 0x2000_4FFF)
//            m07 → DMA reg stub   (0x2000_5000 – 0x2000_5FFF)
//          Interconnect s01 (DMA master) is tied off (no external DMA master yet).
//
// Include path assumptions (adjust for your simulator/tool):
//   +incdir+rtl/Cores-VeeR-EL2/snapshots/default
//   +incdir+rtl/uart/include
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

// Pull in VeeR build flags (defines RV_BUILD_AXI4, bus-tag widths, etc.)
`include "common_defines.vh"

module cnn_soc_top (
    // -------------------------------------------------------------------------
    // Primary clocks and resets
    // -------------------------------------------------------------------------
    input  logic        clk,          // System clock (all synchronous logic)
    input  logic        rst_l,        // Active-low synchronous reset (VeeR convention)
    input  logic        dbg_rst_l,    // Debug reset, active-low

    // -------------------------------------------------------------------------
    // UART I/O (brought to top level)
    // -------------------------------------------------------------------------
    input  logic        uart_rx_i,
    output logic        uart_tx_o,
    output logic        uart_irq_o,   // read_interrupt_o from axi_uart_top
    output logic        cnn_irq_o,    // accel_done_irq from cnn_axi_wrapper
    output logic        dist_irq_o,   // score_done_irq from distance_axi_wrapper
    output logic        timer_irq_o,  // timer_irq_o from timer_axi_wrapper
    output logic        gpio_irq_o,   // global_interrupt_o from gpio_axi_wrapper
    input  logic [31:0] gpio_i,       // External GPIO inputs
    output logic [31:0] gpio_o,       // External GPIO outputs
    output logic [31:0] gpio_dir_o,   // External GPIO direction (1=output, 0=input)

    // -------------------------------------------------------------------------
    // JTAG (debug)
    // -------------------------------------------------------------------------
    input  logic        jtag_tck,
    input  logic        jtag_tms,
    input  logic        jtag_tdi,
    input  logic        jtag_trst_n,
    output logic        jtag_tdo,
    output logic        jtag_tdoEn,

    // -------------------------------------------------------------------------
    // Interrupt sources (external → PIC)
    // -------------------------------------------------------------------------
    input  logic        timer_int,    // Machine timer interrupt
    input  logic        soft_int,     // Software interrupt

    // -------------------------------------------------------------------------
    // CPU halt/run (MPC interface, brought out for PMU/test use)
    // -------------------------------------------------------------------------
    input  logic        i_cpu_halt_req,
    input  logic        i_cpu_run_req,
    output logic        o_cpu_halt_ack,
    output logic        o_cpu_halt_status,
    output logic        o_cpu_run_ack,
    output logic        o_debug_mode_status
);

// =============================================================================
// Local parameters
// =============================================================================

// Widths as used inside el2_veer_wrapper (from common_defines.vh)
localparam int LSU_BUS_TAG = `RV_LSU_BUS_TAG;   // 3
localparam int IFU_BUS_TAG = `RV_IFU_BUS_TAG;   // 3
localparam int DMA_BUS_TAG = `RV_DMA_BUS_TAG;   // 1
localparam int SB_BUS_TAG  = `RV_SB_BUS_TAG;    // 1

// Interconnect widths
localparam int IC_DATA = 32;
localparam int IC_ADDR = 32;
localparam int IC_STRB = IC_DATA / 8;  // 4
localparam int IC_ID   = 8;

// VeeR external data bus is 64-bit; interconnect is 32-bit
localparam int VR_DATA = 64;
localparam int VR_STRB = VR_DATA / 8;  // 8

// PIC external interrupt count (from param: PIC_TOTAL_INT = 31)
localparam int PIC_INTS = `RV_PIC_TOTAL_INT;   // 31

// UART ID width (from axi_uart_defines.vh: _AXI_UART_ID_WIDTH_ = 12)
localparam int UART_ID = 12;


// =============================================================================
// ① VeeR LSU AXI master wires  (64-bit data, LSU_BUS_TAG-bit IDs)
//    Source: el2_veer_wrapper lsu_axi_* outputs
// =============================================================================

// --- Write address channel ---
logic                       lsu_axi_awvalid;
logic                       lsu_axi_awready;
logic [LSU_BUS_TAG-1:0]     lsu_axi_awid;
logic [31:0]                lsu_axi_awaddr;
logic [3:0]                 lsu_axi_awregion;
logic [7:0]                 lsu_axi_awlen;
logic [2:0]                 lsu_axi_awsize;
logic [1:0]                 lsu_axi_awburst;
logic                       lsu_axi_awlock;
logic [3:0]                 lsu_axi_awcache;
logic [2:0]                 lsu_axi_awprot;
logic [3:0]                 lsu_axi_awqos;
// --- Write data channel ---
logic                       lsu_axi_wvalid;
logic                       lsu_axi_wready;
logic [VR_DATA-1:0]         lsu_axi_wdata;   // 64-bit
logic [VR_STRB-1:0]         lsu_axi_wstrb;   // 8-bit
logic                       lsu_axi_wlast;
// --- Write response channel ---
logic                       lsu_axi_bvalid;
logic                       lsu_axi_bready;
logic [1:0]                 lsu_axi_bresp;
logic [LSU_BUS_TAG-1:0]     lsu_axi_bid;
// --- Read address channel ---
logic                       lsu_axi_arvalid;
logic                       lsu_axi_arready;
logic [LSU_BUS_TAG-1:0]     lsu_axi_arid;
logic [31:0]                lsu_axi_araddr;
logic [3:0]                 lsu_axi_arregion;
logic [7:0]                 lsu_axi_arlen;
logic [2:0]                 lsu_axi_arsize;
logic [1:0]                 lsu_axi_arburst;
logic                       lsu_axi_arlock;
logic [3:0]                 lsu_axi_arcache;
logic [2:0]                 lsu_axi_arprot;
logic [3:0]                 lsu_axi_arqos;
// --- Read data channel ---
logic                       lsu_axi_rvalid;
logic                       lsu_axi_rready;
logic [LSU_BUS_TAG-1:0]     lsu_axi_rid;
logic [VR_DATA-1:0]         lsu_axi_rdata;   // 64-bit
logic [1:0]                 lsu_axi_rresp;
logic                       lsu_axi_rlast;

// =============================================================================
// ② VeeR IFU AXI master wires  (64-bit data, IFU_BUS_TAG-bit IDs)
//    Option A: IFU bypasses interconnect, goes directly to IMEM slave.
// =============================================================================

logic                       ifu_axi_awvalid;
logic                       ifu_axi_awready;
logic [IFU_BUS_TAG-1:0]     ifu_axi_awid;
logic [31:0]                ifu_axi_awaddr;
logic [3:0]                 ifu_axi_awregion;
logic [7:0]                 ifu_axi_awlen;
logic [2:0]                 ifu_axi_awsize;
logic [1:0]                 ifu_axi_awburst;
logic                       ifu_axi_awlock;
logic [3:0]                 ifu_axi_awcache;
logic [2:0]                 ifu_axi_awprot;
logic [3:0]                 ifu_axi_awqos;

logic                       ifu_axi_wvalid;
logic                       ifu_axi_wready;
logic [VR_DATA-1:0]         ifu_axi_wdata;
logic [VR_STRB-1:0]         ifu_axi_wstrb;
logic                       ifu_axi_wlast;

logic                       ifu_axi_bvalid;
logic                       ifu_axi_bready;
logic [1:0]                 ifu_axi_bresp;
logic [IFU_BUS_TAG-1:0]     ifu_axi_bid;

logic                       ifu_axi_arvalid;
logic                       ifu_axi_arready;
logic [IFU_BUS_TAG-1:0]     ifu_axi_arid;
logic [31:0]                ifu_axi_araddr;
logic [3:0]                 ifu_axi_arregion;
logic [7:0]                 ifu_axi_arlen;
logic [2:0]                 ifu_axi_arsize;
logic [1:0]                 ifu_axi_arburst;
logic                       ifu_axi_arlock;
logic [3:0]                 ifu_axi_arcache;
logic [2:0]                 ifu_axi_arprot;
logic [3:0]                 ifu_axi_arqos;

logic                       ifu_axi_rvalid;
logic                       ifu_axi_rready;
logic [IFU_BUS_TAG-1:0]     ifu_axi_rid;
logic [VR_DATA-1:0]         ifu_axi_rdata;
logic [1:0]                 ifu_axi_rresp;
logic                       ifu_axi_rlast;

// =============================================================================
// ③ VeeR SB (System Bus / debug) AXI master — tied off (not connected to fabric)
// =============================================================================

logic                       sb_axi_awvalid;
logic                       sb_axi_awready;
logic [SB_BUS_TAG-1:0]      sb_axi_awid;
logic [31:0]                sb_axi_awaddr;
logic [3:0]                 sb_axi_awregion;
logic [7:0]                 sb_axi_awlen;
logic [2:0]                 sb_axi_awsize;
logic [1:0]                 sb_axi_awburst;
logic                       sb_axi_awlock;
logic [3:0]                 sb_axi_awcache;
logic [2:0]                 sb_axi_awprot;
logic [3:0]                 sb_axi_awqos;
logic                       sb_axi_wvalid;
logic                       sb_axi_wready;
logic [VR_DATA-1:0]         sb_axi_wdata;
logic [VR_STRB-1:0]         sb_axi_wstrb;
logic                       sb_axi_wlast;
logic                       sb_axi_bvalid;
logic                       sb_axi_bready;
logic [1:0]                 sb_axi_bresp;
logic [SB_BUS_TAG-1:0]      sb_axi_bid;
logic                       sb_axi_arvalid;
logic                       sb_axi_arready;
logic [SB_BUS_TAG-1:0]      sb_axi_arid;
logic [31:0]                sb_axi_araddr;
logic [3:0]                 sb_axi_arregion;
logic [7:0]                 sb_axi_arlen;
logic [2:0]                 sb_axi_arsize;
logic [1:0]                 sb_axi_arburst;
logic                       sb_axi_arlock;
logic [3:0]                 sb_axi_arcache;
logic [2:0]                 sb_axi_arprot;
logic [3:0]                 sb_axi_arqos;
logic                       sb_axi_rvalid;
logic                       sb_axi_rready;
logic [SB_BUS_TAG-1:0]      sb_axi_rid;
logic [VR_DATA-1:0]         sb_axi_rdata;
logic [1:0]                 sb_axi_rresp;
logic                       sb_axi_rlast;

// =============================================================================
// ④ VeeR DMA AXI slave wires  (64-bit, DMA_BUS_TAG IDs)
//    DMA master port (s01) is unused in this integration; tie off DMA slave.
// =============================================================================

logic                       dma_axi_awvalid;
logic                       dma_axi_awready;
logic [DMA_BUS_TAG-1:0]     dma_axi_awid;
logic [31:0]                dma_axi_awaddr;
logic [2:0]                 dma_axi_awsize;
logic [2:0]                 dma_axi_awprot;
logic [7:0]                 dma_axi_awlen;
logic [1:0]                 dma_axi_awburst;
logic                       dma_axi_wvalid;
logic                       dma_axi_wready;
logic [VR_DATA-1:0]         dma_axi_wdata;
logic [VR_STRB-1:0]         dma_axi_wstrb;
logic                       dma_axi_wlast;
logic                       dma_axi_bvalid;
logic                       dma_axi_bready;
logic [1:0]                 dma_axi_bresp;
logic [DMA_BUS_TAG-1:0]     dma_axi_bid;
logic                       dma_axi_arvalid;
logic                       dma_axi_arready;
logic [DMA_BUS_TAG-1:0]     dma_axi_arid;
logic [31:0]                dma_axi_araddr;
logic [2:0]                 dma_axi_arsize;
logic [2:0]                 dma_axi_arprot;
logic [7:0]                 dma_axi_arlen;
logic [1:0]                 dma_axi_arburst;
logic                       dma_axi_rvalid;
logic                       dma_axi_rready;
logic [DMA_BUS_TAG-1:0]     dma_axi_rid;
logic [VR_DATA-1:0]         dma_axi_rdata;
logic [1:0]                 dma_axi_rresp;
logic                       dma_axi_rlast;


// =============================================================================
// ⑤ Interconnect s00 wires — CPU master, 32-bit data, 8-bit IDs
//    These are driven by the LSU 64→32 width adapter (see Section ⑧).
// =============================================================================

logic [IC_ID-1:0]   s00_axi_awid;
logic [IC_ADDR-1:0] s00_axi_awaddr;
logic [7:0]         s00_axi_awlen;
logic [2:0]         s00_axi_awsize;
logic [1:0]         s00_axi_awburst;
logic               s00_axi_awlock;
logic [3:0]         s00_axi_awcache;
logic [2:0]         s00_axi_awprot;
logic [3:0]         s00_axi_awqos;
logic               s00_axi_awvalid;
logic               s00_axi_awready;
logic [IC_DATA-1:0] s00_axi_wdata;
logic [IC_STRB-1:0] s00_axi_wstrb;
logic               s00_axi_wlast;
logic               s00_axi_wvalid;
logic               s00_axi_wready;
logic [IC_ID-1:0]   s00_axi_bid;
logic [1:0]         s00_axi_bresp;
logic               s00_axi_bvalid;
logic               s00_axi_bready;
logic [IC_ID-1:0]   s00_axi_arid;
logic [IC_ADDR-1:0] s00_axi_araddr;
logic [7:0]         s00_axi_arlen;
logic [2:0]         s00_axi_arsize;
logic [1:0]         s00_axi_arburst;
logic               s00_axi_arlock;
logic [3:0]         s00_axi_arcache;
logic [2:0]         s00_axi_arprot;
logic [3:0]         s00_axi_arqos;
logic               s00_axi_arvalid;
logic               s00_axi_arready;
logic [IC_ID-1:0]   s00_axi_rid;
logic [IC_DATA-1:0] s00_axi_rdata;
logic [1:0]         s00_axi_rresp;
logic               s00_axi_rlast;
logic               s00_axi_rvalid;
logic               s00_axi_rready;

// Interconnect s01 (DMA master) — tied off; no external DMA master in this rev
logic [IC_ID-1:0]   s01_axi_awid   = '0;
logic [IC_ADDR-1:0] s01_axi_awaddr = '0;
logic [7:0]         s01_axi_awlen  = '0;
logic [2:0]         s01_axi_awsize = '0;
logic [1:0]         s01_axi_awburst= '0;
logic               s01_axi_awlock = 1'b0;
logic [3:0]         s01_axi_awcache= '0;
logic [2:0]         s01_axi_awprot = '0;
logic [3:0]         s01_axi_awqos  = '0;
logic               s01_axi_awvalid= 1'b0;
logic [IC_DATA-1:0] s01_axi_wdata  = '0;
logic [IC_STRB-1:0] s01_axi_wstrb  = '0;
logic               s01_axi_wlast  = 1'b0;
logic               s01_axi_wvalid = 1'b0;
logic               s01_axi_bready = 1'b1;
logic [IC_ID-1:0]   s01_axi_arid   = '0;
logic [IC_ADDR-1:0] s01_axi_araddr = '0;
logic [7:0]         s01_axi_arlen  = '0;
logic [2:0]         s01_axi_arsize = '0;
logic [1:0]         s01_axi_arburst= '0;
logic               s01_axi_arlock = 1'b0;
logic [3:0]         s01_axi_arcache= '0;
logic [2:0]         s01_axi_arprot = '0;
logic [3:0]         s01_axi_arqos  = '0;
logic               s01_axi_arvalid= 1'b0;
logic               s01_axi_rready = 1'b1;

// =============================================================================
// ⑥  Interconnect master-side wires (m00..m07) — 32-bit, 8-bit IDs
//    Generated by the crossbar; fed to each peripheral slave.
// =============================================================================

// Helper macro: declare one interconnect master port bundle
// (written out explicitly for each port for clean tool compatibility)

// ---- m00 : IMEM ----
logic [IC_ID-1:0]   m00_axi_awid;    logic [IC_ADDR-1:0] m00_axi_awaddr;
logic [7:0]         m00_axi_awlen;   logic [2:0]         m00_axi_awsize;
logic [1:0]         m00_axi_awburst; logic               m00_axi_awlock;
logic [3:0]         m00_axi_awcache; logic [2:0]         m00_axi_awprot;
logic [3:0]         m00_axi_awqos;   logic [3:0]         m00_axi_awregion;
logic               m00_axi_awvalid; logic               m00_axi_awready;
logic [IC_DATA-1:0] m00_axi_wdata;   logic [IC_STRB-1:0] m00_axi_wstrb;
logic               m00_axi_wlast;   logic               m00_axi_wvalid;
logic               m00_axi_wready;
logic [IC_ID-1:0]   m00_axi_bid;     logic [1:0]         m00_axi_bresp;
logic               m00_axi_bvalid;  logic               m00_axi_bready;
logic [IC_ID-1:0]   m00_axi_arid;    logic [IC_ADDR-1:0] m00_axi_araddr;
logic [7:0]         m00_axi_arlen;   logic [2:0]         m00_axi_arsize;
logic [1:0]         m00_axi_arburst; logic               m00_axi_arlock;
logic [3:0]         m00_axi_arcache; logic [2:0]         m00_axi_arprot;
logic [3:0]         m00_axi_arqos;   logic [3:0]         m00_axi_arregion;
logic               m00_axi_arvalid; logic               m00_axi_arready;
logic [IC_ID-1:0]   m00_axi_rid;     logic [IC_DATA-1:0] m00_axi_rdata;
logic [1:0]         m00_axi_rresp;   logic               m00_axi_rlast;
logic               m00_axi_rvalid;  logic               m00_axi_rready;

// ---- m01 : DMEM ----
logic [IC_ID-1:0]   m01_axi_awid;    logic [IC_ADDR-1:0] m01_axi_awaddr;
logic [7:0]         m01_axi_awlen;   logic [2:0]         m01_axi_awsize;
logic [1:0]         m01_axi_awburst; logic               m01_axi_awlock;
logic [3:0]         m01_axi_awcache; logic [2:0]         m01_axi_awprot;
logic [3:0]         m01_axi_awqos;   logic [3:0]         m01_axi_awregion;
logic               m01_axi_awvalid; logic               m01_axi_awready;
logic [IC_DATA-1:0] m01_axi_wdata;   logic [IC_STRB-1:0] m01_axi_wstrb;
logic               m01_axi_wlast;   logic               m01_axi_wvalid;
logic               m01_axi_wready;
logic [IC_ID-1:0]   m01_axi_bid;     logic [1:0]         m01_axi_bresp;
logic               m01_axi_bvalid;  logic               m01_axi_bready;
logic [IC_ID-1:0]   m01_axi_arid;    logic [IC_ADDR-1:0] m01_axi_araddr;
logic [7:0]         m01_axi_arlen;   logic [2:0]         m01_axi_arsize;
logic [1:0]         m01_axi_arburst; logic               m01_axi_arlock;
logic [3:0]         m01_axi_arcache; logic [2:0]         m01_axi_arprot;
logic [3:0]         m01_axi_arqos;   logic [3:0]         m01_axi_arregion;
logic               m01_axi_arvalid; logic               m01_axi_arready;
logic [IC_ID-1:0]   m01_axi_rid;     logic [IC_DATA-1:0] m01_axi_rdata;
logic [1:0]         m01_axi_rresp;   logic               m01_axi_rlast;
logic               m01_axi_rvalid;  logic               m01_axi_rready;

// ---- m02 : UART ----
logic [IC_ID-1:0]   m02_axi_awid;    logic [IC_ADDR-1:0] m02_axi_awaddr;
logic [7:0]         m02_axi_awlen;   logic [2:0]         m02_axi_awsize;
logic [1:0]         m02_axi_awburst; logic               m02_axi_awlock;
logic [3:0]         m02_axi_awcache; logic [2:0]         m02_axi_awprot;
logic [3:0]         m02_axi_awqos;   logic [3:0]         m02_axi_awregion;
logic               m02_axi_awvalid; logic               m02_axi_awready;
logic [IC_DATA-1:0] m02_axi_wdata;   logic [IC_STRB-1:0] m02_axi_wstrb;
logic               m02_axi_wlast;   logic               m02_axi_wvalid;
logic               m02_axi_wready;
logic [IC_ID-1:0]   m02_axi_bid;     logic [1:0]         m02_axi_bresp;
logic               m02_axi_bvalid;  logic               m02_axi_bready;
logic [IC_ID-1:0]   m02_axi_arid;    logic [IC_ADDR-1:0] m02_axi_araddr;
logic [7:0]         m02_axi_arlen;   logic [2:0]         m02_axi_arsize;
logic [1:0]         m02_axi_arburst; logic               m02_axi_arlock;
logic [3:0]         m02_axi_arcache; logic [2:0]         m02_axi_arprot;
logic [3:0]         m02_axi_arqos;   logic [3:0]         m02_axi_arregion;
logic               m02_axi_arvalid; logic               m02_axi_arready;
logic [IC_ID-1:0]   m02_axi_rid;     logic [IC_DATA-1:0] m02_axi_rdata;
logic [1:0]         m02_axi_rresp;   logic               m02_axi_rlast;
logic               m02_axi_rvalid;  logic               m02_axi_rready;

// ---- m03 : Timer stub ----
logic [IC_ID-1:0]   m03_axi_awid;    logic [IC_ADDR-1:0] m03_axi_awaddr;
logic [7:0]         m03_axi_awlen;   logic [2:0]         m03_axi_awsize;
logic [1:0]         m03_axi_awburst; logic               m03_axi_awlock;
logic [3:0]         m03_axi_awcache; logic [2:0]         m03_axi_awprot;
logic [3:0]         m03_axi_awqos;   logic [3:0]         m03_axi_awregion;
logic               m03_axi_awvalid; logic               m03_axi_awready;
logic [IC_DATA-1:0] m03_axi_wdata;   logic [IC_STRB-1:0] m03_axi_wstrb;
logic               m03_axi_wlast;   logic               m03_axi_wvalid;
logic               m03_axi_wready;
logic [IC_ID-1:0]   m03_axi_bid;     logic [1:0]         m03_axi_bresp;
logic               m03_axi_bvalid;  logic               m03_axi_bready;
logic [IC_ID-1:0]   m03_axi_arid;    logic [IC_ADDR-1:0] m03_axi_araddr;
logic [7:0]         m03_axi_arlen;   logic [2:0]         m03_axi_arsize;
logic [1:0]         m03_axi_arburst; logic               m03_axi_arlock;
logic [3:0]         m03_axi_arcache; logic [2:0]         m03_axi_arprot;
logic [3:0]         m03_axi_arqos;   logic [3:0]         m03_axi_arregion;
logic               m03_axi_arvalid; logic               m03_axi_arready;
logic [IC_ID-1:0]   m03_axi_rid;     logic [IC_DATA-1:0] m03_axi_rdata;
logic [1:0]         m03_axi_rresp;   logic               m03_axi_rlast;
logic               m03_axi_rvalid;  logic               m03_axi_rready;

// ---- m04 : GPIO stub ----
logic [IC_ID-1:0]   m04_axi_awid;    logic [IC_ADDR-1:0] m04_axi_awaddr;
logic [7:0]         m04_axi_awlen;   logic [2:0]         m04_axi_awsize;
logic [1:0]         m04_axi_awburst; logic               m04_axi_awlock;
logic [3:0]         m04_axi_awcache; logic [2:0]         m04_axi_awprot;
logic [3:0]         m04_axi_awqos;   logic [3:0]         m04_axi_awregion;
logic               m04_axi_awvalid; logic               m04_axi_awready;
logic [IC_DATA-1:0] m04_axi_wdata;   logic [IC_STRB-1:0] m04_axi_wstrb;
logic               m04_axi_wlast;   logic               m04_axi_wvalid;
logic               m04_axi_wready;
logic [IC_ID-1:0]   m04_axi_bid;     logic [1:0]         m04_axi_bresp;
logic               m04_axi_bvalid;  logic               m04_axi_bready;
logic [IC_ID-1:0]   m04_axi_arid;    logic [IC_ADDR-1:0] m04_axi_araddr;
logic [7:0]         m04_axi_arlen;   logic [2:0]         m04_axi_arsize;
logic [1:0]         m04_axi_arburst; logic               m04_axi_arlock;
logic [3:0]         m04_axi_arcache; logic [2:0]         m04_axi_arprot;
logic [3:0]         m04_axi_arqos;   logic [3:0]         m04_axi_arregion;
logic               m04_axi_arvalid; logic               m04_axi_arready;
logic [IC_ID-1:0]   m04_axi_rid;     logic [IC_DATA-1:0] m04_axi_rdata;
logic [1:0]         m04_axi_rresp;   logic               m04_axi_rlast;
logic               m04_axi_rvalid;  logic               m04_axi_rready;

// ---- m05 : CNN AXI wrapper ----
logic [IC_ID-1:0]   m05_axi_awid;    logic [IC_ADDR-1:0] m05_axi_awaddr;
logic [7:0]         m05_axi_awlen;   logic [2:0]         m05_axi_awsize;
logic [1:0]         m05_axi_awburst; logic               m05_axi_awlock;
logic [3:0]         m05_axi_awcache; logic [2:0]         m05_axi_awprot;
logic [3:0]         m05_axi_awqos;   logic [3:0]         m05_axi_awregion;
logic               m05_axi_awvalid; logic               m05_axi_awready;
logic [IC_DATA-1:0] m05_axi_wdata;   logic [IC_STRB-1:0] m05_axi_wstrb;
logic               m05_axi_wlast;   logic               m05_axi_wvalid;
logic               m05_axi_wready;
logic [IC_ID-1:0]   m05_axi_bid;     logic [1:0]         m05_axi_bresp;
logic               m05_axi_bvalid;  logic               m05_axi_bready;
logic [IC_ID-1:0]   m05_axi_arid;    logic [IC_ADDR-1:0] m05_axi_araddr;
logic [7:0]         m05_axi_arlen;   logic [2:0]         m05_axi_arsize;
logic [1:0]         m05_axi_arburst; logic               m05_axi_arlock;
logic [3:0]         m05_axi_arcache; logic [2:0]         m05_axi_arprot;
logic [3:0]         m05_axi_arqos;   logic [3:0]         m05_axi_arregion;
logic               m05_axi_arvalid; logic               m05_axi_arready;
logic [IC_ID-1:0]   m05_axi_rid;     logic [IC_DATA-1:0] m05_axi_rdata;
logic [1:0]         m05_axi_rresp;   logic               m05_axi_rlast;
logic               m05_axi_rvalid;  logic               m05_axi_rready;

// ---- m06 : Distance/Anomaly stub ----
logic [IC_ID-1:0]   m06_axi_awid;    logic [IC_ADDR-1:0] m06_axi_awaddr;
logic [7:0]         m06_axi_awlen;   logic [2:0]         m06_axi_awsize;
logic [1:0]         m06_axi_awburst; logic               m06_axi_awlock;
logic [3:0]         m06_axi_awcache; logic [2:0]         m06_axi_awprot;
logic [3:0]         m06_axi_awqos;   logic [3:0]         m06_axi_awregion;
logic               m06_axi_awvalid; logic               m06_axi_awready;
logic [IC_DATA-1:0] m06_axi_wdata;   logic [IC_STRB-1:0] m06_axi_wstrb;
logic               m06_axi_wlast;   logic               m06_axi_wvalid;
logic               m06_axi_wready;
logic [IC_ID-1:0]   m06_axi_bid;     logic [1:0]         m06_axi_bresp;
logic               m06_axi_bvalid;  logic               m06_axi_bready;
logic [IC_ID-1:0]   m06_axi_arid;    logic [IC_ADDR-1:0] m06_axi_araddr;
logic [7:0]         m06_axi_arlen;   logic [2:0]         m06_axi_arsize;
logic [1:0]         m06_axi_arburst; logic               m06_axi_arlock;
logic [3:0]         m06_axi_arcache; logic [2:0]         m06_axi_arprot;
logic [3:0]         m06_axi_arqos;   logic [3:0]         m06_axi_arregion;
logic               m06_axi_arvalid; logic               m06_axi_arready;
logic [IC_ID-1:0]   m06_axi_rid;     logic [IC_DATA-1:0] m06_axi_rdata;
logic [1:0]         m06_axi_rresp;   logic               m06_axi_rlast;
logic               m06_axi_rvalid;  logic               m06_axi_rready;

// ---- m07 : DMA register stub ----
logic [IC_ID-1:0]   m07_axi_awid;    logic [IC_ADDR-1:0] m07_axi_awaddr;
logic [7:0]         m07_axi_awlen;   logic [2:0]         m07_axi_awsize;
logic [1:0]         m07_axi_awburst; logic               m07_axi_awlock;
logic [3:0]         m07_axi_awcache; logic [2:0]         m07_axi_awprot;
logic [3:0]         m07_axi_awqos;   logic [3:0]         m07_axi_awregion;
logic               m07_axi_awvalid; logic               m07_axi_awready;
logic [IC_DATA-1:0] m07_axi_wdata;   logic [IC_STRB-1:0] m07_axi_wstrb;
logic               m07_axi_wlast;   logic               m07_axi_wvalid;
logic               m07_axi_wready;
logic [IC_ID-1:0]   m07_axi_bid;     logic [1:0]         m07_axi_bresp;
logic               m07_axi_bvalid;  logic               m07_axi_bready;
logic [IC_ID-1:0]   m07_axi_arid;    logic [IC_ADDR-1:0] m07_axi_araddr;
logic [7:0]         m07_axi_arlen;   logic [2:0]         m07_axi_arsize;
logic [1:0]         m07_axi_arburst; logic               m07_axi_arlock;
logic [3:0]         m07_axi_arcache; logic [2:0]         m07_axi_arprot;
logic [3:0]         m07_axi_arqos;   logic [3:0]         m07_axi_arregion;
logic               m07_axi_arvalid; logic               m07_axi_arready;
logic [IC_ID-1:0]   m07_axi_rid;     logic [IC_DATA-1:0] m07_axi_rdata;
logic [1:0]         m07_axi_rresp;   logic               m07_axi_rlast;
logic               m07_axi_rvalid;  logic               m07_axi_rready;

// IFU→IMEM direct path (32-bit after width adapter, 8-bit IDs)
logic [IC_ID-1:0]   ifu32_awid;    logic [IC_ADDR-1:0] ifu32_awaddr;
logic [7:0]         ifu32_awlen;   logic [2:0]         ifu32_awsize;
logic [1:0]         ifu32_awburst; logic               ifu32_awlock;
logic [3:0]         ifu32_awcache; logic [2:0]         ifu32_awprot;
logic [3:0]         ifu32_awqos;
logic               ifu32_awvalid; logic               ifu32_awready;
logic [IC_DATA-1:0] ifu32_wdata;   logic [IC_STRB-1:0] ifu32_wstrb;
logic               ifu32_wlast;   logic               ifu32_wvalid;
logic               ifu32_wready;
logic [IC_ID-1:0]   ifu32_bid;     logic [1:0]         ifu32_bresp;
logic               ifu32_bvalid;  logic               ifu32_bready;
logic [IC_ID-1:0]   ifu32_arid;    logic [IC_ADDR-1:0] ifu32_araddr;
logic [7:0]         ifu32_arlen;   logic [2:0]         ifu32_arsize;
logic [1:0]         ifu32_arburst; logic               ifu32_arlock;
logic [3:0]         ifu32_arcache; logic [2:0]         ifu32_arprot;
logic [3:0]         ifu32_arqos;
logic               ifu32_arvalid; logic               ifu32_arready;
logic [IC_ID-1:0]   ifu32_rid;     logic [IC_DATA-1:0] ifu32_rdata;
logic [1:0]         ifu32_rresp;   logic               ifu32_rlast;
logic               ifu32_rvalid;  logic               ifu32_rready;

// CNN, Distance, Timer, and GPIO IP internal signals
logic signed [31:0] soc_cnn_embedding [0:15];
logic               soc_cnn_irq;
logic               soc_dist_irq;
logic               soc_timer_irq;
logic               soc_gpio_irq;
logic [31:0]        soc_gpio_pin_irqs;
logic [31:0]        soc_gpio_in_sync;

assign cnn_irq_o   = soc_cnn_irq;
assign dist_irq_o  = soc_dist_irq;
assign timer_irq_o = soc_timer_irq;
assign gpio_irq_o  = soc_gpio_irq;

// el2_mem_if instances (SRAM export / icache export)
el2_mem_if #() el2_mem_export ();
el2_mem_if #() el2_icache_export ();

// VeeR misc outputs (not connected to external pins in this stub)
logic trace_rv_i_valid_ip, trace_rv_i_exception_ip, trace_rv_i_interrupt_ip;
logic [31:0] trace_rv_i_insn_ip, trace_rv_i_address_ip, trace_rv_i_tval_ip;
logic [4:0]  trace_rv_i_ecause_ip;
logic iccm_ecc_single_error, iccm_ecc_double_error;
logic dccm_ecc_single_error, dccm_ecc_double_error, dccm_write_readback_error;
logic dec_tlu_perfcnt0, dec_tlu_perfcnt1, dec_tlu_perfcnt2, dec_tlu_perfcnt3;
logic mpc_debug_halt_ack, mpc_debug_run_ack, debug_brkpt_status;
logic dmi_uncore_en, dmi_uncore_wr_en;
logic [6:0]  dmi_uncore_addr;
logic [31:0] dmi_uncore_wdata;
logic        dmi_active;


// =============================================================================
// ⑦  VeeR-EL2 CPU — el2_veer_wrapper instantiation
//    Module: el2_veer_wrapper (design/el2_veer_wrapper.sv)
//    Requires: `include "common_defines.vh" already at top
//              `include "el2_param.vh"  via the #() parameter pack
// =============================================================================

el2_veer_wrapper #(
    // Use the generated snapshot parameters verbatim.
    // el2_param.vh is `include-d inside the module port list via #(`include).
    // No explicit parameter overrides needed; defaults match the snapshot.
) rvtop (
    .clk            (clk),
    .rst_l          (rst_l),
    .dbg_rst_l      (dbg_rst_l),
    // Boot vector: reset to IMEM base 0x0000_0000, bit 0 always 0 per spec
    .rst_vec        (31'h0000_0000),
    .nmi_int        (1'b0),
    .nmi_vec        (31'h1111_0000),   // unused; tie to safe constant
    .jtag_id        (31'h0000_0000),

    // Trace outputs (unused at top)
    .trace_rv_i_insn_ip      (trace_rv_i_insn_ip),
    .trace_rv_i_address_ip   (trace_rv_i_address_ip),
    .trace_rv_i_valid_ip     (trace_rv_i_valid_ip),
    .trace_rv_i_exception_ip (trace_rv_i_exception_ip),
    .trace_rv_i_ecause_ip    (trace_rv_i_ecause_ip),
    .trace_rv_i_interrupt_ip (trace_rv_i_interrupt_ip),
    .trace_rv_i_tval_ip      (trace_rv_i_tval_ip),

`ifdef RV_BUILD_AXI4
    // ---- LSU AXI master → width adapter ----
    .lsu_axi_awvalid  (lsu_axi_awvalid),  .lsu_axi_awready  (lsu_axi_awready),
    .lsu_axi_awid     (lsu_axi_awid),     .lsu_axi_awaddr   (lsu_axi_awaddr),
    .lsu_axi_awregion (lsu_axi_awregion), .lsu_axi_awlen    (lsu_axi_awlen),
    .lsu_axi_awsize   (lsu_axi_awsize),   .lsu_axi_awburst  (lsu_axi_awburst),
    .lsu_axi_awlock   (lsu_axi_awlock),   .lsu_axi_awcache  (lsu_axi_awcache),
    .lsu_axi_awprot   (lsu_axi_awprot),   .lsu_axi_awqos    (lsu_axi_awqos),
    .lsu_axi_wvalid   (lsu_axi_wvalid),   .lsu_axi_wready   (lsu_axi_wready),
    .lsu_axi_wdata    (lsu_axi_wdata),    .lsu_axi_wstrb    (lsu_axi_wstrb),
    .lsu_axi_wlast    (lsu_axi_wlast),
    .lsu_axi_bvalid   (lsu_axi_bvalid),   .lsu_axi_bready   (lsu_axi_bready),
    .lsu_axi_bresp    (lsu_axi_bresp),    .lsu_axi_bid      (lsu_axi_bid),
    .lsu_axi_arvalid  (lsu_axi_arvalid),  .lsu_axi_arready  (lsu_axi_arready),
    .lsu_axi_arid     (lsu_axi_arid),     .lsu_axi_araddr   (lsu_axi_araddr),
    .lsu_axi_arregion (lsu_axi_arregion), .lsu_axi_arlen    (lsu_axi_arlen),
    .lsu_axi_arsize   (lsu_axi_arsize),   .lsu_axi_arburst  (lsu_axi_arburst),
    .lsu_axi_arlock   (lsu_axi_arlock),   .lsu_axi_arcache  (lsu_axi_arcache),
    .lsu_axi_arprot   (lsu_axi_arprot),   .lsu_axi_arqos    (lsu_axi_arqos),
    .lsu_axi_rvalid   (lsu_axi_rvalid),   .lsu_axi_rready   (lsu_axi_rready),
    .lsu_axi_rid      (lsu_axi_rid),      .lsu_axi_rdata    (lsu_axi_rdata),
    .lsu_axi_rresp    (lsu_axi_rresp),    .lsu_axi_rlast    (lsu_axi_rlast),

    // ---- IFU AXI master → direct-to-IMEM width adapter ----
    .ifu_axi_awvalid  (ifu_axi_awvalid),  .ifu_axi_awready  (ifu_axi_awready),
    .ifu_axi_awid     (ifu_axi_awid),     .ifu_axi_awaddr   (ifu_axi_awaddr),
    .ifu_axi_awregion (ifu_axi_awregion), .ifu_axi_awlen    (ifu_axi_awlen),
    .ifu_axi_awsize   (ifu_axi_awsize),   .ifu_axi_awburst  (ifu_axi_awburst),
    .ifu_axi_awlock   (ifu_axi_awlock),   .ifu_axi_awcache  (ifu_axi_awcache),
    .ifu_axi_awprot   (ifu_axi_awprot),   .ifu_axi_awqos    (ifu_axi_awqos),
    .ifu_axi_wvalid   (ifu_axi_wvalid),   .ifu_axi_wready   (ifu_axi_wready),
    .ifu_axi_wdata    (ifu_axi_wdata),    .ifu_axi_wstrb    (ifu_axi_wstrb),
    .ifu_axi_wlast    (ifu_axi_wlast),
    .ifu_axi_bvalid   (ifu_axi_bvalid),   .ifu_axi_bready   (ifu_axi_bready),
    .ifu_axi_bresp    (ifu_axi_bresp),    .ifu_axi_bid      (ifu_axi_bid),
    .ifu_axi_arvalid  (ifu_axi_arvalid),  .ifu_axi_arready  (ifu_axi_arready),
    .ifu_axi_arid     (ifu_axi_arid),     .ifu_axi_araddr   (ifu_axi_araddr),
    .ifu_axi_arregion (ifu_axi_arregion), .ifu_axi_arlen    (ifu_axi_arlen),
    .ifu_axi_arsize   (ifu_axi_arsize),   .ifu_axi_arburst  (ifu_axi_arburst),
    .ifu_axi_arlock   (ifu_axi_arlock),   .ifu_axi_arcache  (ifu_axi_arcache),
    .ifu_axi_arprot   (ifu_axi_arprot),   .ifu_axi_arqos    (ifu_axi_arqos),
    .ifu_axi_rvalid   (ifu_axi_rvalid),   .ifu_axi_rready   (ifu_axi_rready),
    .ifu_axi_rid      (ifu_axi_rid),      .ifu_axi_rdata    (ifu_axi_rdata),
    .ifu_axi_rresp    (ifu_axi_rresp),    .ifu_axi_rlast    (ifu_axi_rlast),

    // ---- SB AXI (debug system bus) — tie off: no external bus access ----
    .sb_axi_awvalid   (sb_axi_awvalid),   .sb_axi_awready   (sb_axi_awready),
    .sb_axi_awid      (sb_axi_awid),      .sb_axi_awaddr    (sb_axi_awaddr),
    .sb_axi_awregion  (sb_axi_awregion),  .sb_axi_awlen     (sb_axi_awlen),
    .sb_axi_awsize    (sb_axi_awsize),    .sb_axi_awburst   (sb_axi_awburst),
    .sb_axi_awlock    (sb_axi_awlock),    .sb_axi_awcache   (sb_axi_awcache),
    .sb_axi_awprot    (sb_axi_awprot),    .sb_axi_awqos     (sb_axi_awqos),
    .sb_axi_wvalid    (sb_axi_wvalid),    .sb_axi_wready    (sb_axi_wready),
    .sb_axi_wdata     (sb_axi_wdata),     .sb_axi_wstrb     (sb_axi_wstrb),
    .sb_axi_wlast     (sb_axi_wlast),
    .sb_axi_bvalid    (sb_axi_bvalid),    .sb_axi_bready    (sb_axi_bready),
    .sb_axi_bresp     (sb_axi_bresp),     .sb_axi_bid       (sb_axi_bid),
    .sb_axi_arvalid   (sb_axi_arvalid),   .sb_axi_arready   (sb_axi_arready),
    .sb_axi_arid      (sb_axi_arid),      .sb_axi_araddr    (sb_axi_araddr),
    .sb_axi_arregion  (sb_axi_arregion),  .sb_axi_arlen     (sb_axi_arlen),
    .sb_axi_arsize    (sb_axi_arsize),    .sb_axi_arburst   (sb_axi_arburst),
    .sb_axi_arlock    (sb_axi_arlock),    .sb_axi_arcache   (sb_axi_arcache),
    .sb_axi_arprot    (sb_axi_arprot),    .sb_axi_arqos     (sb_axi_arqos),
    .sb_axi_rvalid    (sb_axi_rvalid),    .sb_axi_rready    (sb_axi_rready),
    .sb_axi_rid       (sb_axi_rid),       .sb_axi_rdata     (sb_axi_rdata),
    .sb_axi_rresp     (sb_axi_rresp),     .sb_axi_rlast     (sb_axi_rlast),

    // ---- DMA AXI slave — tied to no-activity (no DMA master this rev) ----
    .dma_axi_awvalid  (dma_axi_awvalid),  .dma_axi_awready  (dma_axi_awready),
    .dma_axi_awid     (dma_axi_awid),     .dma_axi_awaddr   (dma_axi_awaddr),
    .dma_axi_awsize   (dma_axi_awsize),   .dma_axi_awprot   (dma_axi_awprot),
    .dma_axi_awlen    (dma_axi_awlen),    .dma_axi_awburst  (dma_axi_awburst),
    .dma_axi_wvalid   (dma_axi_wvalid),   .dma_axi_wready   (dma_axi_wready),
    .dma_axi_wdata    (dma_axi_wdata),    .dma_axi_wstrb    (dma_axi_wstrb),
    .dma_axi_wlast    (dma_axi_wlast),
    .dma_axi_bvalid   (dma_axi_bvalid),   .dma_axi_bready   (dma_axi_bready),
    .dma_axi_bresp    (dma_axi_bresp),    .dma_axi_bid      (dma_axi_bid),
    .dma_axi_arvalid  (dma_axi_arvalid),  .dma_axi_arready  (dma_axi_arready),
    .dma_axi_arid     (dma_axi_arid),     .dma_axi_araddr   (dma_axi_araddr),
    .dma_axi_arsize   (dma_axi_arsize),   .dma_axi_arprot   (dma_axi_arprot),
    .dma_axi_arlen    (dma_axi_arlen),    .dma_axi_arburst  (dma_axi_arburst),
    .dma_axi_rvalid   (dma_axi_rvalid),   .dma_axi_rready   (dma_axi_rready),
    .dma_axi_rid      (dma_axi_rid),      .dma_axi_rdata    (dma_axi_rdata),
    .dma_axi_rresp    (dma_axi_rresp),    .dma_axi_rlast    (dma_axi_rlast),
`endif // RV_BUILD_AXI4

    // Bus clock enables: tie high (1:1 ratio, single clock domain)
    .lsu_bus_clk_en (1'b1),
    .ifu_bus_clk_en (1'b1),
    .dbg_bus_clk_en (1'b1),
    .dma_bus_clk_en (1'b1),

    // ECC status (not used at top)
    .iccm_ecc_single_error        (iccm_ecc_single_error),
    .iccm_ecc_double_error        (iccm_ecc_double_error),
    .dccm_ecc_single_error        (dccm_ecc_single_error),
    .dccm_ecc_double_error        (dccm_ecc_double_error),
    .dccm_write_readback_error    (dccm_write_readback_error),

    // ICache / SRAM export interfaces (connected to el2_mem_if instances)
    .el2_icache_export (el2_icache_export.veer_icache_src),
    .el2_mem_export    (el2_mem_export.veer_sram_src),

    // Interrupts
    .timer_int      (timer_int | soc_timer_irq),
    .soft_int       (soft_int),
    .extintsrc_req  ({{(PIC_INTS-5){1'b0}}, soc_gpio_irq, soc_timer_irq, soc_dist_irq, soc_cnn_irq, uart_irq_o}),

    // Performance counter outputs (unused)
    .dec_tlu_perfcnt0 (dec_tlu_perfcnt0),
    .dec_tlu_perfcnt1 (dec_tlu_perfcnt1),
    .dec_tlu_perfcnt2 (dec_tlu_perfcnt2),
    .dec_tlu_perfcnt3 (dec_tlu_perfcnt3),

    // JTAG
    .jtag_tck     (jtag_tck),
    .jtag_tms     (jtag_tms),
    .jtag_tdi     (jtag_tdi),
    .jtag_trst_n  (jtag_trst_n),
    .jtag_tdo     (jtag_tdo),
    .jtag_tdoEn   (jtag_tdoEn),

    // Core ID (hartid)
    .core_id      (28'h0),

    // MPC halt/run
    .mpc_debug_halt_req (1'b0),
    .mpc_debug_run_req  (1'b0),
    .mpc_reset_run_req  (1'b1),  // run after reset
    .mpc_debug_halt_ack (mpc_debug_halt_ack),
    .mpc_debug_run_ack  (mpc_debug_run_ack),
    .debug_brkpt_status (debug_brkpt_status),

    .i_cpu_halt_req      (i_cpu_halt_req),
    .o_cpu_halt_ack      (o_cpu_halt_ack),
    .o_cpu_halt_status   (o_cpu_halt_status),
    .o_debug_mode_status (o_debug_mode_status),
    .i_cpu_run_req       (i_cpu_run_req),
    .o_cpu_run_ack       (o_cpu_run_ack),

    // Scan / MBIST (tie off)
    .scan_mode    (1'b0),
    .mbist_mode   (1'b0),

    // DMI uncore
    .dmi_core_enable   (1'b0),
    .dmi_uncore_enable (1'b0),
    .dmi_uncore_en     (dmi_uncore_en),
    .dmi_uncore_wr_en  (dmi_uncore_wr_en),
    .dmi_uncore_addr   (dmi_uncore_addr),
    .dmi_uncore_wdata  (dmi_uncore_wdata),
    .dmi_uncore_rdata  (32'h0),
    .dmi_active        (dmi_active)
);

// Tie off SB (debug bus) slave inputs — no debug bus master connected
assign sb_axi_awready = 1'b0;
assign sb_axi_wready  = 1'b0;
assign sb_axi_bvalid  = 1'b0;
assign sb_axi_bresp   = 2'b00;
assign sb_axi_bid     = '0;
assign sb_axi_arready = 1'b0;
assign sb_axi_rvalid  = 1'b0;
assign sb_axi_rdata   = '0;
assign sb_axi_rresp   = 2'b00;
assign sb_axi_rid     = '0;
assign sb_axi_rlast   = 1'b0;

// Tie off DMA slave inputs — no DMA master present
assign dma_axi_awvalid = 1'b0;
assign dma_axi_awid    = '0;
assign dma_axi_awaddr  = '0;
assign dma_axi_awsize  = '0;
assign dma_axi_awprot  = '0;
assign dma_axi_awlen   = '0;
assign dma_axi_awburst = '0;
assign dma_axi_wvalid  = 1'b0;
assign dma_axi_wdata   = '0;
assign dma_axi_wstrb   = '0;
assign dma_axi_wlast   = 1'b0;
assign dma_axi_bready  = 1'b1;
assign dma_axi_arvalid = 1'b0;
assign dma_axi_arid    = '0;
assign dma_axi_araddr  = '0;
assign dma_axi_arsize  = '0;
assign dma_axi_arprot  = '0;
assign dma_axi_arlen   = '0;
assign dma_axi_arburst = '0;
assign dma_axi_rready  = 1'b1;


// =============================================================================
// ⑧  LSU 64→32 AXI width adapter
//    CPU LSU AXI master (64-bit wdata) → interconnect s00 (32-bit wdata)
//    Strategy: pass upper/lower 32-bit word based on wstrb and awaddr[2].
//    For AXI4-Lite targets (all peripherals here), transactions are always
//    single-beat (awlen=0).  For 64-bit reads, the adapter presents the
//    correct 32-bit lane to the CPU based on araddr[2].
//
//    Note: This is a structural adapter sufficient for single-beat 32-bit
//    peripherals.  A full AXI width converter IP is needed for burst slaves.
// =============================================================================

// ---- Write address: pass through, ID zero-extended ----
assign s00_axi_awid     = {{(IC_ID-LSU_BUS_TAG){1'b0}}, lsu_axi_awid};
assign s00_axi_awaddr   = lsu_axi_awaddr;
assign s00_axi_awlen    = lsu_axi_awlen;
assign s00_axi_awsize   = (lsu_axi_awsize == 3'b011) ? 3'b010 : lsu_axi_awsize; // cap 64→32
assign s00_axi_awburst  = lsu_axi_awburst;
assign s00_axi_awlock   = lsu_axi_awlock;
assign s00_axi_awcache  = lsu_axi_awcache;
assign s00_axi_awprot   = lsu_axi_awprot;
assign s00_axi_awqos    = lsu_axi_awqos;
assign s00_axi_awvalid  = lsu_axi_awvalid;
assign lsu_axi_awready  = s00_axi_awready;

// ---- Write data: select upper or lower 32-bit lane based on address[2] ----
assign s00_axi_wdata   = lsu_axi_awaddr[2] ? lsu_axi_wdata[63:32] : lsu_axi_wdata[31:0];
assign s00_axi_wstrb   = lsu_axi_awaddr[2] ? lsu_axi_wstrb[7:4]   : lsu_axi_wstrb[3:0];
assign s00_axi_wlast   = lsu_axi_wlast;
assign s00_axi_wvalid  = lsu_axi_wvalid;
assign lsu_axi_wready  = s00_axi_wready;

// ---- Write response: pass through, ID truncated ----
assign lsu_axi_bvalid  = s00_axi_bvalid;
assign lsu_axi_bresp   = s00_axi_bresp;
assign lsu_axi_bid     = s00_axi_bid[LSU_BUS_TAG-1:0];
assign s00_axi_bready  = lsu_axi_bready;

// ---- Read address: pass through ----
assign s00_axi_arid    = {{(IC_ID-LSU_BUS_TAG){1'b0}}, lsu_axi_arid};
assign s00_axi_araddr  = lsu_axi_araddr;
assign s00_axi_arlen   = lsu_axi_arlen;
assign s00_axi_arsize  = (lsu_axi_arsize == 3'b011) ? 3'b010 : lsu_axi_arsize;
assign s00_axi_arburst = lsu_axi_arburst;
assign s00_axi_arlock  = lsu_axi_arlock;
assign s00_axi_arcache = lsu_axi_arcache;
assign s00_axi_arprot  = lsu_axi_arprot;
assign s00_axi_arqos   = lsu_axi_arqos;
assign s00_axi_arvalid = lsu_axi_arvalid;
assign lsu_axi_arready = s00_axi_arready;

// ---- Read data: replicate 32-bit word into both halves of 64-bit rdata ----
assign lsu_axi_rvalid  = s00_axi_rvalid;
assign lsu_axi_rresp   = s00_axi_rresp;
assign lsu_axi_rid     = s00_axi_rid[LSU_BUS_TAG-1:0];
assign lsu_axi_rdata   = {s00_axi_rdata, s00_axi_rdata}; // replicate to 64-bit
assign lsu_axi_rlast   = s00_axi_rlast;
assign s00_axi_rready  = lsu_axi_rready;

// =============================================================================
// ⑨  IFU 64→32 AXI width adapter  (Option A: direct path to IMEM, no interconnect)
//    IFU is read-only; write channels are permanently idle.
// =============================================================================

// Write address: IFU never writes — tie off
assign ifu_axi_awready = 1'b0;
assign ifu_axi_wready  = 1'b0;
assign ifu_axi_bvalid  = 1'b0;
assign ifu_axi_bresp   = 2'b00;
assign ifu_axi_bid     = '0;

// Read address: pass through to IMEM's ifu32 port
assign ifu32_arid    = {{(IC_ID-IFU_BUS_TAG){1'b0}}, ifu_axi_arid};
assign ifu32_araddr  = ifu_axi_araddr;
assign ifu32_arlen   = ifu_axi_arlen;
assign ifu32_arsize  = (ifu_axi_arsize == 3'b011) ? 3'b010 : ifu_axi_arsize;
assign ifu32_arburst = ifu_axi_arburst;
assign ifu32_arlock  = ifu_axi_arlock;
assign ifu32_arcache = ifu_axi_arcache;
assign ifu32_arprot  = ifu_axi_arprot;
assign ifu32_arqos   = ifu_axi_arqos;
assign ifu32_arvalid = ifu_axi_arvalid;
assign ifu_axi_arready = ifu32_arready;

// Read data: replicate 32→64 bits
assign ifu_axi_rvalid = ifu32_rvalid;
assign ifu_axi_rresp  = ifu32_rresp;
assign ifu_axi_rid    = ifu32_rid[IFU_BUS_TAG-1:0];
assign ifu_axi_rdata  = {ifu32_rdata, ifu32_rdata};
assign ifu_axi_rlast  = ifu32_rlast;
assign ifu32_rready   = ifu_axi_rready;

// IFU write side of ifu32 (IMEM dual-port) — tie off, IFU only reads
assign ifu32_awid    = '0;
assign ifu32_awaddr  = '0;
assign ifu32_awlen   = '0;
assign ifu32_awsize  = '0;
assign ifu32_awburst = '0;
assign ifu32_awlock  = 1'b0;
assign ifu32_awcache = '0;
assign ifu32_awprot  = '0;
assign ifu32_awqos   = '0;
assign ifu32_awvalid = 1'b0;
assign ifu32_wdata   = '0;
assign ifu32_wstrb   = '0;
assign ifu32_wlast   = 1'b0;
assign ifu32_wvalid  = 1'b0;
assign ifu32_bready  = 1'b1;

// =============================================================================
// ⑩  AXI Interconnect — axi_interconnect_wrap_2x8
//    s00 = CPU LSU (32-bit, via adapter above)
//    s01 = DMA master (tied off — future expansion)
//    m00..m07 = eight decoded slave targets
// =============================================================================

axi_interconnect_wrap_2x8 #(
    .DATA_WIDTH       (32),
    .ADDR_WIDTH       (32),
    .ID_WIDTH         (8),
    .AWUSER_ENABLE    (0),
    .WUSER_ENABLE     (0),
    .BUSER_ENABLE     (0),
    .ARUSER_ENABLE    (0),
    .RUSER_ENABLE     (0),
    .FORWARD_ID       (0),
    .M_REGIONS        (1),
    // Memory map — matches spec Section 3 exactly
    .M00_BASE_ADDR    (32'h0000_0000),  // IMEM   64 KB
    .M00_ADDR_WIDTH   ({1{32'd16}}),
    .M00_CONNECT_READ (2'b11), .M00_CONNECT_WRITE(2'b11),
    .M01_BASE_ADDR    (32'h1000_0000),  // DMEM   64 KB
    .M01_ADDR_WIDTH   ({1{32'd16}}),
    .M01_CONNECT_READ (2'b11), .M01_CONNECT_WRITE(2'b11),
    .M02_BASE_ADDR    (32'h2000_0000),  // UART    4 KB
    .M02_ADDR_WIDTH   ({1{32'd12}}),
    .M02_CONNECT_READ (2'b11), .M02_CONNECT_WRITE(2'b11),
    .M03_BASE_ADDR    (32'h2000_1000),  // Timer   4 KB
    .M03_ADDR_WIDTH   ({1{32'd12}}),
    .M03_CONNECT_READ (2'b11), .M03_CONNECT_WRITE(2'b11),
    .M04_BASE_ADDR    (32'h2000_2000),  // GPIO    4 KB
    .M04_ADDR_WIDTH   ({1{32'd12}}),
    .M04_CONNECT_READ (2'b11), .M04_CONNECT_WRITE(2'b11),
    .M05_BASE_ADDR    (32'h2000_3000),  // CNN     4 KB
    .M05_ADDR_WIDTH   ({1{32'd12}}),
    .M05_CONNECT_READ (2'b11), .M05_CONNECT_WRITE(2'b11),
    .M06_BASE_ADDR    (32'h2000_4000),  // Distance 4 KB
    .M06_ADDR_WIDTH   ({1{32'd12}}),
    .M06_CONNECT_READ (2'b11), .M06_CONNECT_WRITE(2'b11),
    .M07_BASE_ADDR    (32'h2000_5000),  // DMA regs 4 KB
    .M07_ADDR_WIDTH   ({1{32'd12}}),
    .M07_CONNECT_READ (2'b11), .M07_CONNECT_WRITE(2'b11)
) u_interconnect (
    .clk  (clk),
    .rst  (~rst_l),   // interconnect uses active-high reset

    // ---- s00 : CPU LSU master (32-bit, from adapter) ----
    .s00_axi_awid    (s00_axi_awid),    .s00_axi_awaddr  (s00_axi_awaddr),
    .s00_axi_awlen   (s00_axi_awlen),   .s00_axi_awsize  (s00_axi_awsize),
    .s00_axi_awburst (s00_axi_awburst), .s00_axi_awlock  (s00_axi_awlock),
    .s00_axi_awcache (s00_axi_awcache), .s00_axi_awprot  (s00_axi_awprot),
    .s00_axi_awqos   (s00_axi_awqos),   .s00_axi_awuser  (1'b0),
    .s00_axi_awvalid (s00_axi_awvalid), .s00_axi_awready (s00_axi_awready),
    .s00_axi_wdata   (s00_axi_wdata),   .s00_axi_wstrb   (s00_axi_wstrb),
    .s00_axi_wlast   (s00_axi_wlast),   .s00_axi_wuser   (1'b0),
    .s00_axi_wvalid  (s00_axi_wvalid),  .s00_axi_wready  (s00_axi_wready),
    .s00_axi_bid     (s00_axi_bid),     .s00_axi_bresp   (s00_axi_bresp),
    .s00_axi_buser   (),                .s00_axi_bvalid  (s00_axi_bvalid),
    .s00_axi_bready  (s00_axi_bready),
    .s00_axi_arid    (s00_axi_arid),    .s00_axi_araddr  (s00_axi_araddr),
    .s00_axi_arlen   (s00_axi_arlen),   .s00_axi_arsize  (s00_axi_arsize),
    .s00_axi_arburst (s00_axi_arburst), .s00_axi_arlock  (s00_axi_arlock),
    .s00_axi_arcache (s00_axi_arcache), .s00_axi_arprot  (s00_axi_arprot),
    .s00_axi_arqos   (s00_axi_arqos),   .s00_axi_aruser  (1'b0),
    .s00_axi_arvalid (s00_axi_arvalid), .s00_axi_arready (s00_axi_arready),
    .s00_axi_rid     (s00_axi_rid),     .s00_axi_rdata   (s00_axi_rdata),
    .s00_axi_rresp   (s00_axi_rresp),   .s00_axi_rlast   (s00_axi_rlast),
    .s00_axi_ruser   (),                .s00_axi_rvalid  (s00_axi_rvalid),
    .s00_axi_rready  (s00_axi_rready),

    // ---- s01 : DMA master — tied off ----
    .s01_axi_awid    (s01_axi_awid),    .s01_axi_awaddr  (s01_axi_awaddr),
    .s01_axi_awlen   (s01_axi_awlen),   .s01_axi_awsize  (s01_axi_awsize),
    .s01_axi_awburst (s01_axi_awburst), .s01_axi_awlock  (s01_axi_awlock),
    .s01_axi_awcache (s01_axi_awcache), .s01_axi_awprot  (s01_axi_awprot),
    .s01_axi_awqos   (s01_axi_awqos),   .s01_axi_awuser  (1'b0),
    .s01_axi_awvalid (s01_axi_awvalid), .s01_axi_awready (),
    .s01_axi_wdata   (s01_axi_wdata),   .s01_axi_wstrb   (s01_axi_wstrb),
    .s01_axi_wlast   (s01_axi_wlast),   .s01_axi_wuser   (1'b0),
    .s01_axi_wvalid  (s01_axi_wvalid),  .s01_axi_wready  (),
    .s01_axi_bid     (),                .s01_axi_bresp   (),
    .s01_axi_buser   (),                .s01_axi_bvalid  (),
    .s01_axi_bready  (s01_axi_bready),
    .s01_axi_arid    (s01_axi_arid),    .s01_axi_araddr  (s01_axi_araddr),
    .s01_axi_arlen   (s01_axi_arlen),   .s01_axi_arsize  (s01_axi_arsize),
    .s01_axi_arburst (s01_axi_arburst), .s01_axi_arlock  (s01_axi_arlock),
    .s01_axi_arcache (s01_axi_arcache), .s01_axi_arprot  (s01_axi_arprot),
    .s01_axi_arqos   (s01_axi_arqos),   .s01_axi_aruser  (1'b0),
    .s01_axi_arvalid (s01_axi_arvalid), .s01_axi_arready (),
    .s01_axi_rid     (),                .s01_axi_rdata   (),
    .s01_axi_rresp   (),                .s01_axi_rlast   (),
    .s01_axi_ruser   (),                .s01_axi_rvalid  (),
    .s01_axi_rready  (s01_axi_rready),

    // ---- m00 : IMEM ----
    .m00_axi_awid    (m00_axi_awid),    .m00_axi_awaddr  (m00_axi_awaddr),
    .m00_axi_awlen   (m00_axi_awlen),   .m00_axi_awsize  (m00_axi_awsize),
    .m00_axi_awburst (m00_axi_awburst), .m00_axi_awlock  (m00_axi_awlock),
    .m00_axi_awcache (m00_axi_awcache), .m00_axi_awprot  (m00_axi_awprot),
    .m00_axi_awqos   (m00_axi_awqos),   .m00_axi_awregion(m00_axi_awregion),
    .m00_axi_awuser  (),                .m00_axi_awvalid (m00_axi_awvalid),
    .m00_axi_awready (m00_axi_awready),
    .m00_axi_wdata   (m00_axi_wdata),   .m00_axi_wstrb   (m00_axi_wstrb),
    .m00_axi_wlast   (m00_axi_wlast),   .m00_axi_wuser   (),
    .m00_axi_wvalid  (m00_axi_wvalid),  .m00_axi_wready  (m00_axi_wready),
    .m00_axi_bid     (m00_axi_bid),     .m00_axi_bresp   (m00_axi_bresp),
    .m00_axi_buser   (1'b0),            .m00_axi_bvalid  (m00_axi_bvalid),
    .m00_axi_bready  (m00_axi_bready),
    .m00_axi_arid    (m00_axi_arid),    .m00_axi_araddr  (m00_axi_araddr),
    .m00_axi_arlen   (m00_axi_arlen),   .m00_axi_arsize  (m00_axi_arsize),
    .m00_axi_arburst (m00_axi_arburst), .m00_axi_arlock  (m00_axi_arlock),
    .m00_axi_arcache (m00_axi_arcache), .m00_axi_arprot  (m00_axi_arprot),
    .m00_axi_arqos   (m00_axi_arqos),   .m00_axi_arregion(m00_axi_arregion),
    .m00_axi_aruser  (),                .m00_axi_arvalid (m00_axi_arvalid),
    .m00_axi_arready (m00_axi_arready),
    .m00_axi_rid     (m00_axi_rid),     .m00_axi_rdata   (m00_axi_rdata),
    .m00_axi_rresp   (m00_axi_rresp),   .m00_axi_rlast   (m00_axi_rlast),
    .m00_axi_ruser   (1'b0),            .m00_axi_rvalid  (m00_axi_rvalid),
    .m00_axi_rready  (m00_axi_rready),

    // ---- m01 : DMEM ----
    .m01_axi_awid    (m01_axi_awid),    .m01_axi_awaddr  (m01_axi_awaddr),
    .m01_axi_awlen   (m01_axi_awlen),   .m01_axi_awsize  (m01_axi_awsize),
    .m01_axi_awburst (m01_axi_awburst), .m01_axi_awlock  (m01_axi_awlock),
    .m01_axi_awcache (m01_axi_awcache), .m01_axi_awprot  (m01_axi_awprot),
    .m01_axi_awqos   (m01_axi_awqos),   .m01_axi_awregion(m01_axi_awregion),
    .m01_axi_awuser  (),                .m01_axi_awvalid (m01_axi_awvalid),
    .m01_axi_awready (m01_axi_awready),
    .m01_axi_wdata   (m01_axi_wdata),   .m01_axi_wstrb   (m01_axi_wstrb),
    .m01_axi_wlast   (m01_axi_wlast),   .m01_axi_wuser   (),
    .m01_axi_wvalid  (m01_axi_wvalid),  .m01_axi_wready  (m01_axi_wready),
    .m01_axi_bid     (m01_axi_bid),     .m01_axi_bresp   (m01_axi_bresp),
    .m01_axi_buser   (1'b0),            .m01_axi_bvalid  (m01_axi_bvalid),
    .m01_axi_bready  (m01_axi_bready),
    .m01_axi_arid    (m01_axi_arid),    .m01_axi_araddr  (m01_axi_araddr),
    .m01_axi_arlen   (m01_axi_arlen),   .m01_axi_arsize  (m01_axi_arsize),
    .m01_axi_arburst (m01_axi_arburst), .m01_axi_arlock  (m01_axi_arlock),
    .m01_axi_arcache (m01_axi_arcache), .m01_axi_arprot  (m01_axi_arprot),
    .m01_axi_arqos   (m01_axi_arqos),   .m01_axi_arregion(m01_axi_arregion),
    .m01_axi_aruser  (),                .m01_axi_arvalid (m01_axi_arvalid),
    .m01_axi_arready (m01_axi_arready),
    .m01_axi_rid     (m01_axi_rid),     .m01_axi_rdata   (m01_axi_rdata),
    .m01_axi_rresp   (m01_axi_rresp),   .m01_axi_rlast   (m01_axi_rlast),
    .m01_axi_ruser   (1'b0),            .m01_axi_rvalid  (m01_axi_rvalid),
    .m01_axi_rready  (m01_axi_rready),

    // ---- m02 : UART ----
    .m02_axi_awid    (m02_axi_awid),    .m02_axi_awaddr  (m02_axi_awaddr),
    .m02_axi_awlen   (m02_axi_awlen),   .m02_axi_awsize  (m02_axi_awsize),
    .m02_axi_awburst (m02_axi_awburst), .m02_axi_awlock  (m02_axi_awlock),
    .m02_axi_awcache (m02_axi_awcache), .m02_axi_awprot  (m02_axi_awprot),
    .m02_axi_awqos   (m02_axi_awqos),   .m02_axi_awregion(m02_axi_awregion),
    .m02_axi_awuser  (),                .m02_axi_awvalid (m02_axi_awvalid),
    .m02_axi_awready (m02_axi_awready),
    .m02_axi_wdata   (m02_axi_wdata),   .m02_axi_wstrb   (m02_axi_wstrb),
    .m02_axi_wlast   (m02_axi_wlast),   .m02_axi_wuser   (),
    .m02_axi_wvalid  (m02_axi_wvalid),  .m02_axi_wready  (m02_axi_wready),
    .m02_axi_bid     (m02_axi_bid),     .m02_axi_bresp   (m02_axi_bresp),
    .m02_axi_buser   (1'b0),            .m02_axi_bvalid  (m02_axi_bvalid),
    .m02_axi_bready  (m02_axi_bready),
    .m02_axi_arid    (m02_axi_arid),    .m02_axi_araddr  (m02_axi_araddr),
    .m02_axi_arlen   (m02_axi_arlen),   .m02_axi_arsize  (m02_axi_arsize),
    .m02_axi_arburst (m02_axi_arburst), .m02_axi_arlock  (m02_axi_arlock),
    .m02_axi_arcache (m02_axi_arcache), .m02_axi_arprot  (m02_axi_arprot),
    .m02_axi_arqos   (m02_axi_arqos),   .m02_axi_arregion(m02_axi_arregion),
    .m02_axi_aruser  (),                .m02_axi_arvalid (m02_axi_arvalid),
    .m02_axi_arready (m02_axi_arready),
    .m02_axi_rid     (m02_axi_rid),     .m02_axi_rdata   (m02_axi_rdata),
    .m02_axi_rresp   (m02_axi_rresp),   .m02_axi_rlast   (m02_axi_rlast),
    .m02_axi_ruser   (1'b0),            .m02_axi_rvalid  (m02_axi_rvalid),
    .m02_axi_rready  (m02_axi_rready),

    // ---- m03 : Timer (stub) ----
    .m03_axi_awid    (m03_axi_awid),    .m03_axi_awaddr  (m03_axi_awaddr),
    .m03_axi_awlen   (m03_axi_awlen),   .m03_axi_awsize  (m03_axi_awsize),
    .m03_axi_awburst (m03_axi_awburst), .m03_axi_awlock  (m03_axi_awlock),
    .m03_axi_awcache (m03_axi_awcache), .m03_axi_awprot  (m03_axi_awprot),
    .m03_axi_awqos   (m03_axi_awqos),   .m03_axi_awregion(m03_axi_awregion),
    .m03_axi_awuser  (),                .m03_axi_awvalid (m03_axi_awvalid),
    .m03_axi_awready (m03_axi_awready),
    .m03_axi_wdata   (m03_axi_wdata),   .m03_axi_wstrb   (m03_axi_wstrb),
    .m03_axi_wlast   (m03_axi_wlast),   .m03_axi_wuser   (),
    .m03_axi_wvalid  (m03_axi_wvalid),  .m03_axi_wready  (m03_axi_wready),
    .m03_axi_bid     (m03_axi_bid),     .m03_axi_bresp   (m03_axi_bresp),
    .m03_axi_buser   (1'b0),            .m03_axi_bvalid  (m03_axi_bvalid),
    .m03_axi_bready  (m03_axi_bready),
    .m03_axi_arid    (m03_axi_arid),    .m03_axi_araddr  (m03_axi_araddr),
    .m03_axi_arlen   (m03_axi_arlen),   .m03_axi_arsize  (m03_axi_arsize),
    .m03_axi_arburst (m03_axi_arburst), .m03_axi_arlock  (m03_axi_arlock),
    .m03_axi_arcache (m03_axi_arcache), .m03_axi_arprot  (m03_axi_arprot),
    .m03_axi_arqos   (m03_axi_arqos),   .m03_axi_arregion(m03_axi_arregion),
    .m03_axi_aruser  (),                .m03_axi_arvalid (m03_axi_arvalid),
    .m03_axi_arready (m03_axi_arready),
    .m03_axi_rid     (m03_axi_rid),     .m03_axi_rdata   (m03_axi_rdata),
    .m03_axi_rresp   (m03_axi_rresp),   .m03_axi_rlast   (m03_axi_rlast),
    .m03_axi_ruser   (1'b0),            .m03_axi_rvalid  (m03_axi_rvalid),
    .m03_axi_rready  (m03_axi_rready),

    // ---- m04 : GPIO (stub) ----
    .m04_axi_awid    (m04_axi_awid),    .m04_axi_awaddr  (m04_axi_awaddr),
    .m04_axi_awlen   (m04_axi_awlen),   .m04_axi_awsize  (m04_axi_awsize),
    .m04_axi_awburst (m04_axi_awburst), .m04_axi_awlock  (m04_axi_awlock),
    .m04_axi_awcache (m04_axi_awcache), .m04_axi_awprot  (m04_axi_awprot),
    .m04_axi_awqos   (m04_axi_awqos),   .m04_axi_awregion(m04_axi_awregion),
    .m04_axi_awuser  (),                .m04_axi_awvalid (m04_axi_awvalid),
    .m04_axi_awready (m04_axi_awready),
    .m04_axi_wdata   (m04_axi_wdata),   .m04_axi_wstrb   (m04_axi_wstrb),
    .m04_axi_wlast   (m04_axi_wlast),   .m04_axi_wuser   (),
    .m04_axi_wvalid  (m04_axi_wvalid),  .m04_axi_wready  (m04_axi_wready),
    .m04_axi_bid     (m04_axi_bid),     .m04_axi_bresp   (m04_axi_bresp),
    .m04_axi_buser   (1'b0),            .m04_axi_bvalid  (m04_axi_bvalid),
    .m04_axi_bready  (m04_axi_bready),
    .m04_axi_arid    (m04_axi_arid),    .m04_axi_araddr  (m04_axi_araddr),
    .m04_axi_arlen   (m04_axi_arlen),   .m04_axi_arsize  (m04_axi_arsize),
    .m04_axi_arburst (m04_axi_arburst), .m04_axi_arlock  (m04_axi_arlock),
    .m04_axi_arcache (m04_axi_arcache), .m04_axi_arprot  (m04_axi_arprot),
    .m04_axi_arqos   (m04_axi_arqos),   .m04_axi_arregion(m04_axi_arregion),
    .m04_axi_aruser  (),                .m04_axi_arvalid (m04_axi_arvalid),
    .m04_axi_arready (m04_axi_arready),
    .m04_axi_rid     (m04_axi_rid),     .m04_axi_rdata   (m04_axi_rdata),
    .m04_axi_rresp   (m04_axi_rresp),   .m04_axi_rlast   (m04_axi_rlast),
    .m04_axi_ruser   (1'b0),            .m04_axi_rvalid  (m04_axi_rvalid),
    .m04_axi_rready  (m04_axi_rready),

    // ---- m05 : CNN AXI wrapper ----
    .m05_axi_awid    (m05_axi_awid),    .m05_axi_awaddr  (m05_axi_awaddr),
    .m05_axi_awlen   (m05_axi_awlen),   .m05_axi_awsize  (m05_axi_awsize),
    .m05_axi_awburst (m05_axi_awburst), .m05_axi_awlock  (m05_axi_awlock),
    .m05_axi_awcache (m05_axi_awcache), .m05_axi_awprot  (m05_axi_awprot),
    .m05_axi_awqos   (m05_axi_awqos),   .m05_axi_awregion(m05_axi_awregion),
    .m05_axi_awuser  (),                .m05_axi_awvalid (m05_axi_awvalid),
    .m05_axi_awready (m05_axi_awready),
    .m05_axi_wdata   (m05_axi_wdata),   .m05_axi_wstrb   (m05_axi_wstrb),
    .m05_axi_wlast   (m05_axi_wlast),   .m05_axi_wuser   (),
    .m05_axi_wvalid  (m05_axi_wvalid),  .m05_axi_wready  (m05_axi_wready),
    .m05_axi_bid     (m05_axi_bid),     .m05_axi_bresp   (m05_axi_bresp),
    .m05_axi_buser   (1'b0),            .m05_axi_bvalid  (m05_axi_bvalid),
    .m05_axi_bready  (m05_axi_bready),
    .m05_axi_arid    (m05_axi_arid),    .m05_axi_araddr  (m05_axi_araddr),
    .m05_axi_arlen   (m05_axi_arlen),   .m05_axi_arsize  (m05_axi_arsize),
    .m05_axi_arburst (m05_axi_arburst), .m05_axi_arlock  (m05_axi_arlock),
    .m05_axi_arcache (m05_axi_arcache), .m05_axi_arprot  (m05_axi_arprot),
    .m05_axi_arqos   (m05_axi_arqos),   .m05_axi_arregion(m05_axi_arregion),
    .m05_axi_aruser  (),                .m05_axi_arvalid (m05_axi_arvalid),
    .m05_axi_arready (m05_axi_arready),
    .m05_axi_rid     (m05_axi_rid),     .m05_axi_rdata   (m05_axi_rdata),
    .m05_axi_rresp   (m05_axi_rresp),   .m05_axi_rlast   (m05_axi_rlast),
    .m05_axi_ruser   (1'b0),            .m05_axi_rvalid  (m05_axi_rvalid),
    .m05_axi_rready  (m05_axi_rready),

    // ---- m06 : Distance/Anomaly stub ----
    .m06_axi_awid    (m06_axi_awid),    .m06_axi_awaddr  (m06_axi_awaddr),
    .m06_axi_awlen   (m06_axi_awlen),   .m06_axi_awsize  (m06_axi_awsize),
    .m06_axi_awburst (m06_axi_awburst), .m06_axi_awlock  (m06_axi_awlock),
    .m06_axi_awcache (m06_axi_awcache), .m06_axi_awprot  (m06_axi_awprot),
    .m06_axi_awqos   (m06_axi_awqos),   .m06_axi_awregion(m06_axi_awregion),
    .m06_axi_awuser  (),                .m06_axi_awvalid (m06_axi_awvalid),
    .m06_axi_awready (m06_axi_awready),
    .m06_axi_wdata   (m06_axi_wdata),   .m06_axi_wstrb   (m06_axi_wstrb),
    .m06_axi_wlast   (m06_axi_wlast),   .m06_axi_wuser   (),
    .m06_axi_wvalid  (m06_axi_wvalid),  .m06_axi_wready  (m06_axi_wready),
    .m06_axi_bid     (m06_axi_bid),     .m06_axi_bresp   (m06_axi_bresp),
    .m06_axi_buser   (1'b0),            .m06_axi_bvalid  (m06_axi_bvalid),
    .m06_axi_bready  (m06_axi_bready),
    .m06_axi_arid    (m06_axi_arid),    .m06_axi_araddr  (m06_axi_araddr),
    .m06_axi_arlen   (m06_axi_arlen),   .m06_axi_arsize  (m06_axi_arsize),
    .m06_axi_arburst (m06_axi_arburst), .m06_axi_arlock  (m06_axi_arlock),
    .m06_axi_arcache (m06_axi_arcache), .m06_axi_arprot  (m06_axi_arprot),
    .m06_axi_arqos   (m06_axi_arqos),   .m06_axi_arregion(m06_axi_arregion),
    .m06_axi_aruser  (),                .m06_axi_arvalid (m06_axi_arvalid),
    .m06_axi_arready (m06_axi_arready),
    .m06_axi_rid     (m06_axi_rid),     .m06_axi_rdata   (m06_axi_rdata),
    .m06_axi_rresp   (m06_axi_rresp),   .m06_axi_rlast   (m06_axi_rlast),
    .m06_axi_ruser   (1'b0),            .m06_axi_rvalid  (m06_axi_rvalid),
    .m06_axi_rready  (m06_axi_rready),

    // ---- m07 : DMA register stub ----
    .m07_axi_awid    (m07_axi_awid),    .m07_axi_awaddr  (m07_axi_awaddr),
    .m07_axi_awlen   (m07_axi_awlen),   .m07_axi_awsize  (m07_axi_awsize),
    .m07_axi_awburst (m07_axi_awburst), .m07_axi_awlock  (m07_axi_awlock),
    .m07_axi_awcache (m07_axi_awcache), .m07_axi_awprot  (m07_axi_awprot),
    .m07_axi_awqos   (m07_axi_awqos),   .m07_axi_awregion(m07_axi_awregion),
    .m07_axi_awuser  (),                .m07_axi_awvalid (m07_axi_awvalid),
    .m07_axi_awready (m07_axi_awready),
    .m07_axi_wdata   (m07_axi_wdata),   .m07_axi_wstrb   (m07_axi_wstrb),
    .m07_axi_wlast   (m07_axi_wlast),   .m07_axi_wuser   (),
    .m07_axi_wvalid  (m07_axi_wvalid),  .m07_axi_wready  (m07_axi_wready),
    .m07_axi_bid     (m07_axi_bid),     .m07_axi_bresp   (m07_axi_bresp),
    .m07_axi_buser   (1'b0),            .m07_axi_bvalid  (m07_axi_bvalid),
    .m07_axi_bready  (m07_axi_bready),
    .m07_axi_arid    (m07_axi_arid),    .m07_axi_araddr  (m07_axi_araddr),
    .m07_axi_arlen   (m07_axi_arlen),   .m07_axi_arsize  (m07_axi_arsize),
    .m07_axi_arburst (m07_axi_arburst), .m07_axi_arlock  (m07_axi_arlock),
    .m07_axi_arcache (m07_axi_arcache), .m07_axi_arprot  (m07_axi_arprot),
    .m07_axi_arqos   (m07_axi_arqos),   .m07_axi_arregion(m07_axi_arregion),
    .m07_axi_aruser  (),                .m07_axi_arvalid (m07_axi_arvalid),
    .m07_axi_arready (m07_axi_arready),
    .m07_axi_rid     (m07_axi_rid),     .m07_axi_rdata   (m07_axi_rdata),
    .m07_axi_rresp   (m07_axi_rresp),   .m07_axi_rlast   (m07_axi_rlast),
    .m07_axi_ruser   (1'b0),            .m07_axi_rvalid  (m07_axi_rvalid),
    .m07_axi_rready  (m07_axi_rready)
);


// =============================================================================
// ⑪  UART peripheral — axi_uart_top (m02)
//    Module: axi_uart_top  (rtl/uart/axi_uart_top.v)
//    AXI4-Lite slave: data=32-bit, addr=5-bit, id=12-bit
//    Interconnect drives 8-bit IDs → UART expects 12-bit → zero-extend.
//    UART addr is 5-bit; interconnect supplies full 32-bit → use [4:0].
//
//    CPU → s00 → interconnect m02 → UART  (0x2000_0000)
// =============================================================================

axi_uart_top u_uart (
    // Two separate clocks: fixed baud clock and AXI bus clock.
    // In a single-clock design both are tied to system clk.
    .fixed_clk_i        (clk),
    .axi_aclk_i         (clk),
    .axi_aresetn_i      (rst_l),   // active-low; same convention as VeeR

    // Read address channel
    .axi_arid_i         ({{(UART_ID-IC_ID){1'b0}}, m02_axi_arid}),  // 8→12 bit
    .axi_araddr_i       (m02_axi_araddr[4:0]),
    .axi_arvalid_i      (m02_axi_arvalid),
    .axi_arready_o      (m02_axi_arready),

    // Read data channel
    .axi_rid_o          (),            // 12-bit; we only need 8 bits back
    .axi_rdata_o        (m02_axi_rdata),
    .axi_rresp_o        (m02_axi_rresp),
    .axi_rvalid_o       (m02_axi_rvalid),
    .axi_rready_i       (m02_axi_rready),

    // Write address channel
    .axi_awid_i         ({{(UART_ID-IC_ID){1'b0}}, m02_axi_awid}),
    .axi_awaddr_i       (m02_axi_awaddr[4:0]),
    .axi_awvalid_i      (m02_axi_awvalid),
    .axi_awready_o      (m02_axi_awready),

    // Write data channel
    .axi_wdata_i        (m02_axi_wdata),
    .axi_wstrb_i        (m02_axi_wstrb),
    .axi_wvalid_i       (m02_axi_wvalid),
    .axi_wready_o       (m02_axi_wready),

    // Write response channel
    .axi_bid_o          (),            // 12-bit; discard upper bits
    .axi_bresp_o        (m02_axi_bresp),
    .axi_bvalid_o       (m02_axi_bvalid),
    .axi_bready_i       (m02_axi_bready),

    // UART interrupt and serial lines
    .read_interrupt_o   (uart_irq_o),
    .uart_rx_i          (uart_rx_i),
    .uart_tx_o          (uart_tx_o)
);

// UART does not use rlast/ruser; interconnect expects them driven
assign m02_axi_rlast = 1'b1;   // single-beat AXI4-Lite always last
assign m02_axi_bid   = '0;     // ID unused by UART; drive safe value

// =============================================================================
// ⑫  CNN AXI wrapper — m05 (0x2000_3000)
//    cnn_top has no AXI interface; a register-file wrapper is needed.
//    For now: instantiate a stub that accepts writes (ignores data) and
//    returns OKAY reads of zero.  Replace with cnn_axi_wrapper.sv when ready.
//
//    CPU → s00 → interconnect m05 → CNN slave stub
// =============================================================================

// CNN stub — accepts all AXI transactions, returns SLVERR on read,
// asserts awready/wready immediately, returns write OKAY.
// CNN AXI-Lite wrapper instance
cnn_axi_wrapper #(
    .DATA_WIDTH (IC_DATA),
    .ADDR_WIDTH (IC_ADDR),
    .STRB_WIDTH (IC_STRB),
    .ID_WIDTH   (IC_ID)
) u_cnn_axi (
    .clk            (clk),
    .rst_n          (rst_l),
    .s_axi_awid     (m05_axi_awid),    .s_axi_awaddr   (m05_axi_awaddr),
    .s_axi_awlen    (m05_axi_awlen),   .s_axi_awsize   (m05_axi_awsize),
    .s_axi_awburst  (m05_axi_awburst), .s_axi_awvalid  (m05_axi_awvalid),
    .s_axi_awready  (m05_axi_awready),
    .s_axi_wdata    (m05_axi_wdata),   .s_axi_wstrb    (m05_axi_wstrb),
    .s_axi_wlast    (m05_axi_wlast),   .s_axi_wvalid   (m05_axi_wvalid),
    .s_axi_wready   (m05_axi_wready),
    .s_axi_bid      (m05_axi_bid),     .s_axi_bresp    (m05_axi_bresp),
    .s_axi_bvalid   (m05_axi_bvalid),  .s_axi_bready   (m05_axi_bready),
    .s_axi_arid     (m05_axi_arid),    .s_axi_araddr   (m05_axi_araddr),
    .s_axi_arlen    (m05_axi_arlen),   .s_axi_arsize   (m05_axi_arsize),
    .s_axi_arburst  (m05_axi_arburst), .s_axi_arvalid  (m05_axi_arvalid),
    .s_axi_arready  (m05_axi_arready),
    .s_axi_rid      (m05_axi_rid),     .s_axi_rdata    (m05_axi_rdata),
    .s_axi_rresp    (m05_axi_rresp),   .s_axi_rlast    (m05_axi_rlast),
    .s_axi_rvalid   (m05_axi_rvalid),  .s_axi_rready   (m05_axi_rready),
    .accel_done_irq (soc_cnn_irq),
    .hw_embedding   (soc_cnn_embedding)
);

// =============================================================================
// ⑬  Stub slaves for m00(IMEM), m01(DMEM), m03(Timer), m04(GPIO),
//     m06(Distance), m07(DMA regs), and IFU direct IMEM port.
//    Each stub accepts transactions and returns OKAY/zero.
//    Replace with real RTL modules as they are developed.
// =============================================================================

// ---- Real Dual-Port IMEM (Port A: ifu32 direct IFU fetch, Port B: m00 interconnect LSU/DMA) ----
imem_axi #(
    .DATA_WIDTH (32),
    .ADDR_WIDTH (32),
    .ID_WIDTH_A (8),
    .ID_WIDTH_B (8),
    .MEM_SIZE   (65536)
) u_imem (
    .clk            (clk),
    .rst_n          (rst_l),

    // Port A: CPU IFU direct instruction fetch
    .s_axi_a_awid   (ifu32_awid),
    .s_axi_a_awaddr (ifu32_awaddr),
    .s_axi_a_awlen  (ifu32_awlen),
    .s_axi_a_awsize (ifu32_awsize),
    .s_axi_a_awburst(ifu32_awburst),
    .s_axi_a_awvalid(ifu32_awvalid),
    .s_axi_a_awready(ifu32_awready),
    .s_axi_a_wdata  (ifu32_wdata),
    .s_axi_a_wstrb  (ifu32_wstrb),
    .s_axi_a_wlast  (ifu32_wlast),
    .s_axi_a_wvalid (ifu32_wvalid),
    .s_axi_a_wready (ifu32_wready),
    .s_axi_a_bid    (ifu32_bid),
    .s_axi_a_bresp  (ifu32_bresp),
    .s_axi_a_bvalid (ifu32_bvalid),
    .s_axi_a_bready (ifu32_bready),
    .s_axi_a_arid   (ifu32_arid),
    .s_axi_a_araddr (ifu32_araddr),
    .s_axi_a_arlen  (ifu32_arlen),
    .s_axi_a_arsize (ifu32_arsize),
    .s_axi_a_arburst(ifu32_arburst),
    .s_axi_a_arvalid(ifu32_arvalid),
    .s_axi_a_arready(ifu32_arready),
    .s_axi_a_rid    (ifu32_rid),
    .s_axi_a_rdata  (ifu32_rdata),
    .s_axi_a_rresp  (ifu32_rresp),
    .s_axi_a_rlast  (ifu32_rlast),
    .s_axi_a_rvalid (ifu32_rvalid),
    .s_axi_a_rready (ifu32_rready),

    // Port B: Interconnect m00 (LSU / DMA / System)
    .s_axi_b_awid   (m00_axi_awid),
    .s_axi_b_awaddr (m00_axi_awaddr),
    .s_axi_b_awlen  (m00_axi_awlen),
    .s_axi_b_awsize (m00_axi_awsize),
    .s_axi_b_awburst(m00_axi_awburst),
    .s_axi_b_awvalid(m00_axi_awvalid),
    .s_axi_b_awready(m00_axi_awready),
    .s_axi_b_wdata  (m00_axi_wdata),
    .s_axi_b_wstrb  (m00_axi_wstrb),
    .s_axi_b_wlast  (m00_axi_wlast),
    .s_axi_b_wvalid (m00_axi_wvalid),
    .s_axi_b_wready (m00_axi_wready),
    .s_axi_b_bid    (m00_axi_bid),
    .s_axi_b_bresp  (m00_axi_bresp),
    .s_axi_b_bvalid (m00_axi_bvalid),
    .s_axi_b_bready (m00_axi_bready),
    .s_axi_b_arid   (m00_axi_arid),
    .s_axi_b_araddr (m00_axi_araddr),
    .s_axi_b_arlen  (m00_axi_arlen),
    .s_axi_b_arsize (m00_axi_arsize),
    .s_axi_b_arburst(m00_axi_arburst),
    .s_axi_b_arvalid(m00_axi_arvalid),
    .s_axi_b_arready(m00_axi_arready),
    .s_axi_b_rid    (m00_axi_rid),
    .s_axi_b_rdata  (m00_axi_rdata),
    .s_axi_b_rresp  (m00_axi_rresp),
    .s_axi_b_rlast  (m00_axi_rlast),
    .s_axi_b_rvalid (m00_axi_rvalid),
    .s_axi_b_rready (m00_axi_rready)
);

// ---- Real Single-Port DMEM (m01 from interconnect: LSU / DMA) ----
dmem_axi #(
    .DATA_WIDTH (32),
    .ADDR_WIDTH (32),
    .ID_WIDTH   (8),
    .MEM_SIZE   (65536)
) u_dmem (
    .clk          (clk),
    .rst_n        (rst_l),
    .s_axi_awid   (m01_axi_awid),
    .s_axi_awaddr (m01_axi_awaddr),
    .s_axi_awlen  (m01_axi_awlen),
    .s_axi_awsize (m01_axi_awsize),
    .s_axi_awburst(m01_axi_awburst),
    .s_axi_awvalid(m01_axi_awvalid),
    .s_axi_awready(m01_axi_awready),
    .s_axi_wdata  (m01_axi_wdata),
    .s_axi_wstrb  (m01_axi_wstrb),
    .s_axi_wlast  (m01_axi_wlast),
    .s_axi_wvalid (m01_axi_wvalid),
    .s_axi_wready (m01_axi_wready),
    .s_axi_bid    (m01_axi_bid),
    .s_axi_bresp  (m01_axi_bresp),
    .s_axi_bvalid (m01_axi_bvalid),
    .s_axi_bready (m01_axi_bready),
    .s_axi_arid   (m01_axi_arid),
    .s_axi_araddr (m01_axi_araddr),
    .s_axi_arlen  (m01_axi_arlen),
    .s_axi_arsize (m01_axi_arsize),
    .s_axi_arburst(m01_axi_arburst),
    .s_axi_arvalid(m01_axi_arvalid),
    .s_axi_arready(m01_axi_arready),
    .s_axi_rid    (m01_axi_rid),
    .s_axi_rdata  (m01_axi_rdata),
    .s_axi_rresp  (m01_axi_rresp),
    .s_axi_rlast  (m01_axi_rlast),
    .s_axi_rvalid (m01_axi_rvalid),
    .s_axi_rready (m01_axi_rready)
);

// ---- Timer IP (m03 @ 0x2000_1000) ----
timer_axi_wrapper #(
    .DATA_WIDTH (32),
    .ADDR_WIDTH (32),
    .ID_WIDTH   (8)
) u_timer (
    .clk            (clk),
    .rst_n          (rst_l),
    .s_axi_awid     (m03_axi_awid),   .s_axi_awaddr   (m03_axi_awaddr),
    .s_axi_awlen    (m03_axi_awlen),  .s_axi_awsize   (m03_axi_awsize),
    .s_axi_awburst  (m03_axi_awburst),.s_axi_awvalid  (m03_axi_awvalid),
    .s_axi_awready  (m03_axi_awready),
    .s_axi_wdata    (m03_axi_wdata),  .s_axi_wstrb    (m03_axi_wstrb),
    .s_axi_wlast    (m03_axi_wlast),  .s_axi_wvalid   (m03_axi_wvalid),
    .s_axi_wready   (m03_axi_wready),
    .s_axi_bid      (m03_axi_bid),    .s_axi_bresp    (m03_axi_bresp),
    .s_axi_bvalid   (m03_axi_bvalid), .s_axi_bready   (m03_axi_bready),
    .s_axi_arid     (m03_axi_arid),   .s_axi_araddr   (m03_axi_araddr),
    .s_axi_arlen    (m03_axi_arlen),  .s_axi_arsize   (m03_axi_arsize),
    .s_axi_arburst  (m03_axi_arburst),.s_axi_arvalid  (m03_axi_arvalid),
    .s_axi_arready  (m03_axi_arready),
    .s_axi_rid      (m03_axi_rid),    .s_axi_rdata    (m03_axi_rdata),
    .s_axi_rresp    (m03_axi_rresp),  .s_axi_rlast    (m03_axi_rlast),
    .s_axi_rvalid   (m03_axi_rvalid), .s_axi_rready   (m03_axi_rready),
    .timer_irq_o    (soc_timer_irq)
);

// ---- GPIO IP (m04 @ 0x2000_2000) ----
gpio_axi_wrapper #(
    .DATA_WIDTH (32),
    .ADDR_WIDTH (32),
    .STRB_WIDTH (4),
    .ID_WIDTH   (8),
    .GPIO_COUNT (32)
) u_gpio (
    .clk            (clk),
    .rst_n          (rst_l),
    .s_axi_awid     (m04_axi_awid),   .s_axi_awaddr   (m04_axi_awaddr),
    .s_axi_awlen    (m04_axi_awlen),  .s_axi_awsize   (m04_axi_awsize),
    .s_axi_awburst  (m04_axi_awburst),.s_axi_awvalid  (m04_axi_awvalid),
    .s_axi_awready  (m04_axi_awready),
    .s_axi_wdata    (m04_axi_wdata),  .s_axi_wstrb    (m04_axi_wstrb),
    .s_axi_wlast    (m04_axi_wlast),  .s_axi_wvalid   (m04_axi_wvalid),
    .s_axi_wready   (m04_axi_wready),
    .s_axi_bid      (m04_axi_bid),    .s_axi_bresp    (m04_axi_bresp),
    .s_axi_bvalid   (m04_axi_bvalid), .s_axi_bready   (m04_axi_bready),
    .s_axi_arid     (m04_axi_arid),   .s_axi_araddr   (m04_axi_araddr),
    .s_axi_arlen    (m04_axi_arlen),  .s_axi_arsize   (m04_axi_arsize),
    .s_axi_arburst  (m04_axi_arburst),.s_axi_arvalid  (m04_axi_arvalid),
    .s_axi_arready  (m04_axi_arready),
    .s_axi_rid      (m04_axi_rid),    .s_axi_rdata    (m04_axi_rdata),
    .s_axi_rresp    (m04_axi_rresp),  .s_axi_rlast    (m04_axi_rlast),
    .s_axi_rvalid   (m04_axi_rvalid), .s_axi_rready   (m04_axi_rready),
    .gpio_i         (gpio_i),
    .gpio_o         (gpio_o),
    .gpio_dir_o     (gpio_dir_o),
    .gpio_in_sync_o (soc_gpio_in_sync),
    .gpio_irq_o     (soc_gpio_irq),
    .gpio_pin_irq_o (soc_gpio_pin_irqs)
);

// Distance/Similarity AXI-Lite wrapper instance
distance_axi_wrapper #(
    .DATA_WIDTH (IC_DATA),
    .ADDR_WIDTH (IC_ADDR),
    .STRB_WIDTH (IC_STRB),
    .ID_WIDTH   (IC_ID)
) u_dist_axi (
    .clk                (clk),
    .rst_n              (rst_l),
    .s_axi_awid         (m06_axi_awid),    .s_axi_awaddr   (m06_axi_awaddr),
    .s_axi_awlen        (m06_axi_awlen),   .s_axi_awsize   (m06_axi_awsize),
    .s_axi_awburst      (m06_axi_awburst), .s_axi_awvalid  (m06_axi_awvalid),
    .s_axi_awready      (m06_axi_awready),
    .s_axi_wdata        (m06_axi_wdata),   .s_axi_wstrb    (m06_axi_wstrb),
    .s_axi_wlast        (m06_axi_wlast),   .s_axi_wvalid   (m06_axi_wvalid),
    .s_axi_wready       (m06_axi_wready),
    .s_axi_bid          (m06_axi_bid),     .s_axi_bresp    (m06_axi_bresp),
    .s_axi_bvalid       (m06_axi_bvalid),  .s_axi_bready   (m06_axi_bready),
    .s_axi_arid         (m06_axi_arid),    .s_axi_araddr   (m06_axi_araddr),
    .s_axi_arlen        (m06_axi_arlen),   .s_axi_arsize   (m06_axi_arsize),
    .s_axi_arburst      (m06_axi_arburst), .s_axi_arvalid  (m06_axi_arvalid),
    .s_axi_arready      (m06_axi_arready),
    .s_axi_rid          (m06_axi_rid),     .s_axi_rdata    (m06_axi_rdata),
    .s_axi_rresp        (m06_axi_rresp),   .s_axi_rlast    (m06_axi_rlast),
    .s_axi_rvalid       (m06_axi_rvalid),  .s_axi_rready   (m06_axi_rready),
    .hw_query_embedding (soc_cnn_embedding),
    .score_done_irq     (soc_dist_irq)
);

// ---- DMA register stub (m07) ----
axi_slave_stub #(.DATA_WIDTH(32),.ADDR_WIDTH(32),.ID_WIDTH(8)) u_dma_regs (
    .clk(clk), .rst_n(rst_l),
    .s_axi_awid(m07_axi_awid),   .s_axi_awaddr(m07_axi_awaddr),
    .s_axi_awlen(m07_axi_awlen), .s_axi_awsize(m07_axi_awsize),
    .s_axi_awburst(m07_axi_awburst),.s_axi_awvalid(m07_axi_awvalid),
    .s_axi_awready(m07_axi_awready),
    .s_axi_wdata(m07_axi_wdata), .s_axi_wstrb(m07_axi_wstrb),
    .s_axi_wlast(m07_axi_wlast), .s_axi_wvalid(m07_axi_wvalid),
    .s_axi_wready(m07_axi_wready),
    .s_axi_bid(m07_axi_bid),     .s_axi_bresp(m07_axi_bresp),
    .s_axi_bvalid(m07_axi_bvalid),.s_axi_bready(m07_axi_bready),
    .s_axi_arid(m07_axi_arid),   .s_axi_araddr(m07_axi_araddr),
    .s_axi_arlen(m07_axi_arlen), .s_axi_arsize(m07_axi_arsize),
    .s_axi_arburst(m07_axi_arburst),.s_axi_arvalid(m07_axi_arvalid),
    .s_axi_arready(m07_axi_arready),
    .s_axi_rid(m07_axi_rid),     .s_axi_rdata(m07_axi_rdata),
    .s_axi_rresp(m07_axi_rresp), .s_axi_rlast(m07_axi_rlast),
    .s_axi_rvalid(m07_axi_rvalid),.s_axi_rready(m07_axi_rready)
);

endmodule : cnn_soc_top
`default_nettype wire

// =============================================================================
// axi_slave_stub — compile-ready placeholder slave
// Accepts all AXI4 transactions; returns OKAY writes and zero reads.
// Replace each instance above with real peripheral RTL as it becomes available.
// =============================================================================
module axi_slave_stub #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32,
    parameter int ID_WIDTH   = 8
) (
    input  logic                    clk,
    input  logic                    rst_n,
    // Write address
    input  logic [ID_WIDTH-1:0]     s_axi_awid,
    input  logic [ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  logic [7:0]              s_axi_awlen,
    input  logic [2:0]              s_axi_awsize,
    input  logic [1:0]              s_axi_awburst,
    input  logic                    s_axi_awvalid,
    output logic                    s_axi_awready,
    // Write data
    input  logic [DATA_WIDTH-1:0]   s_axi_wdata,
    input  logic [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  logic                    s_axi_wlast,
    input  logic                    s_axi_wvalid,
    output logic                    s_axi_wready,
    // Write response
    output logic [ID_WIDTH-1:0]     s_axi_bid,
    output logic [1:0]              s_axi_bresp,
    output logic                    s_axi_bvalid,
    input  logic                    s_axi_bready,
    // Read address
    input  logic [ID_WIDTH-1:0]     s_axi_arid,
    input  logic [ADDR_WIDTH-1:0]   s_axi_araddr,
    input  logic [7:0]              s_axi_arlen,
    input  logic [2:0]              s_axi_arsize,
    input  logic [1:0]              s_axi_arburst,
    input  logic                    s_axi_arvalid,
    output logic                    s_axi_arready,
    // Read data
    output logic [ID_WIDTH-1:0]     s_axi_rid,
    output logic [DATA_WIDTH-1:0]   s_axi_rdata,
    output logic [1:0]              s_axi_rresp,
    output logic                    s_axi_rlast,
    output logic                    s_axi_rvalid,
    input  logic                    s_axi_rready
);
    // Simple one-cycle accept-and-respond
    // Write: accept AW+W simultaneously, return OKAY on next cycle
    logic aw_seen, w_seen;
    logic [ID_WIDTH-1:0] wr_id;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_seen <= 1'b0; w_seen <= 1'b0;
            wr_id   <= '0;
            s_axi_bvalid <= 1'b0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin
                aw_seen <= 1'b1; wr_id <= s_axi_awid;
            end
            if (s_axi_wvalid && s_axi_wready && s_axi_wlast)
                w_seen <= 1'b1;
            if ((aw_seen || (s_axi_awvalid && s_axi_awready)) &&
                (w_seen  || (s_axi_wvalid  && s_axi_wready && s_axi_wlast))) begin
                s_axi_bvalid <= 1'b1;
                if (s_axi_bvalid && s_axi_bready) begin
                    s_axi_bvalid <= 1'b0;
                    aw_seen <= 1'b0; w_seen <= 1'b0;
                end
            end
            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
                aw_seen <= 1'b0; w_seen <= 1'b0;
            end
        end
    end

    assign s_axi_awready = 1'b1;
    assign s_axi_wready  = 1'b1;
    assign s_axi_bid     = wr_id;
    assign s_axi_bresp   = 2'b00; // OKAY

    // Read: one-cycle response
    logic [ID_WIDTH-1:0] rd_id_r;
    logic                rd_pending;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_pending   <= 1'b0;
            rd_id_r      <= '0;
            s_axi_rvalid <= 1'b0;
        end else begin
            if (s_axi_arvalid && s_axi_arready && !rd_pending) begin
                rd_pending   <= 1'b1;
                rd_id_r      <= s_axi_arid;
                s_axi_rvalid <= 1'b1;
            end
            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
                rd_pending   <= 1'b0;
            end
        end
    end

    assign s_axi_arready = !rd_pending;
    assign s_axi_rid     = rd_id_r;
    assign s_axi_rdata   = '0;
    assign s_axi_rresp   = 2'b00; // OKAY
    assign s_axi_rlast   = 1'b1;

endmodule : axi_slave_stub
