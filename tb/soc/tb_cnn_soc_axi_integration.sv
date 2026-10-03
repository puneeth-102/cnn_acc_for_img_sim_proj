// =============================================================================
// File   : tb_cnn_soc_axi_integration.sv
// Module : tb_cnn_soc_axi_integration
// Purpose: Full AXI Interconnect + Peripheral Integration Testbench.
//          Connects:
//            - CPU Master (S00)
//            - 2x8 AXI Interconnect (axi_interconnect_wrap_2x8)
//            - UART (m02 @ 0x2000_0000)
//            - CNN Accelerator (m05 @ 0x2000_3000)
//            - Distance/Similarity IP (m06 @ 0x2000_4000)
//            - Peripheral stubs for IMEM (m00), DMEM (m01), Timer (m03), GPIO (m04), DMA (m07)
//          Verifies:
//            1. CPU -> AXI -> UART access & register configuration
//            2. CPU -> AXI -> CNN configuration, execution, busy/done polling & result readback
//            3. CPU -> AXI -> Distance engine configuration, execution & result readback (MATCH & ANOMALY)
//            4. Direct hardware coupling from CNN to Distance IP
//            5. Dedicated interrupts (uart_irq_o, cnn_irq_o, dist_irq_o)
//            6. Interconnect address decoding and unmapped address DECERR response
// =============================================================================

