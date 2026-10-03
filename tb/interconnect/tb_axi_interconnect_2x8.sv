// =============================================================================
// tb/tb_axi_interconnect_2x8.sv
//
// Self-checking testbench for axi_interconnect_wrap_2x8 (2-master × 8-slave)
//
// Masters (AXI slaves on the wrapper):
//   s00 = CPU / RISC-V
//   s01 = DMA
//
// Slaves (AXI masters on the wrapper):
//   m00 = IMEM       0x0000_0000  width 16
//   m01 = DMEM       0x1000_0000  width 16
//   m02 = UART       0x2000_0000  width 12
//   m03 = Timer      0x2000_1000  width 12
//   m04 = GPIO       0x2000_2000  width 12
//   m05 = CNN        0x2000_3000  width 12
//   m06 = Distance   0x2000_4000  width 12
//   m07 = DMA Regs   0x2000_5000  width 12
// =============================================================================

`timescale 1ns/1ps

module tb_axi_interconnect_2x8;

// ---------------------------------------------------------------------------
// Parameters matching DUT defaults
// ---------------------------------------------------------------------------
localparam DW  = 32;
localparam AW  = 32;
localparam SW  = DW/8;
localparam IDW = 8;

// ---------------------------------------------------------------------------
// Clock / reset
// ---------------------------------------------------------------------------
reg clk = 0;
reg rst = 1;
always #5 clk = ~clk;     // 100 MHz

// ---------------------------------------------------------------------------
// CPU master (s00) – driven by TB
// ---------------------------------------------------------------------------
reg  [IDW-1:0] s00_axi_awid    = 0;
reg  [AW-1:0]  s00_axi_awaddr  = 0;
reg  [7:0]     s00_axi_awlen   = 0;
reg  [2:0]     s00_axi_awsize  = 3'b010;  // 4-byte beats
reg  [1:0]     s00_axi_awburst = 2'b01;   // INCR
reg            s00_axi_awlock  = 0;
reg  [3:0]     s00_axi_awcache = 0;
reg  [2:0]     s00_axi_awprot  = 0;
reg  [3:0]     s00_axi_awqos   = 0;
reg  [0:0]     s00_axi_awuser  = 0;
reg            s00_axi_awvalid = 0;
wire           s00_axi_awready;

reg  [DW-1:0]  s00_axi_wdata   = 0;
reg  [SW-1:0]  s00_axi_wstrb   = 4'hF;
reg            s00_axi_wlast   = 1;
reg  [0:0]     s00_axi_wuser   = 0;
reg            s00_axi_wvalid  = 0;
wire           s00_axi_wready;

wire [IDW-1:0] s00_axi_bid;
wire [1:0]     s00_axi_bresp;
wire [0:0]     s00_axi_buser;
wire           s00_axi_bvalid;
reg            s00_axi_bready  = 1;

reg  [IDW-1:0] s00_axi_arid    = 0;
reg  [AW-1:0]  s00_axi_araddr  = 0;
reg  [7:0]     s00_axi_arlen   = 0;
reg  [2:0]     s00_axi_arsize  = 3'b010;
reg  [1:0]     s00_axi_arburst = 2'b01;
reg            s00_axi_arlock  = 0;
reg  [3:0]     s00_axi_arcache = 0;
reg  [2:0]     s00_axi_arprot  = 0;
reg  [3:0]     s00_axi_arqos   = 0;
reg  [0:0]     s00_axi_aruser  = 0;
reg            s00_axi_arvalid = 0;
wire           s00_axi_arready;

wire [IDW-1:0] s00_axi_rid;
wire [DW-1:0]  s00_axi_rdata;
wire [1:0]     s00_axi_rresp;
wire           s00_axi_rlast;
wire [0:0]     s00_axi_ruser;
wire           s00_axi_rvalid;
reg            s00_axi_rready  = 1;

// ---------------------------------------------------------------------------
// DMA master (s01) – driven by TB
// ---------------------------------------------------------------------------
reg  [IDW-1:0] s01_axi_awid    = 8'h10;
reg  [AW-1:0]  s01_axi_awaddr  = 0;
reg  [7:0]     s01_axi_awlen   = 0;
reg  [2:0]     s01_axi_awsize  = 3'b010;
reg  [1:0]     s01_axi_awburst = 2'b01;
reg            s01_axi_awlock  = 0;
reg  [3:0]     s01_axi_awcache = 0;
reg  [2:0]     s01_axi_awprot  = 0;
reg  [3:0]     s01_axi_awqos   = 0;
reg  [0:0]     s01_axi_awuser  = 0;
reg            s01_axi_awvalid = 0;
wire           s01_axi_awready;

reg  [DW-1:0]  s01_axi_wdata   = 32'hDEAD_BEEF;
reg  [SW-1:0]  s01_axi_wstrb   = 4'hF;
reg            s01_axi_wlast   = 1;
reg  [0:0]     s01_axi_wuser   = 0;
reg            s01_axi_wvalid  = 0;
wire           s01_axi_wready;

wire [IDW-1:0] s01_axi_bid;
wire [1:0]     s01_axi_bresp;
wire [0:0]     s01_axi_buser;
wire           s01_axi_bvalid;
reg            s01_axi_bready  = 1;

reg  [IDW-1:0] s01_axi_arid    = 8'h10;
reg  [AW-1:0]  s01_axi_araddr  = 0;
reg  [7:0]     s01_axi_arlen   = 0;
reg  [2:0]     s01_axi_arsize  = 3'b010;
reg  [1:0]     s01_axi_arburst = 2'b01;
reg            s01_axi_arlock  = 0;
reg  [3:0]     s01_axi_arcache = 0;
reg  [2:0]     s01_axi_arprot  = 0;
reg  [3:0]     s01_axi_arqos   = 0;
reg  [0:0]     s01_axi_aruser  = 0;
reg            s01_axi_arvalid = 0;
wire           s01_axi_arready;

wire [IDW-1:0] s01_axi_rid;
wire [DW-1:0]  s01_axi_rdata;
wire [1:0]     s01_axi_rresp;
wire           s01_axi_rlast;
wire [0:0]     s01_axi_ruser;
wire           s01_axi_rvalid;
reg            s01_axi_rready  = 1;

// ---------------------------------------------------------------------------
// 8 slave memory models – each slave drives awready/wready/bvalid/arready/rvalid
// ---------------------------------------------------------------------------

// --- m00 IMEM ---
wire [IDW-1:0] m00_axi_awid;    wire [AW-1:0] m00_axi_awaddr;
wire [7:0]     m00_axi_awlen;   wire [2:0]    m00_axi_awsize;
wire [1:0]     m00_axi_awburst; wire          m00_axi_awlock;
wire [3:0]     m00_axi_awcache; wire [2:0]    m00_axi_awprot;
wire [3:0]     m00_axi_awqos;   wire [3:0]    m00_axi_awregion;
wire [0:0]     m00_axi_awuser;  wire          m00_axi_awvalid;
reg            m00_axi_awready = 1;
wire [DW-1:0]  m00_axi_wdata;   wire [SW-1:0] m00_axi_wstrb;
wire           m00_axi_wlast;   wire [0:0]    m00_axi_wuser;
wire           m00_axi_wvalid;
reg            m00_axi_wready  = 1;
reg  [IDW-1:0] m00_axi_bid     = 0;
reg  [1:0]     m00_axi_bresp   = 0;
reg  [0:0]     m00_axi_buser   = 0;
reg            m00_axi_bvalid  = 0;
wire           m00_axi_bready;
wire [IDW-1:0] m00_axi_arid;    wire [AW-1:0] m00_axi_araddr;
wire [7:0]     m00_axi_arlen;   wire [2:0]    m00_axi_arsize;
wire [1:0]     m00_axi_arburst; wire          m00_axi_arlock;
wire [3:0]     m00_axi_arcache; wire [2:0]    m00_axi_arprot;
wire [3:0]     m00_axi_arqos;   wire [3:0]    m00_axi_arregion;
wire [0:0]     m00_axi_aruser;  wire          m00_axi_arvalid;
reg            m00_axi_arready = 1;
reg  [IDW-1:0] m00_axi_rid     = 0;
reg  [DW-1:0]  m00_axi_rdata   = 32'hAAAA_0000;
reg  [1:0]     m00_axi_rresp   = 0;
reg            m00_axi_rlast   = 1;
reg  [0:0]     m00_axi_ruser   = 0;
reg            m00_axi_rvalid  = 0;
wire           m00_axi_rready;

// --- m01 DMEM ---
wire [IDW-1:0] m01_axi_awid;    wire [AW-1:0] m01_axi_awaddr;
wire [7:0]     m01_axi_awlen;   wire [2:0]    m01_axi_awsize;
wire [1:0]     m01_axi_awburst; wire          m01_axi_awlock;
wire [3:0]     m01_axi_awcache; wire [2:0]    m01_axi_awprot;
wire [3:0]     m01_axi_awqos;   wire [3:0]    m01_axi_awregion;
wire [0:0]     m01_axi_awuser;  wire          m01_axi_awvalid;
reg            m01_axi_awready = 1;
wire [DW-1:0]  m01_axi_wdata;   wire [SW-1:0] m01_axi_wstrb;
wire           m01_axi_wlast;   wire [0:0]    m01_axi_wuser;
wire           m01_axi_wvalid;
reg            m01_axi_wready  = 1;
reg  [IDW-1:0] m01_axi_bid     = 0;
reg  [1:0]     m01_axi_bresp   = 0;
reg  [0:0]     m01_axi_buser   = 0;
reg            m01_axi_bvalid  = 0;
wire           m01_axi_bready;
wire [IDW-1:0] m01_axi_arid;    wire [AW-1:0] m01_axi_araddr;
wire [7:0]     m01_axi_arlen;   wire [2:0]    m01_axi_arsize;
wire [1:0]     m01_axi_arburst; wire          m01_axi_arlock;
wire [3:0]     m01_axi_arcache; wire [2:0]    m01_axi_arprot;
wire [3:0]     m01_axi_arqos;   wire [3:0]    m01_axi_arregion;
wire [0:0]     m01_axi_aruser;  wire          m01_axi_arvalid;
reg            m01_axi_arready = 1;
reg  [IDW-1:0] m01_axi_rid     = 0;
reg  [DW-1:0]  m01_axi_rdata   = 32'hBBBB_0001;
reg  [1:0]     m01_axi_rresp   = 0;
reg            m01_axi_rlast   = 1;
reg  [0:0]     m01_axi_ruser   = 0;
reg            m01_axi_rvalid  = 0;
wire           m01_axi_rready;

// --- m02 UART ---
wire [IDW-1:0] m02_axi_awid;    wire [AW-1:0] m02_axi_awaddr;
wire [7:0]     m02_axi_awlen;   wire [2:0]    m02_axi_awsize;
wire [1:0]     m02_axi_awburst; wire          m02_axi_awlock;
wire [3:0]     m02_axi_awcache; wire [2:0]    m02_axi_awprot;
wire [3:0]     m02_axi_awqos;   wire [3:0]    m02_axi_awregion;
wire [0:0]     m02_axi_awuser;  wire          m02_axi_awvalid;
reg            m02_axi_awready = 1;
wire [DW-1:0]  m02_axi_wdata;   wire [SW-1:0] m02_axi_wstrb;
wire           m02_axi_wlast;   wire [0:0]    m02_axi_wuser;
wire           m02_axi_wvalid;
reg            m02_axi_wready  = 1;
reg  [IDW-1:0] m02_axi_bid     = 0;
reg  [1:0]     m02_axi_bresp   = 0;
reg  [0:0]     m02_axi_buser   = 0;
reg            m02_axi_bvalid  = 0;
wire           m02_axi_bready;
wire [IDW-1:0] m02_axi_arid;    wire [AW-1:0] m02_axi_araddr;
wire [7:0]     m02_axi_arlen;   wire [2:0]    m02_axi_arsize;
wire [1:0]     m02_axi_arburst; wire          m02_axi_arlock;
wire [3:0]     m02_axi_arcache; wire [2:0]    m02_axi_arprot;
wire [3:0]     m02_axi_arqos;   wire [3:0]    m02_axi_arregion;
wire [0:0]     m02_axi_aruser;  wire          m02_axi_arvalid;
reg            m02_axi_arready = 1;
reg  [IDW-1:0] m02_axi_rid     = 0;
reg  [DW-1:0]  m02_axi_rdata   = 32'hCCCC_0002;
reg  [1:0]     m02_axi_rresp   = 0;
reg            m02_axi_rlast   = 1;
reg  [0:0]     m02_axi_ruser   = 0;
reg            m02_axi_rvalid  = 0;
wire           m02_axi_rready;

// --- m03 Timer ---
wire [IDW-1:0] m03_axi_awid;    wire [AW-1:0] m03_axi_awaddr;
wire [7:0]     m03_axi_awlen;   wire [2:0]    m03_axi_awsize;
wire [1:0]     m03_axi_awburst; wire          m03_axi_awlock;
wire [3:0]     m03_axi_awcache; wire [2:0]    m03_axi_awprot;
wire [3:0]     m03_axi_awqos;   wire [3:0]    m03_axi_awregion;
wire [0:0]     m03_axi_awuser;  wire          m03_axi_awvalid;
reg            m03_axi_awready = 1;
wire [DW-1:0]  m03_axi_wdata;   wire [SW-1:0] m03_axi_wstrb;
wire           m03_axi_wlast;   wire [0:0]    m03_axi_wuser;
wire           m03_axi_wvalid;
reg            m03_axi_wready  = 1;
reg  [IDW-1:0] m03_axi_bid     = 0;
reg  [1:0]     m03_axi_bresp   = 0;
reg  [0:0]     m03_axi_buser   = 0;
reg            m03_axi_bvalid  = 0;
wire           m03_axi_bready;
wire [IDW-1:0] m03_axi_arid;    wire [AW-1:0] m03_axi_araddr;
wire [7:0]     m03_axi_arlen;   wire [2:0]    m03_axi_arsize;
wire [1:0]     m03_axi_arburst; wire          m03_axi_arlock;
wire [3:0]     m03_axi_arcache; wire [2:0]    m03_axi_arprot;
wire [3:0]     m03_axi_arqos;   wire [3:0]    m03_axi_arregion;
wire [0:0]     m03_axi_aruser;  wire          m03_axi_arvalid;
reg            m03_axi_arready = 1;
reg  [IDW-1:0] m03_axi_rid     = 0;
reg  [DW-1:0]  m03_axi_rdata   = 32'hDDDD_0003;
reg  [1:0]     m03_axi_rresp   = 0;
reg            m03_axi_rlast   = 1;
reg  [0:0]     m03_axi_ruser   = 0;
reg            m03_axi_rvalid  = 0;
wire           m03_axi_rready;

// --- m04 GPIO ---
wire [IDW-1:0] m04_axi_awid;    wire [AW-1:0] m04_axi_awaddr;
wire [7:0]     m04_axi_awlen;   wire [2:0]    m04_axi_awsize;
wire [1:0]     m04_axi_awburst; wire          m04_axi_awlock;
wire [3:0]     m04_axi_awcache; wire [2:0]    m04_axi_awprot;
wire [3:0]     m04_axi_awqos;   wire [3:0]    m04_axi_awregion;
wire [0:0]     m04_axi_awuser;  wire          m04_axi_awvalid;
reg            m04_axi_awready = 1;
wire [DW-1:0]  m04_axi_wdata;   wire [SW-1:0] m04_axi_wstrb;
wire           m04_axi_wlast;   wire [0:0]    m04_axi_wuser;
wire           m04_axi_wvalid;
reg            m04_axi_wready  = 1;
reg  [IDW-1:0] m04_axi_bid     = 0;
reg  [1:0]     m04_axi_bresp   = 0;
reg  [0:0]     m04_axi_buser   = 0;
reg            m04_axi_bvalid  = 0;
wire           m04_axi_bready;
wire [IDW-1:0] m04_axi_arid;    wire [AW-1:0] m04_axi_araddr;
wire [7:0]     m04_axi_arlen;   wire [2:0]    m04_axi_arsize;
wire [1:0]     m04_axi_arburst; wire          m04_axi_arlock;
wire [3:0]     m04_axi_arcache; wire [2:0]    m04_axi_arprot;
wire [3:0]     m04_axi_arqos;   wire [3:0]    m04_axi_arregion;
wire [0:0]     m04_axi_aruser;  wire          m04_axi_arvalid;
reg            m04_axi_arready = 1;
reg  [IDW-1:0] m04_axi_rid     = 0;
reg  [DW-1:0]  m04_axi_rdata   = 32'hEEEE_0004;
reg  [1:0]     m04_axi_rresp   = 0;
reg            m04_axi_rlast   = 1;
reg  [0:0]     m04_axi_ruser   = 0;
reg            m04_axi_rvalid  = 0;
wire           m04_axi_rready;

// --- m05 CNN ---
wire [IDW-1:0] m05_axi_awid;    wire [AW-1:0] m05_axi_awaddr;
wire [7:0]     m05_axi_awlen;   wire [2:0]    m05_axi_awsize;
wire [1:0]     m05_axi_awburst; wire          m05_axi_awlock;
wire [3:0]     m05_axi_awcache; wire [2:0]    m05_axi_awprot;
wire [3:0]     m05_axi_awqos;   wire [3:0]    m05_axi_awregion;
wire [0:0]     m05_axi_awuser;  wire          m05_axi_awvalid;
reg            m05_axi_awready = 1;
wire [DW-1:0]  m05_axi_wdata;   wire [SW-1:0] m05_axi_wstrb;
wire           m05_axi_wlast;   wire [0:0]    m05_axi_wuser;
wire           m05_axi_wvalid;
reg            m05_axi_wready  = 1;
reg  [IDW-1:0] m05_axi_bid     = 0;
reg  [1:0]     m05_axi_bresp   = 0;
reg  [0:0]     m05_axi_buser   = 0;
reg            m05_axi_bvalid  = 0;
wire           m05_axi_bready;
wire [IDW-1:0] m05_axi_arid;    wire [AW-1:0] m05_axi_araddr;
wire [7:0]     m05_axi_arlen;   wire [2:0]    m05_axi_arsize;
wire [1:0]     m05_axi_arburst; wire          m05_axi_arlock;
wire [3:0]     m05_axi_arcache; wire [2:0]    m05_axi_arprot;
wire [3:0]     m05_axi_arqos;   wire [3:0]    m05_axi_arregion;
wire [0:0]     m05_axi_aruser;  wire          m05_axi_arvalid;
reg            m05_axi_arready = 1;
reg  [IDW-1:0] m05_axi_rid     = 0;
reg  [DW-1:0]  m05_axi_rdata   = 32'hFF05_C005;
reg  [1:0]     m05_axi_rresp   = 0;
reg            m05_axi_rlast   = 1;
reg  [0:0]     m05_axi_ruser   = 0;
reg            m05_axi_rvalid  = 0;
wire           m05_axi_rready;

// --- m06 Distance/Anomaly ---
wire [IDW-1:0] m06_axi_awid;    wire [AW-1:0] m06_axi_awaddr;
wire [7:0]     m06_axi_awlen;   wire [2:0]    m06_axi_awsize;
wire [1:0]     m06_axi_awburst; wire          m06_axi_awlock;
wire [3:0]     m06_axi_awcache; wire [2:0]    m06_axi_awprot;
wire [3:0]     m06_axi_awqos;   wire [3:0]    m06_axi_awregion;
wire [0:0]     m06_axi_awuser;  wire          m06_axi_awvalid;
reg            m06_axi_awready = 1;
wire [DW-1:0]  m06_axi_wdata;   wire [SW-1:0] m06_axi_wstrb;
wire           m06_axi_wlast;   wire [0:0]    m06_axi_wuser;
wire           m06_axi_wvalid;
reg            m06_axi_wready  = 1;
reg  [IDW-1:0] m06_axi_bid     = 0;
reg  [1:0]     m06_axi_bresp   = 0;
reg  [0:0]     m06_axi_buser   = 0;
reg            m06_axi_bvalid  = 0;
wire           m06_axi_bready;
wire [IDW-1:0] m06_axi_arid;    wire [AW-1:0] m06_axi_araddr;
wire [7:0]     m06_axi_arlen;   wire [2:0]    m06_axi_arsize;
wire [1:0]     m06_axi_arburst; wire          m06_axi_arlock;
wire [3:0]     m06_axi_arcache; wire [2:0]    m06_axi_arprot;
wire [3:0]     m06_axi_arqos;   wire [3:0]    m06_axi_arregion;
wire [0:0]     m06_axi_aruser;  wire          m06_axi_arvalid;
reg            m06_axi_arready = 1;
reg  [IDW-1:0] m06_axi_rid     = 0;
reg  [DW-1:0]  m06_axi_rdata   = 32'h0006_D157;
reg  [1:0]     m06_axi_rresp   = 0;
reg            m06_axi_rlast   = 1;
reg  [0:0]     m06_axi_ruser   = 0;
reg            m06_axi_rvalid  = 0;
wire           m06_axi_rready;

// --- m07 DMA Registers ---
wire [IDW-1:0] m07_axi_awid;    wire [AW-1:0] m07_axi_awaddr;
wire [7:0]     m07_axi_awlen;   wire [2:0]    m07_axi_awsize;
wire [1:0]     m07_axi_awburst; wire          m07_axi_awlock;
wire [3:0]     m07_axi_awcache; wire [2:0]    m07_axi_awprot;
wire [3:0]     m07_axi_awqos;   wire [3:0]    m07_axi_awregion;
wire [0:0]     m07_axi_awuser;  wire          m07_axi_awvalid;
reg            m07_axi_awready = 1;
wire [DW-1:0]  m07_axi_wdata;   wire [SW-1:0] m07_axi_wstrb;
wire           m07_axi_wlast;   wire [0:0]    m07_axi_wuser;
wire           m07_axi_wvalid;
reg            m07_axi_wready  = 1;
reg  [IDW-1:0] m07_axi_bid     = 0;
reg  [1:0]     m07_axi_bresp   = 0;
reg  [0:0]     m07_axi_buser   = 0;
reg            m07_axi_bvalid  = 0;
wire           m07_axi_bready;
wire [IDW-1:0] m07_axi_arid;    wire [AW-1:0] m07_axi_araddr;
wire [7:0]     m07_axi_arlen;   wire [2:0]    m07_axi_arsize;
wire [1:0]     m07_axi_arburst; wire          m07_axi_arlock;
wire [3:0]     m07_axi_arcache; wire [2:0]    m07_axi_arprot;
wire [3:0]     m07_axi_arqos;   wire [3:0]    m07_axi_arregion;
wire [0:0]     m07_axi_aruser;  wire          m07_axi_arvalid;
reg            m07_axi_arready = 1;
reg  [IDW-1:0] m07_axi_rid     = 0;
reg  [DW-1:0]  m07_axi_rdata   = 32'h0007_D007;
reg  [1:0]     m07_axi_rresp   = 0;
reg            m07_axi_rlast   = 1;
reg  [0:0]     m07_axi_ruser   = 0;
reg            m07_axi_rvalid  = 0;
wire           m07_axi_rready;

// ---------------------------------------------------------------------------
// DUT instantiation
// ---------------------------------------------------------------------------
axi_interconnect_wrap_2x8 #(
    .DATA_WIDTH   (DW),
    .ADDR_WIDTH   (AW),
    .STRB_WIDTH   (SW),
    .ID_WIDTH     (IDW),
    .AWUSER_WIDTH (1),
    .WUSER_WIDTH  (1),
    .BUSER_WIDTH  (1),
    .ARUSER_WIDTH (1),
    .RUSER_WIDTH  (1),
    .FORWARD_ID   (0),
    .M_REGIONS    (1)
    // Memory map defaults are already set correctly in the wrapper
) dut (
    .clk  (clk),
    .rst  (rst),

    // CPU s00
    .s00_axi_awid    (s00_axi_awid),    .s00_axi_awaddr  (s00_axi_awaddr),
    .s00_axi_awlen   (s00_axi_awlen),   .s00_axi_awsize  (s00_axi_awsize),
    .s00_axi_awburst (s00_axi_awburst), .s00_axi_awlock  (s00_axi_awlock),
    .s00_axi_awcache (s00_axi_awcache), .s00_axi_awprot  (s00_axi_awprot),
    .s00_axi_awqos   (s00_axi_awqos),   .s00_axi_awuser  (s00_axi_awuser),
    .s00_axi_awvalid (s00_axi_awvalid), .s00_axi_awready (s00_axi_awready),
    .s00_axi_wdata   (s00_axi_wdata),   .s00_axi_wstrb   (s00_axi_wstrb),
    .s00_axi_wlast   (s00_axi_wlast),   .s00_axi_wuser   (s00_axi_wuser),
    .s00_axi_wvalid  (s00_axi_wvalid),  .s00_axi_wready  (s00_axi_wready),
    .s00_axi_bid     (s00_axi_bid),     .s00_axi_bresp   (s00_axi_bresp),
    .s00_axi_buser   (s00_axi_buser),   .s00_axi_bvalid  (s00_axi_bvalid),
    .s00_axi_bready  (s00_axi_bready),
    .s00_axi_arid    (s00_axi_arid),    .s00_axi_araddr  (s00_axi_araddr),
    .s00_axi_arlen   (s00_axi_arlen),   .s00_axi_arsize  (s00_axi_arsize),
    .s00_axi_arburst (s00_axi_arburst), .s00_axi_arlock  (s00_axi_arlock),
    .s00_axi_arcache (s00_axi_arcache), .s00_axi_arprot  (s00_axi_arprot),
    .s00_axi_arqos   (s00_axi_arqos),   .s00_axi_aruser  (s00_axi_aruser),
    .s00_axi_arvalid (s00_axi_arvalid), .s00_axi_arready (s00_axi_arready),
    .s00_axi_rid     (s00_axi_rid),     .s00_axi_rdata   (s00_axi_rdata),
    .s00_axi_rresp   (s00_axi_rresp),   .s00_axi_rlast   (s00_axi_rlast),
    .s00_axi_ruser   (s00_axi_ruser),   .s00_axi_rvalid  (s00_axi_rvalid),
    .s00_axi_rready  (s00_axi_rready),

    // DMA s01
    .s01_axi_awid    (s01_axi_awid),    .s01_axi_awaddr  (s01_axi_awaddr),
    .s01_axi_awlen   (s01_axi_awlen),   .s01_axi_awsize  (s01_axi_awsize),
    .s01_axi_awburst (s01_axi_awburst), .s01_axi_awlock  (s01_axi_awlock),
    .s01_axi_awcache (s01_axi_awcache), .s01_axi_awprot  (s01_axi_awprot),
    .s01_axi_awqos   (s01_axi_awqos),   .s01_axi_awuser  (s01_axi_awuser),
    .s01_axi_awvalid (s01_axi_awvalid), .s01_axi_awready (s01_axi_awready),
    .s01_axi_wdata   (s01_axi_wdata),   .s01_axi_wstrb   (s01_axi_wstrb),
    .s01_axi_wlast   (s01_axi_wlast),   .s01_axi_wuser   (s01_axi_wuser),
    .s01_axi_wvalid  (s01_axi_wvalid),  .s01_axi_wready  (s01_axi_wready),
    .s01_axi_bid     (s01_axi_bid),     .s01_axi_bresp   (s01_axi_bresp),
    .s01_axi_buser   (s01_axi_buser),   .s01_axi_bvalid  (s01_axi_bvalid),
    .s01_axi_bready  (s01_axi_bready),
    .s01_axi_arid    (s01_axi_arid),    .s01_axi_araddr  (s01_axi_araddr),
    .s01_axi_arlen   (s01_axi_arlen),   .s01_axi_arsize  (s01_axi_arsize),
    .s01_axi_arburst (s01_axi_arburst), .s01_axi_arlock  (s01_axi_arlock),
    .s01_axi_arcache (s01_axi_arcache), .s01_axi_arprot  (s01_axi_arprot),
    .s01_axi_arqos   (s01_axi_arqos),   .s01_axi_aruser  (s01_axi_aruser),
    .s01_axi_arvalid (s01_axi_arvalid), .s01_axi_arready (s01_axi_arready),
    .s01_axi_rid     (s01_axi_rid),     .s01_axi_rdata   (s01_axi_rdata),
    .s01_axi_rresp   (s01_axi_rresp),   .s01_axi_rlast   (s01_axi_rlast),
    .s01_axi_ruser   (s01_axi_ruser),   .s01_axi_rvalid  (s01_axi_rvalid),
    .s01_axi_rready  (s01_axi_rready),

    // IMEM m00
    .m00_axi_awid(m00_axi_awid), .m00_axi_awaddr(m00_axi_awaddr),
    .m00_axi_awlen(m00_axi_awlen), .m00_axi_awsize(m00_axi_awsize),
    .m00_axi_awburst(m00_axi_awburst), .m00_axi_awlock(m00_axi_awlock),
    .m00_axi_awcache(m00_axi_awcache), .m00_axi_awprot(m00_axi_awprot),
    .m00_axi_awqos(m00_axi_awqos), .m00_axi_awregion(m00_axi_awregion),
    .m00_axi_awuser(m00_axi_awuser), .m00_axi_awvalid(m00_axi_awvalid),
    .m00_axi_awready(m00_axi_awready),
    .m00_axi_wdata(m00_axi_wdata), .m00_axi_wstrb(m00_axi_wstrb),
    .m00_axi_wlast(m00_axi_wlast), .m00_axi_wuser(m00_axi_wuser),
    .m00_axi_wvalid(m00_axi_wvalid), .m00_axi_wready(m00_axi_wready),
    .m00_axi_bid(m00_axi_bid), .m00_axi_bresp(m00_axi_bresp),
    .m00_axi_buser(m00_axi_buser), .m00_axi_bvalid(m00_axi_bvalid),
    .m00_axi_bready(m00_axi_bready),
    .m00_axi_arid(m00_axi_arid), .m00_axi_araddr(m00_axi_araddr),
    .m00_axi_arlen(m00_axi_arlen), .m00_axi_arsize(m00_axi_arsize),
    .m00_axi_arburst(m00_axi_arburst), .m00_axi_arlock(m00_axi_arlock),
    .m00_axi_arcache(m00_axi_arcache), .m00_axi_arprot(m00_axi_arprot),
    .m00_axi_arqos(m00_axi_arqos), .m00_axi_arregion(m00_axi_arregion),
    .m00_axi_aruser(m00_axi_aruser), .m00_axi_arvalid(m00_axi_arvalid),
    .m00_axi_arready(m00_axi_arready),
    .m00_axi_rid(m00_axi_rid), .m00_axi_rdata(m00_axi_rdata),
    .m00_axi_rresp(m00_axi_rresp), .m00_axi_rlast(m00_axi_rlast),
    .m00_axi_ruser(m00_axi_ruser), .m00_axi_rvalid(m00_axi_rvalid),
    .m00_axi_rready(m00_axi_rready),

    // DMEM m01
    .m01_axi_awid(m01_axi_awid), .m01_axi_awaddr(m01_axi_awaddr),
    .m01_axi_awlen(m01_axi_awlen), .m01_axi_awsize(m01_axi_awsize),
    .m01_axi_awburst(m01_axi_awburst), .m01_axi_awlock(m01_axi_awlock),
    .m01_axi_awcache(m01_axi_awcache), .m01_axi_awprot(m01_axi_awprot),
    .m01_axi_awqos(m01_axi_awqos), .m01_axi_awregion(m01_axi_awregion),
    .m01_axi_awuser(m01_axi_awuser), .m01_axi_awvalid(m01_axi_awvalid),
    .m01_axi_awready(m01_axi_awready),
    .m01_axi_wdata(m01_axi_wdata), .m01_axi_wstrb(m01_axi_wstrb),
    .m01_axi_wlast(m01_axi_wlast), .m01_axi_wuser(m01_axi_wuser),
    .m01_axi_wvalid(m01_axi_wvalid), .m01_axi_wready(m01_axi_wready),
    .m01_axi_bid(m01_axi_bid), .m01_axi_bresp(m01_axi_bresp),
    .m01_axi_buser(m01_axi_buser), .m01_axi_bvalid(m01_axi_bvalid),
    .m01_axi_bready(m01_axi_bready),
    .m01_axi_arid(m01_axi_arid), .m01_axi_araddr(m01_axi_araddr),
    .m01_axi_arlen(m01_axi_arlen), .m01_axi_arsize(m01_axi_arsize),
    .m01_axi_arburst(m01_axi_arburst), .m01_axi_arlock(m01_axi_arlock),
    .m01_axi_arcache(m01_axi_arcache), .m01_axi_arprot(m01_axi_arprot),
    .m01_axi_arqos(m01_axi_arqos), .m01_axi_arregion(m01_axi_arregion),
    .m01_axi_aruser(m01_axi_aruser), .m01_axi_arvalid(m01_axi_arvalid),
    .m01_axi_arready(m01_axi_arready),
    .m01_axi_rid(m01_axi_rid), .m01_axi_rdata(m01_axi_rdata),
    .m01_axi_rresp(m01_axi_rresp), .m01_axi_rlast(m01_axi_rlast),
    .m01_axi_ruser(m01_axi_ruser), .m01_axi_rvalid(m01_axi_rvalid),
    .m01_axi_rready(m01_axi_rready),

    // UART m02
    .m02_axi_awid(m02_axi_awid), .m02_axi_awaddr(m02_axi_awaddr),
    .m02_axi_awlen(m02_axi_awlen), .m02_axi_awsize(m02_axi_awsize),
    .m02_axi_awburst(m02_axi_awburst), .m02_axi_awlock(m02_axi_awlock),
    .m02_axi_awcache(m02_axi_awcache), .m02_axi_awprot(m02_axi_awprot),
    .m02_axi_awqos(m02_axi_awqos), .m02_axi_awregion(m02_axi_awregion),
    .m02_axi_awuser(m02_axi_awuser), .m02_axi_awvalid(m02_axi_awvalid),
    .m02_axi_awready(m02_axi_awready),
    .m02_axi_wdata(m02_axi_wdata), .m02_axi_wstrb(m02_axi_wstrb),
    .m02_axi_wlast(m02_axi_wlast), .m02_axi_wuser(m02_axi_wuser),
    .m02_axi_wvalid(m02_axi_wvalid), .m02_axi_wready(m02_axi_wready),
    .m02_axi_bid(m02_axi_bid), .m02_axi_bresp(m02_axi_bresp),
    .m02_axi_buser(m02_axi_buser), .m02_axi_bvalid(m02_axi_bvalid),
    .m02_axi_bready(m02_axi_bready),
    .m02_axi_arid(m02_axi_arid), .m02_axi_araddr(m02_axi_araddr),
    .m02_axi_arlen(m02_axi_arlen), .m02_axi_arsize(m02_axi_arsize),
    .m02_axi_arburst(m02_axi_arburst), .m02_axi_arlock(m02_axi_arlock),
    .m02_axi_arcache(m02_axi_arcache), .m02_axi_arprot(m02_axi_arprot),
    .m02_axi_arqos(m02_axi_arqos), .m02_axi_arregion(m02_axi_arregion),
    .m02_axi_aruser(m02_axi_aruser), .m02_axi_arvalid(m02_axi_arvalid),
    .m02_axi_arready(m02_axi_arready),
    .m02_axi_rid(m02_axi_rid), .m02_axi_rdata(m02_axi_rdata),
    .m02_axi_rresp(m02_axi_rresp), .m02_axi_rlast(m02_axi_rlast),
    .m02_axi_ruser(m02_axi_ruser), .m02_axi_rvalid(m02_axi_rvalid),
    .m02_axi_rready(m02_axi_rready),

    // Timer m03
    .m03_axi_awid(m03_axi_awid), .m03_axi_awaddr(m03_axi_awaddr),
    .m03_axi_awlen(m03_axi_awlen), .m03_axi_awsize(m03_axi_awsize),
    .m03_axi_awburst(m03_axi_awburst), .m03_axi_awlock(m03_axi_awlock),
    .m03_axi_awcache(m03_axi_awcache), .m03_axi_awprot(m03_axi_awprot),
    .m03_axi_awqos(m03_axi_awqos), .m03_axi_awregion(m03_axi_awregion),
    .m03_axi_awuser(m03_axi_awuser), .m03_axi_awvalid(m03_axi_awvalid),
    .m03_axi_awready(m03_axi_awready),
    .m03_axi_wdata(m03_axi_wdata), .m03_axi_wstrb(m03_axi_wstrb),
    .m03_axi_wlast(m03_axi_wlast), .m03_axi_wuser(m03_axi_wuser),
    .m03_axi_wvalid(m03_axi_wvalid), .m03_axi_wready(m03_axi_wready),
    .m03_axi_bid(m03_axi_bid), .m03_axi_bresp(m03_axi_bresp),
    .m03_axi_buser(m03_axi_buser), .m03_axi_bvalid(m03_axi_bvalid),
    .m03_axi_bready(m03_axi_bready),
    .m03_axi_arid(m03_axi_arid), .m03_axi_araddr(m03_axi_araddr),
    .m03_axi_arlen(m03_axi_arlen), .m03_axi_arsize(m03_axi_arsize),
    .m03_axi_arburst(m03_axi_arburst), .m03_axi_arlock(m03_axi_arlock),
    .m03_axi_arcache(m03_axi_arcache), .m03_axi_arprot(m03_axi_arprot),
    .m03_axi_arqos(m03_axi_arqos), .m03_axi_arregion(m03_axi_arregion),
    .m03_axi_aruser(m03_axi_aruser), .m03_axi_arvalid(m03_axi_arvalid),
    .m03_axi_arready(m03_axi_arready),
    .m03_axi_rid(m03_axi_rid), .m03_axi_rdata(m03_axi_rdata),
    .m03_axi_rresp(m03_axi_rresp), .m03_axi_rlast(m03_axi_rlast),
    .m03_axi_ruser(m03_axi_ruser), .m03_axi_rvalid(m03_axi_rvalid),
    .m03_axi_rready(m03_axi_rready),

    // GPIO m04
    .m04_axi_awid(m04_axi_awid), .m04_axi_awaddr(m04_axi_awaddr),
    .m04_axi_awlen(m04_axi_awlen), .m04_axi_awsize(m04_axi_awsize),
    .m04_axi_awburst(m04_axi_awburst), .m04_axi_awlock(m04_axi_awlock),
    .m04_axi_awcache(m04_axi_awcache), .m04_axi_awprot(m04_axi_awprot),
    .m04_axi_awqos(m04_axi_awqos), .m04_axi_awregion(m04_axi_awregion),
    .m04_axi_awuser(m04_axi_awuser), .m04_axi_awvalid(m04_axi_awvalid),
    .m04_axi_awready(m04_axi_awready),
    .m04_axi_wdata(m04_axi_wdata), .m04_axi_wstrb(m04_axi_wstrb),
    .m04_axi_wlast(m04_axi_wlast), .m04_axi_wuser(m04_axi_wuser),
    .m04_axi_wvalid(m04_axi_wvalid), .m04_axi_wready(m04_axi_wready),
    .m04_axi_bid(m04_axi_bid), .m04_axi_bresp(m04_axi_bresp),
    .m04_axi_buser(m04_axi_buser), .m04_axi_bvalid(m04_axi_bvalid),
    .m04_axi_bready(m04_axi_bready),
    .m04_axi_arid(m04_axi_arid), .m04_axi_araddr(m04_axi_araddr),
    .m04_axi_arlen(m04_axi_arlen), .m04_axi_arsize(m04_axi_arsize),
    .m04_axi_arburst(m04_axi_arburst), .m04_axi_arlock(m04_axi_arlock),
    .m04_axi_arcache(m04_axi_arcache), .m04_axi_arprot(m04_axi_arprot),
    .m04_axi_arqos(m04_axi_arqos), .m04_axi_arregion(m04_axi_arregion),
    .m04_axi_aruser(m04_axi_aruser), .m04_axi_arvalid(m04_axi_arvalid),
    .m04_axi_arready(m04_axi_arready),
    .m04_axi_rid(m04_axi_rid), .m04_axi_rdata(m04_axi_rdata),
    .m04_axi_rresp(m04_axi_rresp), .m04_axi_rlast(m04_axi_rlast),
    .m04_axi_ruser(m04_axi_ruser), .m04_axi_rvalid(m04_axi_rvalid),
    .m04_axi_rready(m04_axi_rready),

    // CNN m05
    .m05_axi_awid(m05_axi_awid), .m05_axi_awaddr(m05_axi_awaddr),
    .m05_axi_awlen(m05_axi_awlen), .m05_axi_awsize(m05_axi_awsize),
    .m05_axi_awburst(m05_axi_awburst), .m05_axi_awlock(m05_axi_awlock),
    .m05_axi_awcache(m05_axi_awcache), .m05_axi_awprot(m05_axi_awprot),
    .m05_axi_awqos(m05_axi_awqos), .m05_axi_awregion(m05_axi_awregion),
    .m05_axi_awuser(m05_axi_awuser), .m05_axi_awvalid(m05_axi_awvalid),
    .m05_axi_awready(m05_axi_awready),
    .m05_axi_wdata(m05_axi_wdata), .m05_axi_wstrb(m05_axi_wstrb),
    .m05_axi_wlast(m05_axi_wlast), .m05_axi_wuser(m05_axi_wuser),
    .m05_axi_wvalid(m05_axi_wvalid), .m05_axi_wready(m05_axi_wready),
    .m05_axi_bid(m05_axi_bid), .m05_axi_bresp(m05_axi_bresp),
    .m05_axi_buser(m05_axi_buser), .m05_axi_bvalid(m05_axi_bvalid),
    .m05_axi_bready(m05_axi_bready),
    .m05_axi_arid(m05_axi_arid), .m05_axi_araddr(m05_axi_araddr),
    .m05_axi_arlen(m05_axi_arlen), .m05_axi_arsize(m05_axi_arsize),
    .m05_axi_arburst(m05_axi_arburst), .m05_axi_arlock(m05_axi_arlock),
    .m05_axi_arcache(m05_axi_arcache), .m05_axi_arprot(m05_axi_arprot),
    .m05_axi_arqos(m05_axi_arqos), .m05_axi_arregion(m05_axi_arregion),
    .m05_axi_aruser(m05_axi_aruser), .m05_axi_arvalid(m05_axi_arvalid),
    .m05_axi_arready(m05_axi_arready),
    .m05_axi_rid(m05_axi_rid), .m05_axi_rdata(m05_axi_rdata),
    .m05_axi_rresp(m05_axi_rresp), .m05_axi_rlast(m05_axi_rlast),
    .m05_axi_ruser(m05_axi_ruser), .m05_axi_rvalid(m05_axi_rvalid),
    .m05_axi_rready(m05_axi_rready),

    // Distance/Anomaly m06
    .m06_axi_awid(m06_axi_awid), .m06_axi_awaddr(m06_axi_awaddr),
    .m06_axi_awlen(m06_axi_awlen), .m06_axi_awsize(m06_axi_awsize),
    .m06_axi_awburst(m06_axi_awburst), .m06_axi_awlock(m06_axi_awlock),
    .m06_axi_awcache(m06_axi_awcache), .m06_axi_awprot(m06_axi_awprot),
    .m06_axi_awqos(m06_axi_awqos), .m06_axi_awregion(m06_axi_awregion),
    .m06_axi_awuser(m06_axi_awuser), .m06_axi_awvalid(m06_axi_awvalid),
    .m06_axi_awready(m06_axi_awready),
    .m06_axi_wdata(m06_axi_wdata), .m06_axi_wstrb(m06_axi_wstrb),
    .m06_axi_wlast(m06_axi_wlast), .m06_axi_wuser(m06_axi_wuser),
    .m06_axi_wvalid(m06_axi_wvalid), .m06_axi_wready(m06_axi_wready),
    .m06_axi_bid(m06_axi_bid), .m06_axi_bresp(m06_axi_bresp),
    .m06_axi_buser(m06_axi_buser), .m06_axi_bvalid(m06_axi_bvalid),
    .m06_axi_bready(m06_axi_bready),
    .m06_axi_arid(m06_axi_arid), .m06_axi_araddr(m06_axi_araddr),
    .m06_axi_arlen(m06_axi_arlen), .m06_axi_arsize(m06_axi_arsize),
    .m06_axi_arburst(m06_axi_arburst), .m06_axi_arlock(m06_axi_arlock),
    .m06_axi_arcache(m06_axi_arcache), .m06_axi_arprot(m06_axi_arprot),
    .m06_axi_arqos(m06_axi_arqos), .m06_axi_arregion(m06_axi_arregion),
    .m06_axi_aruser(m06_axi_aruser), .m06_axi_arvalid(m06_axi_arvalid),
    .m06_axi_arready(m06_axi_arready),
    .m06_axi_rid(m06_axi_rid), .m06_axi_rdata(m06_axi_rdata),
    .m06_axi_rresp(m06_axi_rresp), .m06_axi_rlast(m06_axi_rlast),
    .m06_axi_ruser(m06_axi_ruser), .m06_axi_rvalid(m06_axi_rvalid),
    .m06_axi_rready(m06_axi_rready),

    // DMA Regs m07
    .m07_axi_awid(m07_axi_awid), .m07_axi_awaddr(m07_axi_awaddr),
    .m07_axi_awlen(m07_axi_awlen), .m07_axi_awsize(m07_axi_awsize),
    .m07_axi_awburst(m07_axi_awburst), .m07_axi_awlock(m07_axi_awlock),
    .m07_axi_awcache(m07_axi_awcache), .m07_axi_awprot(m07_axi_awprot),
    .m07_axi_awqos(m07_axi_awqos), .m07_axi_awregion(m07_axi_awregion),
    .m07_axi_awuser(m07_axi_awuser), .m07_axi_awvalid(m07_axi_awvalid),
    .m07_axi_awready(m07_axi_awready),
    .m07_axi_wdata(m07_axi_wdata), .m07_axi_wstrb(m07_axi_wstrb),
    .m07_axi_wlast(m07_axi_wlast), .m07_axi_wuser(m07_axi_wuser),
    .m07_axi_wvalid(m07_axi_wvalid), .m07_axi_wready(m07_axi_wready),
    .m07_axi_bid(m07_axi_bid), .m07_axi_bresp(m07_axi_bresp),
    .m07_axi_buser(m07_axi_buser), .m07_axi_bvalid(m07_axi_bvalid),
    .m07_axi_bready(m07_axi_bready),
    .m07_axi_arid(m07_axi_arid), .m07_axi_araddr(m07_axi_araddr),
    .m07_axi_arlen(m07_axi_arlen), .m07_axi_arsize(m07_axi_arsize),
    .m07_axi_arburst(m07_axi_arburst), .m07_axi_arlock(m07_axi_arlock),
    .m07_axi_arcache(m07_axi_arcache), .m07_axi_arprot(m07_axi_arprot),
    .m07_axi_arqos(m07_axi_arqos), .m07_axi_arregion(m07_axi_arregion),
    .m07_axi_aruser(m07_axi_aruser), .m07_axi_arvalid(m07_axi_arvalid),
    .m07_axi_arready(m07_axi_arready),
    .m07_axi_rid(m07_axi_rid), .m07_axi_rdata(m07_axi_rdata),
    .m07_axi_rresp(m07_axi_rresp), .m07_axi_rlast(m07_axi_rlast),
    .m07_axi_ruser(m07_axi_ruser), .m07_axi_rvalid(m07_axi_rvalid),
    .m07_axi_rready(m07_axi_rready)
);

// ---------------------------------------------------------------------------
// Simple slave responders: capture AW+W, reply with BRESP=OKAY
//                          capture AR, reply with RRESP=OKAY, rdata=slaveN_rdata
// Macro-based to keep code compact
// ---------------------------------------------------------------------------
`define SLAVE_MODEL(N) \
  reg [1:0] m``N``_aw_state = 0; \
  always @(posedge clk) begin \
    if (rst) begin \
      m``N``_axi_bvalid <= 0; \
      m``N``_axi_rvalid <= 0; \
    end else begin \
      /* write address accepted */ \
      if (m``N``_axi_awvalid && m``N``_axi_awready) \
        m``N``_axi_bid <= m``N``_axi_awid; \
      /* write data -> assert bvalid next cycle */ \
      if (m``N``_axi_wvalid && m``N``_axi_wready && m``N``_axi_wlast) \
        m``N``_axi_bvalid <= 1; \
      if (m``N``_axi_bvalid && m``N``_axi_bready) \
        m``N``_axi_bvalid <= 0; \
      /* read address accepted -> rvalid next cycle */ \
      if (m``N``_axi_arvalid && m``N``_axi_arready) begin \
        m``N``_axi_rid   <= m``N``_axi_arid; \
        m``N``_axi_rvalid <= 1; \
      end \
      if (m``N``_axi_rvalid && m``N``_axi_rready) \
        m``N``_axi_rvalid <= 0; \
    end \
  end