`timescale 1ns/1ps

module tb_cnn_soc_axi_integration;

    localparam int DW  = 32;
    localparam int AW  = 32;
    localparam int SW  = DW / 8;
    localparam int IDW = 8;

    logic clk;
    logic rst;
    wire  rst_n = ~rst;

    // Clock generation (100 MHz)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // S00 Master wires (CPU)
    logic [IDW-1:0] s00_awid;
    logic [AW-1:0]  s00_awaddr;
    logic [7:0]     s00_awlen;
    logic [2:0]     s00_awsize;
    logic [1:0]     s00_awburst;
    logic           s00_awlock;
    logic [3:0]     s00_awcache;
    logic [2:0]     s00_awprot;
    logic [3:0]     s00_awqos;
    logic           s00_awvalid;
    wire            s00_awready;

    logic [DW-1:0]  s00_wdata;
    logic [SW-1:0]  s00_wstrb;
    logic           s00_wlast;
    logic           s00_wvalid;
    wire            s00_wready;

    wire [IDW-1:0]  s00_bid;
    wire [1:0]      s00_bresp;
    wire            s00_bvalid;
    logic           s00_bready;

    logic [IDW-1:0] s00_arid;
    logic [AW-1:0]  s00_araddr;
    logic [7:0]     s00_arlen;
    logic [2:0]     s00_arsize;
    logic [1:0]     s00_arburst;
    logic           s00_arlock;
    logic [3:0]     s00_arcache;
    logic [2:0]     s00_arprot;
    logic [3:0]     s00_arqos;
    logic           s00_arvalid;
    wire            s00_arready;

    wire [IDW-1:0]  s00_rid;
    wire [DW-1:0]   s00_rdata;
    wire [1:0]      s00_rresp;
    wire            s00_rlast;
    wire            s00_rvalid;
    logic           s00_rready;

    // Interconnect master port wires (m00 - m07)
    // m00: IMEM
    wire [IDW-1:0] m00_awid;    wire [AW-1:0]  m00_awaddr; wire [7:0]     m00_awlen;
    wire [2:0]     m00_awsize;  wire [1:0]     m00_awburst;wire           m00_awlock;
    wire [3:0]     m00_awcache; wire [2:0]     m00_awprot; wire [3:0]     m00_awqos;
    wire [3:0]     m00_awregion;wire           m00_awvalid;wire           m00_awready;
    wire [DW-1:0]  m00_wdata;   wire [SW-1:0]  m00_wstrb;  wire           m00_wlast;
    wire           m00_wvalid;  wire           m00_wready;
    wire [IDW-1:0] m00_bid;     wire [1:0]     m00_bresp;  wire           m00_bvalid;
    wire           m00_bready;
    wire [IDW-1:0] m00_arid;    wire [AW-1:0]  m00_araddr; wire [7:0]     m00_arlen;
    wire [2:0]     m00_arsize;  wire [1:0]     m00_arburst;wire           m00_arlock;
    wire [3:0]     m00_arcache; wire [2:0]     m00_arprot; wire [3:0]     m00_arqos;
    wire [3:0]     m00_arregion;wire           m00_arvalid;wire           m00_arready;
    wire [IDW-1:0] m00_rid;     wire [DW-1:0]  m00_rdata;  wire [1:0]     m00_rresp;
    wire           m00_rlast;   wire           m00_rvalid; wire           m00_rready;

    // m01: DMEM
    wire [IDW-1:0] m01_awid;    wire [AW-1:0]  m01_awaddr; wire [7:0]     m01_awlen;
    wire [2:0]     m01_awsize;  wire [1:0]     m01_awburst;wire           m01_awlock;
    wire [3:0]     m01_awcache; wire [2:0]     m01_awprot; wire [3:0]     m01_awqos;
    wire [3:0]     m01_awregion;wire           m01_awvalid;wire           m01_awready;
    wire [DW-1:0]  m01_wdata;   wire [SW-1:0]  m01_wstrb;  wire           m01_wlast;
    wire           m01_wvalid;  wire           m01_wready;
    wire [IDW-1:0] m01_bid;     wire [1:0]     m01_bresp;  wire           m01_bvalid;
    wire           m01_bready;
    wire [IDW-1:0] m01_arid;    wire [AW-1:0]  m01_araddr; wire [7:0]     m01_arlen;
    wire [2:0]     m01_arsize;  wire [1:0]     m01_arburst;wire           m01_arlock;
    wire [3:0]     m01_arcache; wire [2:0]     m01_arprot; wire [3:0]     m01_arqos;
    wire [3:0]     m01_arregion;wire           m01_arvalid;wire           m01_arready;
    wire [IDW-1:0] m01_rid;     wire [DW-1:0]  m01_rdata;  wire [1:0]     m01_rresp;
    wire           m01_rlast;   wire           m01_rvalid; wire           m01_rready;

    // m02: UART
    wire [IDW-1:0] m02_awid;    wire [AW-1:0]  m02_awaddr; wire [7:0]     m02_awlen;
    wire [2:0]     m02_awsize;  wire [1:0]     m02_awburst;wire           m02_awlock;
    wire [3:0]     m02_awcache; wire [2:0]     m02_awprot; wire [3:0]     m02_awqos;
    wire [3:0]     m02_awregion;wire           m02_awvalid;wire           m02_awready;
    wire [DW-1:0]  m02_wdata;   wire [SW-1:0]  m02_wstrb;  wire           m02_wlast;
    wire           m02_wvalid;  wire           m02_wready;
    wire [IDW-1:0] m02_bid;     wire [1:0]     m02_bresp;  wire           m02_bvalid;
    wire           m02_bready;
    wire [IDW-1:0] m02_arid;    wire [AW-1:0]  m02_araddr; wire [7:0]     m02_arlen;
    wire [2:0]     m02_arsize;  wire [1:0]     m02_arburst;wire           m02_arlock;
    wire [3:0]     m02_arcache; wire [2:0]     m02_arprot; wire [3:0]     m02_arqos;
    wire [3:0]     m02_arregion;wire           m02_arvalid;wire           m02_arready;
    wire [IDW-1:0] m02_rid;     wire [DW-1:0]  m02_rdata;  wire [1:0]     m02_rresp;
    wire           m02_rlast;   wire           m02_rvalid; wire           m02_rready;

    // m03: Timer
    wire [IDW-1:0] m03_awid;    wire [AW-1:0]  m03_awaddr; wire [7:0]     m03_awlen;
    wire [2:0]     m03_awsize;  wire [1:0]     m03_awburst;wire           m03_awlock;
    wire [3:0]     m03_awcache; wire [2:0]     m03_awprot; wire [3:0]     m03_awqos;
    wire [3:0]     m03_awregion;wire           m03_awvalid;wire           m03_awready;
    wire [DW-1:0]  m03_wdata;   wire [SW-1:0]  m03_wstrb;  wire           m03_wlast;
    wire           m03_wvalid;  wire           m03_wready;
    wire [IDW-1:0] m03_bid;     wire [1:0]     m03_bresp;  wire           m03_bvalid;
    wire           m03_bready;
    wire [IDW-1:0] m03_arid;    wire [AW-1:0]  m03_araddr; wire [7:0]     m03_arlen;
    wire [2:0]     m03_arsize;  wire [1:0]     m03_arburst;wire           m03_arlock;
    wire [3:0]     m03_arcache; wire [2:0]     m03_arprot; wire [3:0]     m03_arqos;
    wire [3:0]     m03_arregion;wire           m03_arvalid;wire           m03_arready;
    wire [IDW-1:0] m03_rid;     wire [DW-1:0]  m03_rdata;  wire [1:0]     m03_rresp;
    wire           m03_rlast;   wire           m03_rvalid; wire           m03_rready;

    // m04: GPIO
    wire [IDW-1:0] m04_awid;    wire [AW-1:0]  m04_awaddr; wire [7:0]     m04_awlen;
    wire [2:0]     m04_awsize;  wire [1:0]     m04_awburst;wire           m04_awlock;
    wire [3:0]     m04_awcache; wire [2:0]     m04_awprot; wire [3:0]     m04_awqos;
    wire [3:0]     m04_awregion;wire           m04_awvalid;wire           m04_awready;
    wire [DW-1:0]  m04_wdata;   wire [SW-1:0]  m04_wstrb;  wire           m04_wlast;
    wire           m04_wvalid;  wire           m04_wready;
    wire [IDW-1:0] m04_bid;     wire [1:0]     m04_bresp;  wire           m04_bvalid;
    wire           m04_bready;
    wire [IDW-1:0] m04_arid;    wire [AW-1:0]  m04_araddr; wire [7:0]     m04_arlen;
    wire [2:0]     m04_arsize;  wire [1:0]     m04_arburst;wire           m04_arlock;
    wire [3:0]     m04_arcache; wire [2:0]     m04_arprot; wire [3:0]     m04_arqos;
    wire [3:0]     m04_arregion;wire           m04_arvalid;wire           m04_arready;
    wire [IDW-1:0] m04_rid;     wire [DW-1:0]  m04_rdata;  wire [1:0]     m04_rresp;
    wire           m04_rlast;   wire           m04_rvalid; wire           m04_rready;

    // m05: CNN Accelerator
    wire [IDW-1:0] m05_awid;    wire [AW-1:0]  m05_awaddr; wire [7:0]     m05_awlen;
    wire [2:0]     m05_awsize;  wire [1:0]     m05_awburst;wire           m05_awlock;
    wire [3:0]     m05_awcache; wire [2:0]     m05_awprot; wire [3:0]     m05_awqos;
    wire [3:0]     m05_awregion;wire           m05_awvalid;wire           m05_awready;
    wire [DW-1:0]  m05_wdata;   wire [SW-1:0]  m05_wstrb;  wire           m05_wlast;
    wire           m05_wvalid;  wire           m05_wready;
    wire [IDW-1:0] m05_bid;     wire [1:0]     m05_bresp;  wire           m05_bvalid;
    wire           m05_bready;
    wire [IDW-1:0] m05_arid;    wire [AW-1:0]  m05_araddr; wire [7:0]     m05_arlen;
    wire [2:0]     m05_arsize;  wire [1:0]     m05_arburst;wire           m05_arlock;
    wire [3:0]     m05_arcache; wire [2:0]     m05_arprot; wire [3:0]     m05_arqos;
    wire [3:0]     m05_arregion;wire           m05_arvalid;wire           m05_arready;
    wire [IDW-1:0] m05_rid;     wire [DW-1:0]  m05_rdata;  wire [1:0]     m05_rresp;
    wire           m05_rlast;   wire           m05_rvalid; wire           m05_rready;

    // m06: Distance Engine
    wire [IDW-1:0] m06_awid;    wire [AW-1:0]  m06_awaddr; wire [7:0]     m06_awlen;
    wire [2:0]     m06_awsize;  wire [1:0]     m06_awburst;wire           m06_awlock;
    wire [3:0]     m06_awcache; wire [2:0]     m06_awprot; wire [3:0]     m06_awqos;
    wire [3:0]     m06_awregion;wire           m06_awvalid;wire           m06_awready;
    wire [DW-1:0]  m06_wdata;   wire [SW-1:0]  m06_wstrb;  wire           m06_wlast;
    wire           m06_wvalid;  wire           m06_wready;
    wire [IDW-1:0] m06_bid;     wire [1:0]     m06_bresp;  wire           m06_bvalid;
    wire           m06_bready;
    wire [IDW-1:0] m06_arid;    wire [AW-1:0]  m06_araddr; wire [7:0]     m06_arlen;
    wire [2:0]     m06_arsize;  wire [1:0]     m06_arburst;wire           m06_arlock;
    wire [3:0]     m06_arcache; wire [2:0]     m06_arprot; wire [3:0]     m06_arqos;
    wire [3:0]     m06_arregion;wire           m06_arvalid;wire           m06_arready;
    wire [IDW-1:0] m06_rid;     wire [DW-1:0]  m06_rdata;  wire [1:0]     m06_rresp;
    wire           m06_rlast;   wire           m06_rvalid; wire           m06_rready;

    // m07: DMA Regs
    wire [IDW-1:0] m07_awid;    wire [AW-1:0]  m07_awaddr; wire [7:0]     m07_awlen;
    wire [2:0]     m07_awsize;  wire [1:0]     m07_awburst;wire           m07_awlock;
    wire [3:0]     m07_awcache; wire [2:0]     m07_awprot; wire [3:0]     m07_awqos;
    wire [3:0]     m07_awregion;wire           m07_awvalid;wire           m07_awready;
    wire [DW-1:0]  m07_wdata;   wire [SW-1:0]  m07_wstrb;  wire           m07_wlast;
    wire           m07_wvalid;  wire           m07_wready;
    wire [IDW-1:0] m07_bid;     wire [1:0]     m07_bresp;  wire           m07_bvalid;
    wire           m07_bready;
    wire [IDW-1:0] m07_arid;    wire [AW-1:0]  m07_araddr; wire [7:0]     m07_arlen;
    wire [2:0]     m07_arsize;  wire [1:0]     m07_arburst;wire           m07_arlock;
    wire [3:0]     m07_arcache; wire [2:0]     m07_arprot; wire [3:0]     m07_arqos;
    wire [3:0]     m07_arregion;wire           m07_arvalid;wire           m07_arready;
    wire [IDW-1:0] m07_rid;     wire [DW-1:0]  m07_rdata;  wire [1:0]     m07_rresp;
    wire           m07_rlast;   wire           m07_rvalid; wire           m07_rready;

    // Dedicated Peripheral Interrupts
    wire uart_irq_o;
    wire cnn_irq_o;
    wire dist_irq_o;
    wire timer_irq_o;
    wire gpio_irq_o;
    wire [31:0] gpio_pin_irq_o;
    logic [31:0] gpio_i = '0;
    wire  [31:0] gpio_o;
    wire  [31:0] gpio_dir_o;
    wire  [31:0] gpio_in_sync_o;
    wire signed [31:0] cnn_hw_embedding [0:15];

    // UART loopback signal
    wire uart_tx_line;

    // =========================================================================
    // Instantiate 2x8 AXI Interconnect Wrapper
    // =========================================================================
    axi_interconnect_wrap_2x8 #(
        .DATA_WIDTH (DW),
        .ADDR_WIDTH (AW),
        .ID_WIDTH   (IDW)
    ) u_ic (
        .clk (clk),
        .rst (rst),

        // S00: CPU Master
        .s00_axi_awid     (s00_awid),    .s00_axi_awaddr   (s00_awaddr),
        .s00_axi_awlen    (s00_awlen),   .s00_axi_awsize   (s00_awsize),
        .s00_axi_awburst  (s00_awburst), .s00_axi_awlock   (s00_awlock),
        .s00_axi_awcache  (s00_awcache), .s00_axi_awprot   (s00_awprot),
        .s00_axi_awqos    (s00_awqos),   .s00_axi_awuser   (1'b0),
        .s00_axi_awvalid  (s00_awvalid), .s00_axi_awready  (s00_awready),
        .s00_axi_wdata    (s00_wdata),   .s00_axi_wstrb    (s00_wstrb),
        .s00_axi_wlast    (s00_wlast),   .s00_axi_wuser    (1'b0),
        .s00_axi_wvalid   (s00_wvalid),  .s00_axi_wready   (s00_wready),
        .s00_axi_bid      (s00_bid),     .s00_axi_bresp    (s00_bresp),
        .s00_axi_buser    (),            .s00_axi_bvalid   (s00_bvalid),
        .s00_axi_bready   (s00_bready),
        .s00_axi_arid     (s00_arid),    .s00_axi_araddr   (s00_araddr),
        .s00_axi_arlen    (s00_arlen),   .s00_axi_arsize   (s00_arsize),
        .s00_axi_arburst  (s00_arburst), .s00_axi_arlock   (s00_arlock),
        .s00_axi_arcache  (s00_arcache), .s00_axi_arprot   (s00_arprot),
        .s00_axi_arqos    (s00_arqos),   .s00_axi_aruser   (1'b0),
        .s00_axi_arvalid  (s00_arvalid), .s00_axi_arready  (s00_arready),
        .s00_axi_rid      (s00_rid),     .s00_axi_rdata    (s00_rdata),
        .s00_axi_rresp    (s00_rresp),   .s00_axi_rlast    (s00_rlast),
        .s00_axi_ruser    (),            .s00_axi_rvalid   (s00_rvalid),
        .s00_axi_rready   (s00_rready),

        // S01: DMA Master (tied off for this test)
        .s01_axi_awid     ('0),   .s01_axi_awaddr   ('0),
        .s01_axi_awlen    ('0),   .s01_axi_awsize   ('0),
        .s01_axi_awburst  ('0),   .s01_axi_awlock   ('0),
        .s01_axi_awcache  ('0),   .s01_axi_awprot   ('0),
        .s01_axi_awqos    ('0),   .s01_axi_awuser   ('0),
        .s01_axi_awvalid  (1'b0), .s01_axi_awready  (),
        .s01_axi_wdata    ('0),   .s01_axi_wstrb    ('0),
        .s01_axi_wlast    (1'b0), .s01_axi_wuser    ('0),
        .s01_axi_wvalid   (1'b0), .s01_axi_wready   (),
        .s01_axi_bid      (),     .s01_axi_bresp    (),
        .s01_axi_buser    (),     .s01_axi_bvalid   (),
        .s01_axi_bready   (1'b0),
        .s01_axi_arid     ('0),   .s01_axi_araddr   ('0),
        .s01_axi_arlen    ('0),   .s01_axi_arsize   ('0),
        .s01_axi_arburst  ('0),   .s01_axi_arlock   ('0),
        .s01_axi_arcache  ('0),   .s01_axi_arprot   ('0),
        .s01_axi_arqos    ('0),   .s01_axi_aruser   ('0),
        .s01_axi_arvalid  (1'b0), .s01_axi_arready  (),
        .s01_axi_rid      (),     .s01_axi_rdata    (),
        .s01_axi_rresp    (),     .s01_axi_rlast    (),
        .s01_axi_ruser    (),     .s01_axi_rvalid   (),
        .s01_axi_rready   (1'b0),

        // M00 - M07
        .m00_axi_awid(m00_awid), .m00_axi_awaddr(m00_awaddr), .m00_axi_awlen(m00_awlen),
        .m00_axi_awsize(m00_awsize), .m00_axi_awburst(m00_awburst), .m00_axi_awlock(m00_awlock),
        .m00_axi_awcache(m00_awcache), .m00_axi_awprot(m00_awprot), .m00_axi_awqos(m00_awqos),
        .m00_axi_awregion(m00_awregion), .m00_axi_awuser(), .m00_axi_awvalid(m00_awvalid),
        .m00_axi_awready(m00_awready), .m00_axi_wdata(m00_wdata), .m00_axi_wstrb(m00_wstrb),
        .m00_axi_wlast(m00_wlast), .m00_axi_wuser(), .m00_axi_wvalid(m00_wvalid),
        .m00_axi_wready(m00_wready), .m00_axi_bid(m00_bid), .m00_axi_bresp(m00_bresp),
        .m00_axi_buser(1'b0), .m00_axi_bvalid(m00_bvalid), .m00_axi_bready(m00_bready),
        .m00_axi_arid(m00_arid), .m00_axi_araddr(m00_araddr), .m00_axi_arlen(m00_arlen),
        .m00_axi_arsize(m00_arsize), .m00_axi_arburst(m00_arburst), .m00_axi_arlock(m00_arlock),
        .m00_axi_arcache(m00_arcache), .m00_axi_arprot(m00_arprot), .m00_axi_arqos(m00_arqos),
        .m00_axi_arregion(m00_arregion), .m00_axi_aruser(), .m00_axi_arvalid(m00_arvalid),
        .m00_axi_arready(m00_arready), .m00_axi_rid(m00_rid), .m00_axi_rdata(m00_rdata),
        .m00_axi_rresp(m00_rresp), .m00_axi_rlast(m00_rlast), .m00_axi_ruser(1'b0),
        .m00_axi_rvalid(m00_rvalid), .m00_axi_rready(m00_rready),

        .m01_axi_awid(m01_awid), .m01_axi_awaddr(m01_awaddr), .m01_axi_awlen(m01_awlen),
        .m01_axi_awsize(m01_awsize), .m01_axi_awburst(m01_awburst), .m01_axi_awlock(m01_awlock),
        .m01_axi_awcache(m01_awcache), .m01_axi_awprot(m01_awprot), .m01_axi_awqos(m01_awqos),
        .m01_axi_awregion(m01_awregion), .m01_axi_awuser(), .m01_axi_awvalid(m01_awvalid),
        .m01_axi_awready(m01_awready), .m01_axi_wdata(m01_wdata), .m01_axi_wstrb(m01_wstrb),
        .m01_axi_wlast(m01_wlast), .m01_axi_wuser(), .m01_axi_wvalid(m01_wvalid),
        .m01_axi_wready(m01_wready), .m01_axi_bid(m01_bid), .m01_axi_bresp(m01_bresp),
        .m01_axi_buser(1'b0), .m01_axi_bvalid(m01_bvalid), .m01_axi_bready(m01_bready),
        .m01_axi_arid(m01_arid), .m01_axi_araddr(m01_araddr), .m01_axi_arlen(m01_arlen),
        .m01_axi_arsize(m01_arsize), .m01_axi_arburst(m01_arburst), .m01_axi_arlock(m01_arlock),
        .m01_axi_arcache(m01_arcache), .m01_axi_arprot(m01_arprot), .m01_axi_arqos(m01_arqos),
        .m01_axi_arregion(m01_arregion), .m01_axi_aruser(), .m01_axi_arvalid(m01_arvalid),
        .m01_axi_arready(m01_arready), .m01_axi_rid(m01_rid), .m01_axi_rdata(m01_rdata),
        .m01_axi_rresp(m01_rresp), .m01_axi_rlast(m01_rlast), .m01_axi_ruser(1'b0),
        .m01_axi_rvalid(m01_rvalid), .m01_axi_rready(m01_rready),

        .m02_axi_awid(m02_awid), .m02_axi_awaddr(m02_awaddr), .m02_axi_awlen(m02_awlen),
        .m02_axi_awsize(m02_awsize), .m02_axi_awburst(m02_awburst), .m02_axi_awlock(m02_awlock),
        .m02_axi_awcache(m02_awcache), .m02_axi_awprot(m02_awprot), .m02_axi_awqos(m02_awqos),
        .m02_axi_awregion(m02_awregion), .m02_axi_awuser(), .m02_axi_awvalid(m02_awvalid),
        .m02_axi_awready(m02_awready), .m02_axi_wdata(m02_wdata), .m02_axi_wstrb(m02_wstrb),
        .m02_axi_wlast(m02_wlast), .m02_axi_wuser(), .m02_axi_wvalid(m02_wvalid),
        .m02_axi_wready(m02_wready), .m02_axi_bid(m02_bid), .m02_axi_bresp(m02_bresp),
        .m02_axi_buser(1'b0), .m02_axi_bvalid(m02_bvalid), .m02_axi_bready(m02_bready),
        .m02_axi_arid(m02_arid), .m02_axi_araddr(m02_araddr), .m02_axi_arlen(m02_arlen),
        .m02_axi_arsize(m02_arsize), .m02_axi_arburst(m02_arburst), .m02_axi_arlock(m02_arlock),
        .m02_axi_arcache(m02_arcache), .m02_axi_arprot(m02_arprot), .m02_axi_arqos(m02_arqos),
        .m02_axi_arregion(m02_arregion), .m02_axi_aruser(), .m02_axi_arvalid(m02_arvalid),
        .m02_axi_arready(m02_arready), .m02_axi_rid(m02_rid), .m02_axi_rdata(m02_rdata),
        .m02_axi_rresp(m02_rresp), .m02_axi_rlast(m02_rlast), .m02_axi_ruser(1'b0),
        .m02_axi_rvalid(m02_rvalid), .m02_axi_rready(m02_rready),

        .m03_axi_awid(m03_awid), .m03_axi_awaddr(m03_awaddr), .m03_axi_awlen(m03_awlen),
        .m03_axi_awsize(m03_awsize), .m03_axi_awburst(m03_awburst), .m03_axi_awlock(m03_awlock),
        .m03_axi_awcache(m03_awcache), .m03_axi_awprot(m03_awprot), .m03_axi_awqos(m03_awqos),
        .m03_axi_awregion(m03_awregion), .m03_axi_awuser(), .m03_axi_awvalid(m03_awvalid),
        .m03_axi_awready(m03_awready), .m03_axi_wdata(m03_wdata), .m03_axi_wstrb(m03_wstrb),
        .m03_axi_wlast(m03_wlast), .m03_axi_wuser(), .m03_axi_wvalid(m03_wvalid),
        .m03_axi_wready(m03_wready), .m03_axi_bid(m03_bid), .m03_axi_bresp(m03_bresp),
        .m03_axi_buser(1'b0), .m03_axi_bvalid(m03_bvalid), .m03_axi_bready(m03_bready),
        .m03_axi_arid(m03_arid), .m03_axi_araddr(m03_araddr), .m03_axi_arlen(m03_arlen),
        .m03_axi_arsize(m03_arsize), .m03_axi_arburst(m03_arburst), .m03_axi_arlock(m03_arlock),
        .m03_axi_arcache(m03_arcache), .m03_axi_arprot(m03_arprot), .m03_axi_arqos(m03_arqos),
        .m03_axi_arregion(m03_arregion), .m03_axi_aruser(), .m03_axi_arvalid(m03_arvalid),
        .m03_axi_arready(m03_arready), .m03_axi_rid(m03_rid), .m03_axi_rdata(m03_rdata),
        .m03_axi_rresp(m03_rresp), .m03_axi_rlast(m03_rlast), .m03_axi_ruser(1'b0),
        .m03_axi_rvalid(m03_rvalid), .m03_axi_rready(m03_rready),

        .m04_axi_awid(m04_awid), .m04_axi_awaddr(m04_awaddr), .m04_axi_awlen(m04_awlen),
        .m04_axi_awsize(m04_awsize), .m04_axi_awburst(m04_awburst), .m04_axi_awlock(m04_awlock),
        .m04_axi_awcache(m04_awcache), .m04_axi_awprot(m04_awprot), .m04_axi_awqos(m04_awqos),
        .m04_axi_awregion(m04_awregion), .m04_axi_awuser(), .m04_axi_awvalid(m04_awvalid),
        .m04_axi_awready(m04_awready), .m04_axi_wdata(m04_wdata), .m04_axi_wstrb(m04_wstrb),
        .m04_axi_wlast(m04_wlast), .m04_axi_wuser(), .m04_axi_wvalid(m04_wvalid),
        .m04_axi_wready(m04_wready), .m04_axi_bid(m04_bid), .m04_axi_bresp(m04_bresp),
        .m04_axi_buser(1'b0), .m04_axi_bvalid(m04_bvalid), .m04_axi_bready(m04_bready),
        .m04_axi_arid(m04_arid), .m04_axi_araddr(m04_araddr), .m04_axi_arlen(m04_arlen),
        .m04_axi_arsize(m04_arsize), .m04_axi_arburst(m04_arburst), .m04_axi_arlock(m04_arlock),
        .m04_axi_arcache(m04_arcache), .m04_axi_arprot(m04_arprot), .m04_axi_arqos(m04_arqos),
        .m04_axi_arregion(m04_arregion), .m04_axi_aruser(), .m04_axi_arvalid(m04_arvalid),
        .m04_axi_arready(m04_arready), .m04_axi_rid(m04_rid), .m04_axi_rdata(m04_rdata),
        .m04_axi_rresp(m04_rresp), .m04_axi_rlast(m04_rlast), .m04_axi_ruser(1'b0),
        .m04_axi_rvalid(m04_rvalid), .m04_axi_rready(m04_rready),

        .m05_axi_awid(m05_awid), .m05_axi_awaddr(m05_awaddr), .m05_axi_awlen(m05_awlen),
        .m05_axi_awsize(m05_awsize), .m05_axi_awburst(m05_awburst), .m05_axi_awlock(m05_awlock),
        .m05_axi_awcache(m05_awcache), .m05_axi_awprot(m05_awprot), .m05_axi_awqos(m05_awqos),
        .m05_axi_awregion(m05_awregion), .m05_axi_awuser(), .m05_axi_awvalid(m05_awvalid),
        .m05_axi_awready(m05_awready), .m05_axi_wdata(m05_wdata), .m05_axi_wstrb(m05_wstrb),
        .m05_axi_wlast(m05_wlast), .m05_axi_wuser(), .m05_axi_wvalid(m05_wvalid),
        .m05_axi_wready(m05_wready), .m05_axi_bid(m05_bid), .m05_axi_bresp(m05_bresp),
        .m05_axi_buser(1'b0), .m05_axi_bvalid(m05_bvalid), .m05_axi_bready(m05_bready),
        .m05_axi_arid(m05_arid), .m05_axi_araddr(m05_araddr), .m05_axi_arlen(m05_arlen),
        .m05_axi_arsize(m05_arsize), .m05_axi_arburst(m05_arburst), .m05_axi_arlock(m05_arlock),
        .m05_axi_arcache(m05_arcache), .m05_axi_arprot(m05_arprot), .m05_axi_arqos(m05_arqos),
        .m05_axi_arregion(m05_arregion), .m05_axi_aruser(), .m05_axi_arvalid(m05_arvalid),
        .m05_axi_arready(m05_arready), .m05_axi_rid(m05_rid), .m05_axi_rdata(m05_rdata),
        .m05_axi_rresp(m05_rresp), .m05_axi_rlast(m05_rlast), .m05_axi_ruser(1'b0),
        .m05_axi_rvalid(m05_rvalid), .m05_axi_rready(m05_rready),

        .m06_axi_awid(m06_awid), .m06_axi_awaddr(m06_awaddr), .m06_axi_awlen(m06_awlen),
        .m06_axi_awsize(m06_awsize), .m06_axi_awburst(m06_awburst), .m06_axi_awlock(m06_awlock),
        .m06_axi_awcache(m06_awcache), .m06_axi_awprot(m06_awprot), .m06_axi_awqos(m06_awqos),
        .m06_axi_awregion(m06_awregion), .m06_axi_awuser(), .m06_axi_awvalid(m06_awvalid),
        .m06_axi_awready(m06_awready), .m06_axi_wdata(m06_wdata), .m06_axi_wstrb(m06_wstrb),
        .m06_axi_wlast(m06_wlast), .m06_axi_wuser(), .m06_axi_wvalid(m06_wvalid),
        .m06_axi_wready(m06_wready), .m06_axi_bid(m06_bid), .m06_axi_bresp(m06_bresp),
        .m06_axi_buser(1'b0), .m06_axi_bvalid(m06_bvalid), .m06_axi_bready(m06_bready),
        .m06_axi_arid(m06_arid), .m06_axi_araddr(m06_araddr), .m06_axi_arlen(m06_arlen),
        .m06_axi_arsize(m06_arsize), .m06_axi_arburst(m06_arburst), .m06_axi_arlock(m06_arlock),
        .m06_axi_arcache(m06_arcache), .m06_axi_arprot(m06_arprot), .m06_axi_arqos(m06_arqos),
        .m06_axi_arregion(m06_arregion), .m06_axi_aruser(), .m06_axi_arvalid(m06_arvalid),
        .m06_axi_arready(m06_arready), .m06_axi_rid(m06_rid), .m06_axi_rdata(m06_rdata),
        .m06_axi_rresp(m06_rresp), .m06_axi_rlast(m06_rlast), .m06_axi_ruser(1'b0),
        .m06_axi_rvalid(m06_rvalid), .m06_axi_rready(m06_rready),

        .m07_axi_awid(m07_awid), .m07_axi_awaddr(m07_awaddr), .m07_axi_awlen(m07_awlen),
        .m07_axi_awsize(m07_awsize), .m07_axi_awburst(m07_awburst), .m07_axi_awlock(m07_awlock),
        .m07_axi_awcache(m07_awcache), .m07_axi_awprot(m07_awprot), .m07_axi_awqos(m07_awqos),
        .m07_axi_awregion(m07_awregion), .m07_axi_awuser(), .m07_axi_awvalid(m07_awvalid),
        .m07_axi_awready(m07_awready), .m07_axi_wdata(m07_wdata), .m07_axi_wstrb(m07_wstrb),
        .m07_axi_wlast(m07_wlast), .m07_axi_wuser(), .m07_axi_wvalid(m07_wvalid),
        .m07_axi_wready(m07_wready), .m07_axi_bid(m07_bid), .m07_axi_bresp(m07_bresp),
        .m07_axi_buser(1'b0), .m07_axi_bvalid(m07_bvalid), .m07_axi_bready(m07_bready),
        .m07_axi_arid(m07_arid), .m07_axi_araddr(m07_araddr), .m07_axi_arlen(m07_arlen),
        .m07_axi_arsize(m07_arsize), .m07_axi_arburst(m07_arburst), .m07_axi_arlock(m07_arlock),
        .m07_axi_arcache(m07_arcache), .m07_axi_arprot(m07_arprot), .m07_axi_arqos(m07_arqos),
        .m07_axi_arregion(m07_arregion), .m07_axi_aruser(), .m07_axi_arvalid(m07_arvalid),
        .m07_axi_arready(m07_arready), .m07_axi_rid(m07_rid), .m07_axi_rdata(m07_rdata),
        .m07_axi_rresp(m07_rresp), .m07_axi_rlast(m07_rlast), .m07_axi_ruser(1'b0),
        .m07_axi_rvalid(m07_rvalid), .m07_axi_rready(m07_rready)
    );

    // =========================================================================
    // Slave Peripheral Instantiations
    // =========================================================================

    // m02: Real UART Instance
    axi_uart_top u_uart (
        .fixed_clk_i      (clk),
        .axi_aclk_i       (clk),
        .axi_aresetn_i    (rst_n),
        .axi_arid_i       ({4'b0, m02_arid}),
        .axi_araddr_i     (m02_araddr[4:0]),
        .axi_arvalid_i    (m02_arvalid),
        .axi_arready_o    (m02_arready),
        .axi_rid_o        (),
        .axi_rdata_o      (m02_rdata),
        .axi_rresp_o      (m02_rresp),
        .axi_rvalid_o     (m02_rvalid),
        .axi_rready_i     (m02_rready),
        .axi_awid_i       ({4'b0, m02_awid}),
        .axi_awaddr_i     (m02_awaddr[4:0]),
        .axi_awvalid_i    (m02_awvalid),
        .axi_awready_o    (m02_awready),
        .axi_wdata_i      (m02_wdata),
        .axi_wstrb_i      (m02_wstrb),
        .axi_wvalid_i     (m02_wvalid),
        .axi_wready_o     (m02_wready),
        .axi_bid_o        (),
        .axi_bresp_o      (m02_bresp),
        .axi_bvalid_o     (m02_bvalid),
        .axi_bready_i     (m02_bready),
        .read_interrupt_o (uart_irq_o),
        .uart_rx_i        (uart_tx_line), // Loopback
        .uart_tx_o        (uart_tx_line)
    );
    assign m02_rlast = 1'b1;
    assign m02_bid   = '0;

    // m05: Real CNN AXI Wrapper Instance
    cnn_axi_wrapper #(
        .DATA_WIDTH (DW),
        .ADDR_WIDTH (AW),
        .ID_WIDTH   (IDW)
    ) u_cnn (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axi_awid     (m05_awid),    .s_axi_awaddr   (m05_awaddr),
        .s_axi_awlen    (m05_awlen),   .s_axi_awsize   (m05_awsize),
        .s_axi_awburst  (m05_awburst), .s_axi_awvalid  (m05_awvalid),
        .s_axi_awready  (m05_awready),
        .s_axi_wdata    (m05_wdata),   .s_axi_wstrb    (m05_wstrb),
        .s_axi_wlast    (m05_wlast),   .s_axi_wvalid   (m05_wvalid),
        .s_axi_wready   (m05_wready),
        .s_axi_bid      (m05_bid),     .s_axi_bresp    (m05_bresp),
        .s_axi_bvalid   (m05_bvalid),  .s_axi_bready   (m05_bready),
        .s_axi_arid     (m05_arid),    .s_axi_araddr   (m05_araddr),
        .s_axi_arlen    (m05_arlen),   .s_axi_arsize   (m05_arsize),
        .s_axi_arburst  (m05_arburst), .s_axi_arvalid  (m05_arvalid),
        .s_axi_arready  (m05_arready),
        .s_axi_rid      (m05_rid),     .s_axi_rdata    (m05_rdata),
        .s_axi_rresp    (m05_rresp),   .s_axi_rlast    (m05_rlast),
        .s_axi_rvalid   (m05_rvalid),  .s_axi_rready   (m05_rready),
        .accel_done_irq (cnn_irq_o),
        .hw_embedding   (cnn_hw_embedding)
    );

    // m06: Real Distance/Similarity AXI Wrapper Instance
    distance_axi_wrapper #(
        .DATA_WIDTH (DW),
        .ADDR_WIDTH (AW),
        .ID_WIDTH   (IDW)
    ) u_dist (
        .clk                (clk),
        .rst_n              (rst_n),
        .s_axi_awid         (m06_awid),    .s_axi_awaddr   (m06_awaddr),
        .s_axi_awlen        (m06_awlen),   .s_axi_awsize   (m06_awsize),
        .s_axi_awburst      (m06_awburst), .s_axi_awvalid  (m06_awvalid),
        .s_axi_awready      (m06_awready),
        .s_axi_wdata        (m06_wdata),   .s_axi_wstrb    (m06_wstrb),
        .s_axi_wlast        (m06_wlast),   .s_axi_wvalid   (m06_wvalid),
        .s_axi_wready       (m06_wready),
        .s_axi_bid          (m06_bid),     .s_axi_bresp    (m06_bresp),
        .s_axi_bvalid       (m06_bvalid),  .s_axi_bready   (m06_bready),
        .s_axi_arid         (m06_arid),    .s_axi_araddr   (m06_araddr),
        .s_axi_arlen        (m06_arlen),   .s_axi_arsize   (m06_arsize),
        .s_axi_arburst      (m06_arburst), .s_axi_arvalid  (m06_arvalid),
        .s_axi_arready      (m06_arready),
        .s_axi_rid          (m06_rid),     .s_axi_rdata    (m06_rdata),
        .s_axi_rresp        (m06_rresp),   .s_axi_rlast    (m06_rlast),
        .s_axi_rvalid       (m06_rvalid),  .s_axi_rready   (m06_rready),
        .hw_query_embedding (cnn_hw_embedding),
        .score_done_irq     (dist_irq_o)
    );

    // m00: Real Dual-Port IMEM Instance (Port B connected to m00)
    imem_axi #(
        .DATA_WIDTH (DW),
        .ADDR_WIDTH (AW),
        .ID_WIDTH_A (IDW),
        .ID_WIDTH_B (IDW),
        .MEM_SIZE   (65536)
    ) u_imem (
        .clk            (clk),
        .rst_n          (rst_n),
        // Port A (Unused in LSU interconnect TB, tied off)
        .s_axi_a_awid   ('0),
        .s_axi_a_awaddr ('0),
        .s_axi_a_awlen  ('0),
        .s_axi_a_awsize ('0),
        .s_axi_a_awburst('0),
        .s_axi_a_awvalid(1'b0),
        .s_axi_a_awready(),
        .s_axi_a_wdata  ('0),
        .s_axi_a_wstrb  ('0),
        .s_axi_a_wlast  (1'b0),
        .s_axi_a_wvalid (1'b0),
        .s_axi_a_wready (),
        .s_axi_a_bid    (),
        .s_axi_a_bresp  (),
        .s_axi_a_bvalid (),
        .s_axi_a_bready (1'b1),
        .s_axi_a_arid   ('0),
        .s_axi_a_araddr ('0),
        .s_axi_a_arlen  ('0),
        .s_axi_a_arsize ('0),
        .s_axi_a_arburst('0),
        .s_axi_a_arvalid(1'b0),
        .s_axi_a_arready(),
        .s_axi_a_rid    (),
        .s_axi_a_rdata  (),
        .s_axi_a_rresp  (),
        .s_axi_a_rlast  (),
        .s_axi_a_rvalid (),
        .s_axi_a_rready (1'b1),
        // Port B (m00 from interconnect)
        .s_axi_b_awid   (m00_awid),
        .s_axi_b_awaddr (m00_awaddr),
        .s_axi_b_awlen  (m00_awlen),
        .s_axi_b_awsize (m00_awsize),
        .s_axi_b_awburst(m00_awburst),
        .s_axi_b_awvalid(m00_awvalid),
        .s_axi_b_awready(m00_awready),
        .s_axi_b_wdata  (m00_wdata),
        .s_axi_b_wstrb  (m00_wstrb),
        .s_axi_b_wlast  (m00_wlast),
        .s_axi_b_wvalid (m00_wvalid),
        .s_axi_b_wready (m00_wready),
        .s_axi_b_bid    (m00_bid),
        .s_axi_b_bresp  (m00_bresp),
        .s_axi_b_bvalid (m00_bvalid),
        .s_axi_b_bready (m00_bready),
        .s_axi_b_arid   (m00_arid),
        .s_axi_b_araddr (m00_araddr),
        .s_axi_b_arlen  (m00_arlen),
        .s_axi_b_arsize (m00_arsize),
        .s_axi_b_arburst(m00_arburst),
        .s_axi_b_arvalid(m00_arvalid),
        .s_axi_b_arready(m00_arready),
        .s_axi_b_rid    (m00_rid),
        .s_axi_b_rdata  (m00_rdata),
        .s_axi_b_rresp  (m00_rresp),
        .s_axi_b_rlast  (m00_rlast),
        .s_axi_b_rvalid (m00_rvalid),
        .s_axi_b_rready (m00_rready)
    );

    // m01: Real Single-Port DMEM Instance
    dmem_axi #(
        .DATA_WIDTH (DW),
        .ADDR_WIDTH (AW),
        .ID_WIDTH   (IDW),
        .MEM_SIZE   (65536)
    ) u_dmem (
        .clk          (clk),
        .rst_n        (rst_n),
        .s_axi_awid   (m01_awid),
        .s_axi_awaddr (m01_awaddr),
        .s_axi_awlen  (m01_awlen),
        .s_axi_awsize (m01_awsize),
        .s_axi_awburst(m01_awburst),
        .s_axi_awvalid(m01_awvalid),
        .s_axi_awready(m01_awready),
        .s_axi_wdata  (m01_wdata),
        .s_axi_wstrb  (m01_wstrb),
        .s_axi_wlast  (m01_wlast),
        .s_axi_wvalid (m01_wvalid),
        .s_axi_wready (m01_wready),
        .s_axi_bid    (m01_bid),
        .s_axi_bresp  (m01_bresp),
        .s_axi_bvalid (m01_bvalid),
        .s_axi_bready (m01_bready),
        .s_axi_arid   (m01_arid),
        .s_axi_araddr (m01_araddr),
        .s_axi_arlen  (m01_arlen),
        .s_axi_arsize (m01_arsize),
        .s_axi_arburst(m01_arburst),
        .s_axi_arvalid(m01_arvalid),
        .s_axi_arready(m01_arready),
        .s_axi_rid    (m01_rid),
        .s_axi_rdata  (m01_rdata),
        .s_axi_rresp  (m01_rresp),
        .s_axi_rlast  (m01_rlast),
        .s_axi_rvalid (m01_rvalid),
        .s_axi_rready (m01_rready)
    );

    // m03: Real RISC-V Timer (OpenTitan timer_core) AXI Wrapper Instance
    timer_axi_wrapper #(
        .DATA_WIDTH (DW),
        .ADDR_WIDTH (AW),
        .ID_WIDTH   (IDW)
    ) u_timer (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axi_awid     (m03_awid),    .s_axi_awaddr   (m03_awaddr),
        .s_axi_awlen    (m03_awlen),   .s_axi_awsize   (m03_awsize),
        .s_axi_awburst  (m03_awburst), .s_axi_awvalid  (m03_awvalid),
        .s_axi_awready  (m03_awready),
        .s_axi_wdata    (m03_wdata),   .s_axi_wstrb    (m03_wstrb),
        .s_axi_wlast    (m03_wlast),   .s_axi_wvalid   (m03_wvalid),
        .s_axi_wready   (m03_wready),
        .s_axi_bid      (m03_bid),     .s_axi_bresp    (m03_bresp),
        .s_axi_bvalid   (m03_bvalid),  .s_axi_bready   (m03_bready),
        .s_axi_arid     (m03_arid),    .s_axi_araddr   (m03_araddr),
        .s_axi_arlen    (m03_arlen),   .s_axi_arsize   (m03_arsize),
        .s_axi_arburst  (m03_arburst), .s_axi_arvalid  (m03_arvalid),
        .s_axi_arready  (m03_arready),
        .s_axi_rid      (m03_rid),     .s_axi_rdata    (m03_rdata),
        .s_axi_rresp    (m03_rresp),   .s_axi_rlast    (m03_rlast),
        .s_axi_rvalid   (m03_rvalid),  .s_axi_rready   (m03_rready),
        .timer_irq_o    (timer_irq_o)
    );

    // m04: Real PULP Platform GPIO AXI Wrapper Instance
    gpio_axi_wrapper #(
        .DATA_WIDTH (DW),
        .ADDR_WIDTH (AW),
        .STRB_WIDTH (SW),
        .ID_WIDTH   (IDW),
        .GPIO_COUNT (32)
    ) u_gpio (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .s_axi_awid             (m04_awid),    .s_axi_awaddr   (m04_awaddr),
        .s_axi_awlen            (m04_awlen),   .s_axi_awsize   (m04_awsize),
        .s_axi_awburst          (m04_awburst), .s_axi_awvalid  (m04_awvalid),
        .s_axi_awready          (m04_awready),
        .s_axi_wdata            (m04_wdata),   .s_axi_wstrb    (m04_wstrb),
        .s_axi_wlast            (m04_wlast),   .s_axi_wvalid   (m04_wvalid),
        .s_axi_wready           (m04_wready),
        .s_axi_bid              (m04_bid),     .s_axi_bresp    (m04_bresp),
        .s_axi_bvalid           (m04_bvalid),  .s_axi_bready   (m04_bready),
        .s_axi_arid             (m04_arid),    .s_axi_araddr   (m04_araddr),
        .s_axi_arlen            (m04_arlen),   .s_axi_arsize   (m04_arsize),
        .s_axi_arburst          (m04_arburst), .s_axi_arvalid  (m04_arvalid),
        .s_axi_arready          (m04_arready),
        .s_axi_rid              (m04_rid),     .s_axi_rdata    (m04_rdata),
        .s_axi_rresp            (m04_rresp),   .s_axi_rlast    (m04_rlast),
        .s_axi_rvalid           (m04_rvalid),  .s_axi_rready   (m04_rready),
        .gpio_i                 (gpio_i),
        .gpio_o                 (gpio_o),
        .gpio_dir_o             (gpio_dir_o),
        .gpio_in_sync_o         (gpio_in_sync_o),
        .gpio_irq_o             (gpio_irq_o),
        .gpio_pin_irq_o         (gpio_pin_irq_o)
    );

    axi_slave_stub #(.DATA_WIDTH(DW),.ADDR_WIDTH(AW),.ID_WIDTH(IDW)) u_dma_stub (
        .clk(clk),.rst_n(rst_n),
        .s_axi_awid(m07_awid),.s_axi_awaddr(m07_awaddr),.s_axi_awlen(m07_awlen),.s_axi_awsize(m07_awsize),
        .s_axi_awburst(m07_awburst),.s_axi_awvalid(m07_awvalid),.s_axi_awready(m07_awready),
        .s_axi_wdata(m07_wdata),.s_axi_wstrb(m07_wstrb),.s_axi_wlast(m07_wlast),.s_axi_wvalid(m07_wvalid),
        .s_axi_wready(m07_wready),.s_axi_bid(m07_bid),.s_axi_bresp(m07_bresp),.s_axi_bvalid(m07_bvalid),
        .s_axi_bready(m07_bready),.s_axi_arid(m07_arid),.s_axi_araddr(m07_araddr),.s_axi_arlen(m07_arlen),
        .s_axi_arsize(m07_arsize),.s_axi_arburst(m07_arburst),.s_axi_arvalid(m07_arvalid),.s_axi_arready(m07_arready),
        .s_axi_rid(m07_rid),.s_axi_rdata(m07_rdata),.s_axi_rresp(m07_rresp),.s_axi_rlast(m07_rlast),
        .s_axi_rvalid(m07_rvalid),.s_axi_rready(m07_rready)
    );

    // =========================================================================
    // Master Bus Tasks (Emulating VeeR CPU AXI transactions)
    // =========================================================================
    task automatic cpu_bus_write(
        input  logic [31:0] addr,
        input  logic [31:0] data,
        input  logic [3:0]  strb,
        output logic [1:0]  resp
    );
        int timeout;
        @(negedge clk);
        s00_awid    <= 8'h01;
        s00_awaddr  <= addr;
        s00_awlen   <= 8'd0;
        s00_awsize  <= 3'b010;
        s00_awburst <= 2'b01;
        s00_awlock  <= 1'b0;
        s00_awcache <= 4'b0;
        s00_awprot  <= 3'b0;
        s00_awqos   <= 4'b0;
        s00_awvalid <= 1'b1;

        s00_wdata   <= data;
        s00_wstrb   <= strb;
        s00_wlast   <= 1'b1;
        s00_wvalid  <= 1'b1;
        s00_bready  <= 1'b1;

        timeout = 0;
        fork
            begin
                while (!(s00_awvalid && s00_awready) && timeout < 200) begin
                    @(posedge clk); timeout++;
                end
                @(negedge clk); s00_awvalid <= 1'b0;
            end
            begin
                while (!(s00_wvalid && s00_wready) && timeout < 200) begin
                    @(posedge clk); timeout++;
                end
                @(negedge clk); s00_wvalid <= 1'b0;
            end
        join

        timeout = 0;
        while (!(s00_bvalid && s00_bready) && timeout < 200) begin
            @(posedge clk); timeout++;
        end
        resp = s00_bresp;
        @(negedge clk);
        s00_bready <= 1'b0;
    endtask

    task automatic cpu_bus_read(
        input  logic [31:0] addr,
        output logic [31:0] data,
        output logic [1:0]  resp
    );
        int timeout;
        @(negedge clk);
        s00_arid    <= 8'h02;
        s00_araddr  <= addr;
        s00_arlen   <= 8'd0;
        s00_arsize  <= 3'b010;
        s00_arburst <= 2'b01;
        s00_arlock  <= 1'b0;
        s00_arcache <= 4'b0;
        s00_arprot  <= 3'b0;
        s00_arqos   <= 4'b0;
        s00_arvalid <= 1'b1;
        s00_rready  <= 1'b1;

        timeout = 0;
        while (!(s00_arvalid && s00_arready) && timeout < 200) begin
            @(posedge clk); timeout++;
        end
        @(negedge clk); s00_arvalid <= 1'b0;

        timeout = 0;
        while (!(s00_rvalid && s00_rready) && timeout < 200) begin
            @(posedge clk); timeout++;
        end
        data = s00_rdata;
        resp = s00_rresp;
        @(negedge clk);
        s00_rready <= 1'b0;
    endtask

    int pass_count = 0;
    int fail_count = 0;

    task check(input string desc, input logic condition);
        if (condition) begin
            $display("[PASS] %s", desc);
            pass_count++;
        end else begin
            $display("[FAIL] %s", desc);
            fail_count++;
        end
    endtask

    // =========================================================================
    // Test Sequence
    // =========================================================================
    logic [31:0] rdata;
    logic [1:0]  resp;

    initial begin
        rst         = 1'b1;
        s00_awvalid = 1'b0;
        s00_wvalid  = 1'b0;
        s00_bready  = 1'b0;
        s00_arvalid = 1'b0;
        s00_rready  = 1'b0;

        #40;
        rst = 1'b0;
        #20;

        $display("=================================================================");
        $display("  STARTING END-TO-END SOC AXI INTEGRATION REGRESSION");
        $display("=================================================================");

        // --- TEST 1: Preserve Verified UART on m02 (0x2000_0000) ---
        $display("\n[TEST 1] Preserve Verified CPU -> AXI -> UART Path (m02 @ 0x2000_0000)");
        // Configure UART divisor with DLAB protocol:
        // LCR (offset 0x0C) = 0x80 (set DLAB)
        cpu_bus_write(32'h2000_000C, 32'h80, 4'hF, resp);
        check("UART DLAB bit write OKAY", resp == 2'b00);

        // DLL (offset 0x00) = 64
        cpu_bus_write(32'h2000_0000, 32'd64, 4'hF, resp);
        // DLM (offset 0x04) = 0
        cpu_bus_write(32'h2000_0004, 32'd0, 4'hF, resp);

        // LCR = 0x00 (clear DLAB, 8N1)
        cpu_bus_write(32'h2000_000C, 32'h00, 4'hF, resp);

        // Read LSR (offset 0x14) -> should be 0x60 (TEMT=1, THRE=1)
        cpu_bus_read(32'h2000_0014, rdata, resp);
        check("UART LSR readback through interconnect is 0x60", (resp == 2'b00 && rdata[6:5] == 2'b11));

        // --- TEST 2: CPU -> AXI -> CNN Accelerator (m05 @ 0x2000_3000) ---
        $display("\n[TEST 2] CPU -> AXI -> CNN Accelerator Integration (m05 @ 0x2000_3000)");
        // Read default CNN status
        cpu_bus_read(32'h2000_3004, rdata, resp);
        check("CNN initial STATUS is 0 via interconnect", (resp == 2'b00 && rdata == 32'h0));

        // Configure CNN base addresses
        cpu_bus_write(32'h2000_3008, 32'h1000_0000, 4'hF, resp); // IMAGE_BASE
        cpu_bus_write(32'h2000_300C, 32'h1000_1000, 4'hF, resp); // WEIGHT_BASE
        cpu_bus_write(32'h2000_3010, 32'h1000_2000, 4'hF, resp); // EMBED_BASE
        cpu_bus_write(32'h2000_3014, 32'h0010_0010, 4'hF, resp); // DIM_CFG
        cpu_bus_write(32'h2000_3018, 32'd16, 4'hF, resp);        // EMBED_LEN

        // Start CNN inference with IRQ enabled (CTRL = 0x05)
        cpu_bus_write(32'h2000_3000, 32'h05, 4'hF, resp);
        check("CNN START command accepted via interconnect", resp == 2'b00);

        // Verify BUSY status
        cpu_bus_read(32'h2000_3004, rdata, resp);
        check("CNN STATUS reports BUSY=1 during inference", (resp == 2'b00 && rdata[0] == 1'b1));

        $display("Polling CNN DONE status over AXI...");
        while (1) begin
            cpu_bus_read(32'h2000_3004, rdata, resp);
            if (rdata[1] == 1'b1) break; // DONE
            #500;
        end
        check("CNN inference completes: DONE=1, BUSY=0", (rdata[1] == 1'b1 && rdata[0] == 1'b0));
        check("Dedicated cnn_irq_o interrupt pin asserted", cnn_irq_o == 1'b1);

        // Read CNN embedding results over AXI
        $display("Reading 16-element embedding from CNN IP over AXI...");
        for (int k = 0; k < 16; k++) begin
            cpu_bus_read(32'h2000_3020 + (k*4), rdata, resp);
            check($sformatf("CNN Embedding[%0d] == 1764", k), (resp == 2'b00 && rdata == 32'd1764));
        end

        // --- TEST 3: CPU -> AXI -> Distance IP (m06 @ 0x2000_4000) MATCH Test ---
        $display("\n[TEST 3] CPU -> AXI -> Distance Engine MATCH Classification (m06 @ 0x2000_4000)");
        // Write reference embedding identical to CNN output (1764)
        for (int k = 0; k < 16; k++) begin
            cpu_bus_write(32'h2000_4200 + (k*4), 32'd1764, 4'hF, resp);
        end
        // Set threshold = 50
        cpu_bus_write(32'h2000_4018, 32'd50, 4'hF, resp);
        // Start Distance IP with IRQ enabled (CTRL = 0x05)
        cpu_bus_write(32'h2000_4000, 32'h05, 4'hF, resp);

        // Poll Distance IP DONE
        while (1) begin
            cpu_bus_read(32'h2000_4004, rdata, resp);
            if (rdata[1] == 1'b1) break;
            #10;
        end
        check("Distance engine DONE=1 via interconnect", rdata[1] == 1'b1);
        check("Dedicated dist_irq_o interrupt pin asserted", dist_irq_o == 1'b1);

        // Read Distance & Classification Result
        cpu_bus_read(32'h2000_4020, rdata, resp); // MIN_DISTANCE
        check("MIN_DISTANCE == 0 for matching CNN embedding", (resp == 2'b00 && rdata == 32'd0));

        cpu_bus_read(32'h2000_401C, rdata, resp); // RESULT
        check("RESULT == 1 (MATCH) since distance (0) <= threshold (50)", (resp == 2'b00 && rdata == 32'd1));

        // --- TEST 4: Distance IP ANOMALY Classification ---
        $display("\n[TEST 4] CPU -> AXI -> Distance Engine ANOMALY Classification (m06 @ 0x2000_4000)");
        // Write reference embedding with substantial difference (1764 - 50 = 1714)
        // Difference per element = 50 -> Manhattan distance = 16 * 50 = 800
        for (int k = 0; k < 16; k++) begin
            cpu_bus_write(32'h2000_4200 + (k*4), 32'd1714, 4'hF, resp);
        end
        // Threshold remains 50
        cpu_bus_write(32'h2000_4000, 32'h01, 4'hF, resp); // DIST_START

        while (1) begin
            cpu_bus_read(32'h2000_4004, rdata, resp);
            if (rdata[1] == 1'b1) break;
            #10;
        end

        cpu_bus_read(32'h2000_4020, rdata, resp); // MIN_DISTANCE
        check("MIN_DISTANCE == 800 (16 * 50)", (resp == 2'b00 && rdata == 32'd800));

        cpu_bus_read(32'h2000_401C, rdata, resp); // RESULT
        check("RESULT == 0 (ANOMALY) since distance (800) > threshold (50)", (resp == 2'b00 && rdata == 32'd0));

        // --- TEST 5: CPU -> AXI -> RISC-V Timer IP (m03 @ 0x2000_1000) ---
        $display("\n[TEST 5] CPU -> AXI -> RISC-V Timer (OpenTitan timer_core) Integration (m03 @ 0x2000_1000)");
        // Read default timer config
        cpu_bus_read(32'h2000_1010, rdata, resp); // CFG
        check("Timer initial CFG read OKAY via interconnect", (resp == 2'b00 && rdata[23:16] == 8'd1));

        // Configure step=1, prescale=0
        cpu_bus_write(32'h2000_1010, {8'h0, 8'd1, 4'h0, 12'd0}, 4'hF, resp);
        check("Timer CFG write accepted via interconnect", resp == 2'b00);

        // Reset counter to 0, set compare threshold = 20
        cpu_bus_write(32'h2000_1014, 32'd0, 4'hF, resp);  // MTIME_LOW = 0
        cpu_bus_write(32'h2000_1018, 32'd0, 4'hF, resp);  // MTIME_HIGH = 0
        cpu_bus_write(32'h2000_101C, 32'd20, 4'hF, resp); // MTIMECMP_LOW = 20
        cpu_bus_write(32'h2000_1020, 32'd0, 4'hF, resp);  // MTIMECMP_HIGH = 0

        // Enable interrupt (INTR_ENABLE = 1)
        cpu_bus_write(32'h2000_1008, 32'd1, 4'hF, resp);

        // Start timer (CTRL = 1)
        cpu_bus_write(32'h2000_1000, 32'd1, 4'hF, resp);
        check("Timer START command accepted via interconnect", resp == 2'b00);

        // Wait for counter to reach threshold (20 cycles * 10ns = 200ns)
        #300;
        check("Dedicated timer_irq_o interrupt pin asserted", timer_irq_o == 1'b1);

        cpu_bus_read(32'h2000_100C, rdata, resp); // INTR_STATE
        check("Timer INTR_STATE reports interrupt active (IS=1)", (resp == 2'b00 && rdata[0] == 1'b1));

        cpu_bus_read(32'h2000_1014, rdata, resp); // MTIME_LOW
        check("Timer MTIME_LOW counter incremented (> 20)", (resp == 2'b00 && rdata >= 32'd20));

        // Clear interrupt: advance compare and write 1 to INTR_STATE
        cpu_bus_write(32'h2000_101C, 32'hFFFF_FFFF, 4'hF, resp);
        cpu_bus_write(32'h2000_100C, 32'd1, 4'hF, resp); // W1C
        #20;
        check("Dedicated timer_irq_o interrupt deasserted after clear", timer_irq_o == 1'b0);

        // --- TEST 6: CPU -> AXI -> PULP Platform GPIO (m04 @ 0x2000_2000) ---
        $display("\n[TEST 6] CPU -> AXI -> GPIO (PULP Platform) Integration (m04 @ 0x2000_2000)");
        // Read INFO register
        cpu_bus_read(32'h2000_2000, rdata, resp);
        check("GPIO INFO read OKAY via interconnect (GPIOCount=32, Version=2)", (resp == 2'b00 && rdata == 32'h0000_0820));

        // Configure CFG (glbl_intrpt_mode=1, pin_lvl_intrpt_mode=1)
        cpu_bus_write(32'h2000_2004, 32'h0000_0003, 4'hF, resp);
        check("GPIO CFG write accepted via interconnect", resp == 2'b00);

        // Configure pins [3:0] as push-pull output (2'b01 per pin -> 0x55)
        cpu_bus_write(32'h2000_2008, 32'h0000_0055, 4'hF, resp);
        check("GPIO_MODE_0 write accepted via interconnect", resp == 2'b00);

        // Drive GPIO_OUT with 0x0A
        cpu_bus_write(32'h2000_2180, 32'h0000_000A, 4'hF, resp);
        #10;
        check("gpio_o[3:0] driven to 0xA via interconnect", gpio_o[3:0] == 4'hA);

        // Atomic SET with 0x05 -> 0x0A | 0x05 = 0x0F
        cpu_bus_write(32'h2000_2200, 32'h0000_0005, 4'hF, resp);
        #10;
        check("Atomic SET updates gpio_o[3:0] to 0xF via interconnect", gpio_o[3:0] == 4'hF);

        // Enable input sampling & rising-edge interrupt for pin 4
        cpu_bus_write(32'h2000_2080, 32'h0000_0010, 4'hF, resp);
        cpu_bus_write(32'h2000_2380, 32'h0000_0010, 4'hF, resp);

        // Stimulate input edge on pin 4
        gpio_i[4] = 1'b0;
        #30;
        gpio_i[4] = 1'b1;
        #60;
        check("Dedicated gpio_irq_o interrupt pin asserted", gpio_irq_o == 1'b1);

        // Query INTRPT_STATUS
        cpu_bus_read(32'h2000_2580, rdata, resp);
        check("GPIO INTRPT_STATUS reports pending interrupt (bit 4 = 1)", (resp == 2'b00 && (rdata & 32'h10) != 0));

        // Clear interrupt via W1C
        cpu_bus_write(32'h2000_2580, 32'h0000_0010, 4'hF, resp);
        #20;
        check("Dedicated gpio_irq_o interrupt deasserted after clear", gpio_irq_o == 1'b0);

        // --- TEST 7: Interconnect DECERR on Unmapped Address ---
        $display("\n[TEST 7] Interconnect Address Decoding: Unmapped Address (0x3000_0000)");
        cpu_bus_read(32'h3000_0000, rdata, resp);
        check("Interconnect returns DECERR (2'b11) on unmapped access", resp == 2'b11);

        // --- TEST 8: IMEM Access via Interconnect m00 (0x0000_0000 - 0x0000_FFFF) ---
        $display("\n[TEST 8] IMEM Access via Interconnect m00 (0x0000_0000)");
        cpu_bus_write(32'h0000_0000, 32'h0000_0013, 4'hF, resp);
        check("IMEM write @ 0x0000_0000 returns OKAY (2'b00)", resp == 2'b00);
        cpu_bus_read(32'h0000_0000, rdata, resp);
        check("IMEM read @ 0x0000_0000 matches 0x00000013 (NOP)", resp == 2'b00 && rdata == 32'h0000_0013);

        cpu_bus_write(32'h0000_0004, 32'h0010_0093, 4'hF, resp);
        check("IMEM write @ 0x0000_0004 returns OKAY (2'b00)", resp == 2'b00);
        cpu_bus_read(32'h0000_0004, rdata, resp);
        check("IMEM read @ 0x0000_0004 matches 0x00100093", resp == 2'b00 && rdata == 32'h0010_0093);

        // --- TEST 9: DMEM Access via Interconnect m01 (0x1000_0000 - 0x1000_FFFF) ---
        $display("\n[TEST 9] DMEM Access via Interconnect m01 (0x1000_0000)");
        cpu_bus_write(32'h1000_0000, 32'hDEAD_BEEF, 4'hF, resp);
        check("DMEM write @ 0x1000_0000 returns OKAY (2'b00)", resp == 2'b00);
        cpu_bus_read(32'h1000_0000, rdata, resp);
        check("DMEM read @ 0x1000_0000 matches 0xDEADBEEF", resp == 2'b00 && rdata == 32'hDEAD_BEEF);

        // Byte strobe test on DMEM (modify byte 1 only)
        cpu_bus_write(32'h1000_0000, 32'h0000_5500, 4'b0010, resp);
        check("DMEM byte 1 write returns OKAY (2'b00)", resp == 2'b00);
        cpu_bus_read(32'h1000_0000, rdata, resp);
        check("DMEM read after byte strobe matches 0xDEAD55EF", resp == 2'b00 && rdata == 32'hDEAD_55EF);

        // Top of DMEM (0x1000_FFFC)
        cpu_bus_write(32'h1000_FFFC, 32'hFEED_FACE, 4'hF, resp);
        check("DMEM write @ Top 0x1000_FFFC returns OKAY (2'b00)", resp == 2'b00);
        cpu_bus_read(32'h1000_FFFC, rdata, resp);
        check("DMEM read @ Top 0x1000_FFFC matches 0xFEEDFACE", resp == 2'b00 && rdata == 32'hFEED_FACE);

        // =====================================================================
        // Summary
        // =====================================================================
        $display("\n=================================================================");
        $display("  SOC AXI INTEGRATION REGRESSION RESULTS");
        $display("  PASS: %0d   FAIL: %0d   TOTAL: %0d", pass_count, fail_count, pass_count + fail_count);
        $display("=================================================================");

        if (fail_count == 0)
            $display("OVERALL: ALL SOC AXI INTEGRATION TESTS PASSED!\n");
        else
            $display("OVERALL: SOME TESTS FAILED!\n");

        #50;
        $finish;
    end

    // Safety watchdog
    initial begin
        #500_000_000;
        $display("\n[ERROR] Simulation watchdog timeout!");
        $finish;
    end

endmodule

`ifndef AXI_SLAVE_STUB_DEFINED
`define AXI_SLAVE_STUB_DEFINED
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
    logic aw_seen, w_seen;
    logic [ID_WIDTH-1:0] wr_id;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_seen      <= 1'b0;
            w_seen       <= 1'b0;
            wr_id        <= '0;
            s_axi_bvalid <= 1'b0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin
                aw_seen <= 1'b1;
                wr_id   <= s_axi_awid;
            end
            if (s_axi_wvalid && s_axi_wready && s_axi_wlast)
                w_seen <= 1'b1;
            if ((aw_seen || (s_axi_awvalid && s_axi_awready)) &&
                (w_seen  || (s_axi_wvalid  && s_axi_wready && s_axi_wlast))) begin
                s_axi_bvalid <= 1'b1;
                if (s_axi_bvalid && s_axi_bready) begin
                    s_axi_bvalid <= 1'b0;
                    aw_seen      <= 1'b0;
                    w_seen       <= 1'b0;
                end
            end
            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
                aw_seen      <= 1'b0;
                w_seen       <= 1'b0;
            end
        end
    end

    assign s_axi_awready = 1'b1;
    assign s_axi_wready  = 1'b1;
    assign s_axi_bid     = wr_id;
    assign s_axi_bresp   = 2'b00; // OKAY

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
`endif