`SLAVE_MODEL(00)
`SLAVE_MODEL(01)
`SLAVE_MODEL(02)
`SLAVE_MODEL(03)
`SLAVE_MODEL(04)
`SLAVE_MODEL(05)
`SLAVE_MODEL(06)
`SLAVE_MODEL(07)

// ---------------------------------------------------------------------------
// FSDB waveform dump
// ---------------------------------------------------------------------------
initial begin
    $fsdbDumpfile("tb_axi_interconnect_2x8.fsdb");
    $fsdbDumpvars(0, tb_axi_interconnect_2x8);
    $fsdbDumpvars(0, dut);
end

// ---------------------------------------------------------------------------
// Scoreboard / pass-fail counters
// ---------------------------------------------------------------------------
integer pass_cnt = 0;
integer fail_cnt = 0;

task automatic report;
    input string name;
    input logic  ok;
    begin
        if (ok) begin
            $display("[PASS] %s", name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[FAIL] %s", name);
            fail_cnt = fail_cnt + 1;
        end
    end
endtask

// ---------------------------------------------------------------------------
// Persistent arvalid / awvalid monitors – latch any pulse on mNN_arvalid / awvalid
// Reset by the tasks before issuing a transaction.
// ---------------------------------------------------------------------------
reg [7:0] ar_latch = 8'h00;   // bit N set when mNN_arvalid ever went high since last clear
reg [7:0] aw_latch = 8'h00;

always @(posedge clk) begin
    if (m00_axi_arvalid) ar_latch[0] <= 1;
    if (m01_axi_arvalid) ar_latch[1] <= 1;
    if (m02_axi_arvalid) ar_latch[2] <= 1;
    if (m03_axi_arvalid) ar_latch[3] <= 1;
    if (m04_axi_arvalid) ar_latch[4] <= 1;
    if (m05_axi_arvalid) ar_latch[5] <= 1;
    if (m06_axi_arvalid) ar_latch[6] <= 1;
    if (m07_axi_arvalid) ar_latch[7] <= 1;
    if (m00_axi_awvalid) aw_latch[0] <= 1;
    if (m01_axi_awvalid) aw_latch[1] <= 1;
    if (m02_axi_awvalid) aw_latch[2] <= 1;
    if (m03_axi_awvalid) aw_latch[3] <= 1;
    if (m04_axi_awvalid) aw_latch[4] <= 1;
    if (m05_axi_awvalid) aw_latch[5] <= 1;
    if (m06_axi_awvalid) aw_latch[6] <= 1;
    if (m07_axi_awvalid) aw_latch[7] <= 1;
end

// ---------------------------------------------------------------------------
// Helper: CPU single-beat READ via AR/R channels
//   addr        – target address
//   exp_slv     – which mNN_arvalid should pulse (0..7), -1 = don't care
//   expect_decerr – 1 if we expect DECERR (resp[1:0]==2'b11) back
// ---------------------------------------------------------------------------
task automatic cpu_read;
    input  [31:0] addr;
    input  integer exp_slv;
    input  logic   expect_decerr;
    output logic   ok;

    reg [1:0]  got_rresp;
    integer    timeout;
    begin
        ok = 0;

        // clear latch before issuing
        @(negedge clk); ar_latch <= 8'h00;

        // issue AR
        s00_axi_araddr  <= addr;
        s00_axi_arvalid <= 1;
        // wait for arready
        timeout = 0;
        while (!s00_axi_arready && timeout < 200) begin @(posedge clk); timeout++; end
        @(negedge clk);
        s00_axi_arvalid <= 0;

        // wait for R response – latch captures m_arvalid during this window
        timeout = 0;
        while (!s00_axi_rvalid && timeout < 200) begin @(posedge clk); timeout++; end
        got_rresp = s00_axi_rresp;
        @(posedge clk);  // consume

        if (expect_decerr) begin
            ok = (got_rresp == 2'b11);
        end else begin
            if (exp_slv < 0)
                ok = (got_rresp != 2'b11);
            else
                ok = (ar_latch[exp_slv] === 1'b1) && (got_rresp == 2'b00);
        end
        @(negedge clk);
    end
endtask

// ---------------------------------------------------------------------------
// Helper: CPU single-beat WRITE via AW/W/B channels
// ---------------------------------------------------------------------------
task automatic cpu_write;
    input  [31:0] addr;
    input  [31:0] wdata;
    input  integer exp_slv;
    input  logic   expect_decerr;
    output logic   ok;

    reg [1:0]  got_bresp;
    integer    timeout;
    begin
        ok = 0;

        // clear latch before issuing
        @(negedge clk); aw_latch <= 8'h00;

        s00_axi_awaddr  <= addr;
        s00_axi_awvalid <= 1;
        s00_axi_wdata   <= wdata;
        s00_axi_wvalid  <= 1;

        // wait AW handshake
        timeout = 0;
        while (!s00_axi_awready && timeout < 200) begin @(posedge clk); timeout++; end
        @(negedge clk);
        s00_axi_awvalid <= 0;

        // wait W handshake
        timeout = 0;
        while (!s00_axi_wready && timeout < 200) begin @(posedge clk); timeout++; end
        @(negedge clk);
        s00_axi_wvalid <= 0;

        // wait B channel – latch captures awvalid during this window
        timeout = 0;
        while (!s00_axi_bvalid && timeout < 300) begin @(posedge clk); timeout++; end
        got_bresp = s00_axi_bresp;
        @(posedge clk);

        if (expect_decerr)
            ok = (got_bresp == 2'b11);
        else begin
            if (exp_slv < 0)
                ok = (got_bresp != 2'b11);
            else
                ok = (aw_latch[exp_slv] === 1'b1) && (got_bresp == 2'b00);
        end
        @(negedge clk);
    end
endtask

// ---------------------------------------------------------------------------
// Helper: DMA single-beat WRITE (s01)
// ---------------------------------------------------------------------------
task automatic dma_write;
    input  [31:0] addr;
    input  integer exp_slv;
    output logic   ok;

    reg [1:0]  got_bresp;
    integer    timeout;
    begin
        ok = 0;

        @(negedge clk); aw_latch <= 8'h00;

        s01_axi_awaddr  <= addr;
        s01_axi_awvalid <= 1;
        s01_axi_wvalid  <= 1;

        timeout = 0;
        while (!s01_axi_awready && timeout < 200) begin @(posedge clk); timeout++; end
        @(negedge clk);
        s01_axi_awvalid <= 0;

        timeout = 0;
        while (!s01_axi_wready && timeout < 200) begin @(posedge clk); timeout++; end
        @(negedge clk);
        s01_axi_wvalid <= 0;

        timeout = 0;
        while (!s01_axi_bvalid && timeout < 300) begin @(posedge clk); timeout++; end
        got_bresp = s01_axi_bresp;
        @(posedge clk);

        ok = (aw_latch[exp_slv] === 1'b1) && (got_bresp == 2'b00);
        @(negedge clk);
    end
endtask

// ---------------------------------------------------------------------------
// Test logic
// ---------------------------------------------------------------------------
integer test_ok;
integer arb_cpu_done, arb_dma_done;
integer arb_timeout;

initial begin
    $display("============================================================");
    $display("  tb_axi_interconnect_2x8  –  2-master x 8-slave AXI TB");
    $display("============================================================");

    // -----------------------------------------------------------------------
    // TEST 1: Reset behaviour
    // -----------------------------------------------------------------------
    $display("\n[TEST 1] Reset behaviour");
    rst = 1;
    repeat(10) @(posedge clk);
    // During reset all master valids must be 0
    test_ok = ( m00_axi_awvalid === 0 && m00_axi_arvalid === 0 &&
                m01_axi_awvalid === 0 && m01_axi_arvalid === 0 &&
                m02_axi_awvalid === 0 && m02_axi_arvalid === 0 &&
                m03_axi_awvalid === 0 && m03_axi_arvalid === 0 &&
                m04_axi_awvalid === 0 && m04_axi_arvalid === 0 &&
                m05_axi_awvalid === 0 && m05_axi_arvalid === 0 &&
                m06_axi_awvalid === 0 && m06_axi_arvalid === 0 &&
                m07_axi_awvalid === 0 && m07_axi_arvalid === 0 );
    report("TEST 1  : Reset – all master AWVALIDs/ARVALIDs are 0", test_ok);

    // Deassert reset
    @(negedge clk); rst = 0;
    repeat(5) @(posedge clk);

    // -----------------------------------------------------------------------
    // TEST 2: CPU -> IMEM  (addr 0x0000_0000, expect slave m00)
    // -----------------------------------------------------------------------
    $display("\n[TEST 2] CPU -> IMEM  (0x0000_0000)");
    cpu_read(32'h0000_0000, 0, 0, test_ok);
    report("TEST 2  : CPU READ -> IMEM (m00)", test_ok);

    // -----------------------------------------------------------------------
    // TEST 3: CPU -> DMEM  (addr 0x1000_0000, expect slave m01)
    // -----------------------------------------------------------------------
    $display("\n[TEST 3] CPU -> DMEM  (0x1000_0000)");
    cpu_read(32'h1000_0000, 1, 0, test_ok);
    report("TEST 3  : CPU READ -> DMEM (m01)", test_ok);

    // -----------------------------------------------------------------------
    // TEST 4a: CPU -> UART (0x2000_0000, m02)
    // -----------------------------------------------------------------------
    $display("\n[TEST 4a] CPU -> UART  (0x2000_0000)");
    cpu_write(32'h2000_0000, 32'hABCD_1234, 2, 0, test_ok);
    report("TEST 4a : CPU WRITE -> UART (m02)", test_ok);

    // -----------------------------------------------------------------------
    // TEST 4b: CPU -> Timer (0x2000_1000, m03)
    // -----------------------------------------------------------------------
    $display("\n[TEST 4b] CPU -> Timer (0x2000_1000)");
    cpu_read(32'h2000_1000, 3, 0, test_ok);
    report("TEST 4b : CPU READ  -> Timer (m03)", test_ok);

    // -----------------------------------------------------------------------
    // TEST 4c: CPU -> GPIO  (0x2000_2000, m04)
    // -----------------------------------------------------------------------
    $display("\n[TEST 4c] CPU -> GPIO  (0x2000_2000)");
    cpu_write(32'h2000_2000, 32'h5555_AAAA, 4, 0, test_ok);
    report("TEST 4c : CPU WRITE -> GPIO (m04)", test_ok);

    // -----------------------------------------------------------------------
    // TEST 4d: CPU -> CNN   (0x2000_3000, m05)
    // -----------------------------------------------------------------------
    $display("\n[TEST 4d] CPU -> CNN Accelerator (0x2000_3000)");
    cpu_read(32'h2000_3000, 5, 0, test_ok);
    report("TEST 4d : CPU READ  -> CNN Accel (m05)", test_ok);

    // -----------------------------------------------------------------------
    // TEST 4e: CPU -> Distance/Anomaly (0x2000_4000, m06)
    // -----------------------------------------------------------------------
    $display("\n[TEST 4e] CPU -> Distance/Anomaly (0x2000_4000)");
    cpu_read(32'h2000_4000, 6, 0, test_ok);
    report("TEST 4e : CPU READ  -> Distance Engine (m06)", test_ok);

    // -----------------------------------------------------------------------
    // TEST 4f: CPU -> DMA Regs (0x2000_5000, m07)
    // -----------------------------------------------------------------------
    $display("\n[TEST 4f] CPU -> DMA Registers (0x2000_5000)");
    cpu_write(32'h2000_5000, 32'hC0DE_0007, 7, 0, test_ok);
    report("TEST 4f : CPU WRITE -> DMA Regs (m07)", test_ok);

    // -----------------------------------------------------------------------
    // TEST 5: DMA master -> DMEM (0x1000_0000, m01)
    // -----------------------------------------------------------------------
    $display("\n[TEST 5] DMA master -> DMEM (0x1000_0000)");
    dma_write(32'h1000_0000, 1, test_ok);
    report("TEST 5  : DMA WRITE -> DMEM (m01)", test_ok);

    // -----------------------------------------------------------------------
    // TEST 6: DMA master -> CNN (0x2000_3000, m05)
    // -----------------------------------------------------------------------
    $display("\n[TEST 6] DMA master -> CNN (0x2000_3000)");
    dma_write(32'h2000_3000, 5, test_ok);
    report("TEST 6  : DMA WRITE -> CNN (m05)", test_ok);

    // -----------------------------------------------------------------------
    // TEST 7: Simultaneous CPU + DMA -> DMEM  (arbitration)
    // -----------------------------------------------------------------------
    $display("\n[TEST 7] Simultaneous CPU + DMA -> DMEM (arbitration)");
    arb_cpu_done = 0;
    arb_dma_done = 0;

    fork
        // CPU write to DMEM
        begin
            @(negedge clk);
            s00_axi_awaddr  <= 32'h1000_0100;
            s00_axi_awvalid <= 1;
            s00_axi_wdata   <= 32'hC0BE_0001;
            s00_axi_wvalid  <= 1;
            arb_timeout = 0;
            while (!s00_axi_awready && arb_timeout < 400) begin @(posedge clk); arb_timeout++; end
            @(negedge clk); s00_axi_awvalid <= 0;
            arb_timeout = 0;
            while (!s00_axi_wready && arb_timeout < 400) begin @(posedge clk); arb_timeout++; end
            @(negedge clk); s00_axi_wvalid <= 0;
            arb_timeout = 0;
            while (!s00_axi_bvalid && arb_timeout < 400) begin @(posedge clk); arb_timeout++; end
            arb_cpu_done = (s00_axi_bresp == 2'b00) ? 1 : 0;
        end
        // DMA write to DMEM
        begin
            @(negedge clk);
            s01_axi_awaddr  <= 32'h1000_0200;
            s01_axi_awvalid <= 1;
            s01_axi_wdata   <= 32'hD0BE_0002;
            s01_axi_wvalid  <= 1;
            arb_timeout = 0;
            while (!s01_axi_awready && arb_timeout < 400) begin @(posedge clk); arb_timeout++; end
            @(negedge clk); s01_axi_awvalid <= 0;
            arb_timeout = 0;
            while (!s01_axi_wready && arb_timeout < 400) begin @(posedge clk); arb_timeout++; end
            @(negedge clk); s01_axi_wvalid <= 0;
            arb_timeout = 0;
            while (!s01_axi_bvalid && arb_timeout < 400) begin @(posedge clk); arb_timeout++; end
            arb_dma_done = (s01_axi_bresp == 2'b00) ? 1 : 0;
        end
    join

    report("TEST 7  : ARB – CPU transaction completed via DMEM",  arb_cpu_done);
    report("TEST 7  : ARB – DMA transaction completed via DMEM",  arb_dma_done);

    // -----------------------------------------------------------------------
    // TEST 8: Unmapped address -> expect DECERR
    // -----------------------------------------------------------------------
    $display("\n[TEST 8] Unmapped address (0x3000_0000) -> expect DECERR");
    cpu_read(32'h3000_0000, -1, 1, test_ok);
    report("TEST 8  : Unmapped addr – DECERR returned on R channel", test_ok);

    // -----------------------------------------------------------------------
    // Summary
    // -----------------------------------------------------------------------
    repeat(20) @(posedge clk);
    $display("\n============================================================");
    $display("  SIMULATION COMPLETE");
    $display("  PASS: %0d   FAIL: %0d   TOTAL: %0d",
             pass_cnt, fail_cnt, pass_cnt+fail_cnt);
    $display("============================================================");

    if (fail_cnt == 0)
        $display("RESULT: ALL TESTS PASSED");
    else
        $display("RESULT: %0d TEST(S) FAILED", fail_cnt);

    $finish;
end

// Safety watchdog – 500 µs max
initial begin
    #500_000;
    $display("[WATCHDOG] Simulation exceeded 500 us – forcing $finish");
    $finish;
end

endmodule
