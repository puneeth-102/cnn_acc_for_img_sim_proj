// =============================================================================
// File   : dmem_axi.sv
// Module : dmem_axi
// Purpose: Single-Port 64-KB AXI4 Data Memory (DMEM).
//          Specification Requirements:
//            - Base Address: 0x1000_0000 - 0x1000_FFFF (64 KB, 16-bit offset)
//            - 32-bit Data Width, 32-bit Address Width, 8-bit ID Width
//            - 4-bit byte write strobes (wstrb) for byte (INT8), halfword, and word
//            - Supports single-beat and multi-beat AXI4 bursts (INCR mode)
//            - 1-cycle synchronous SRAM read latency
//            - Optional firmware/data preloading via INIT_FILE ($readmemh)
//            - Connected to AXI Interconnect Port m01
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module dmem_axi #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32,
    parameter int STRB_WIDTH = (DATA_WIDTH/8),
    parameter int ID_WIDTH   = 8,
    parameter int MEM_SIZE   = 65536,                 // 64 KB
    parameter int MEM_DEPTH  = MEM_SIZE / STRB_WIDTH, // 16,384 words (32-bit)
    parameter int ADDR_BITS  = 16,                    // 64 KB = 2^16
    parameter string INIT_FILE = ""                   // Optional hex init file
)(
    input  wire                     clk,
    input  wire                     rst_n,      // Active-low synchronous reset

    // -------------------------------------------------------------------------
    // AXI4 Slave Interface (m01: DMEM)
    // -------------------------------------------------------------------------
    // Write Address Channel
    input  wire [ID_WIDTH-1:0]      s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [7:0]               s_axi_awlen,
    input  wire [2:0]               s_axi_awsize,
    input  wire [1:0]               s_axi_awburst,
    input  wire                     s_axi_awvalid,
    output logic                    s_axi_awready,

    // Write Data Channel
    input  wire [DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]    s_axi_wstrb,
    input  wire                     s_axi_wlast,
    input  wire                     s_axi_wvalid,
    output logic                    s_axi_wready,

    // Write Response Channel
    output logic [ID_WIDTH-1:0]     s_axi_bid,
    output logic [1:0]              s_axi_bresp,
    output logic                    s_axi_bvalid,
    input  wire                     s_axi_bready,

    // Read Address Channel
    input  wire [ID_WIDTH-1:0]      s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [7:0]               s_axi_arlen,
    input  wire [2:0]               s_axi_arsize,
    input  wire [1:0]               s_axi_arburst,
    input  wire                     s_axi_arvalid,
    output logic                    s_axi_arready,

    // Read Data Channel
    output logic [ID_WIDTH-1:0]     s_axi_rid,
    output logic [DATA_WIDTH-1:0]   s_axi_rdata,
    output logic [1:0]              s_axi_rresp,
    output logic                    s_axi_rlast,
    output logic                    s_axi_rvalid,
    input  wire                     s_axi_rready
);

    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    // =========================================================================
    // Memory Storage (64 KB: 16,384 x 32-bit words with byte-enable logic)
    // =========================================================================
    logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // Optional Initialization via Hex File
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    // =========================================================================
    // AXI Write Channel Logic (Zero-wait-state single beat + burst capable)
    // =========================================================================
    logic [ID_WIDTH-1:0]   awid_reg;
    logic [ADDR_BITS-1:0]  waddr_cur;
    logic [7:0]            awlen_reg;
    logic [2:0]            awsize_reg;
    logic [7:0]            wbeat_cnt;
    logic                  wr_active;

    wire aw_hs = s_axi_awvalid && s_axi_awready;
    wire w_hs  = s_axi_wvalid && s_axi_wready;
    assign s_axi_wready = (wr_active || (s_axi_awvalid && s_axi_awready)) && !s_axi_bvalid;

    wire [ADDR_BITS-3:0] w_word_idx = (wr_active) ? waddr_cur[ADDR_BITS-1:2] : s_axi_awaddr[ADDR_BITS-1:2];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_awready <= 1'b1;
            s_axi_bvalid  <= 1'b0;
            s_axi_bid     <= '0;
            s_axi_bresp   <= RESP_OKAY;
            awid_reg      <= '0;
            waddr_cur     <= '0;
            awlen_reg     <= '0;
            awsize_reg    <= '0;
            wbeat_cnt     <= '0;
            wr_active     <= 1'b0;
        end else begin
            // 1. Single-beat or burst start when AW and W arrive together
            if (aw_hs && w_hs) begin
                if (s_axi_awlen == 8'd0) begin
                    // Single-beat write completed in 1 cycle
                    s_axi_bvalid  <= 1'b1;
                    s_axi_bid     <= s_axi_awid;
                    s_axi_bresp   <= RESP_OKAY;
                    s_axi_awready <= 1'b0;
                    wr_active     <= 1'b0;
                end else begin
                    // Multi-beat burst write initiated
                    awid_reg      <= s_axi_awid;
                    waddr_cur     <= s_axi_awaddr[ADDR_BITS-1:0] + (1 << s_axi_awsize);
                    awlen_reg     <= s_axi_awlen;
                    awsize_reg    <= s_axi_awsize;
                    wbeat_cnt     <= 8'd1;
                    wr_active     <= 1'b1;
                    s_axi_awready <= 1'b0;
                end
            // 2. AW arrived alone
            end else if (aw_hs) begin
                awid_reg      <= s_axi_awid;
                waddr_cur     <= s_axi_awaddr[ADDR_BITS-1:0];
                awlen_reg     <= s_axi_awlen;
                awsize_reg    <= s_axi_awsize;
                wbeat_cnt     <= 8'd0;
                wr_active     <= 1'b1;
                s_axi_awready <= 1'b0;
            // 3. Ongoing W beats for active burst or delayed W
            end else if (w_hs && wr_active) begin
                waddr_cur <= waddr_cur + (1 << awsize_reg);
                wbeat_cnt <= wbeat_cnt + 8'd1;
                if (s_axi_wlast || (wbeat_cnt + 8'd1 > awlen_reg)) begin
                    s_axi_bvalid <= 1'b1;
                    s_axi_bid    <= awid_reg;
                    s_axi_bresp  <= RESP_OKAY;
                    wr_active    <= 1'b0;
                end
            end

            // 4. Response handshake
            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid  <= 1'b0;
                s_axi_awready <= 1'b1;
            end
        end
    end

    // Memory write execution (Synchronous Byte-masked)
    always @(posedge clk) begin
        if (w_hs) begin
            if (s_axi_wstrb[0]) mem[w_word_idx][7:0]   <= s_axi_wdata[7:0];
            if (s_axi_wstrb[1]) mem[w_word_idx][15:8]  <= s_axi_wdata[15:8];
            if (s_axi_wstrb[2]) mem[w_word_idx][23:16] <= s_axi_wdata[23:16];
            if (s_axi_wstrb[3]) mem[w_word_idx][31:24] <= s_axi_wdata[31:24];
        end
    end

    // =========================================================================
    // AXI Read Channel Logic (Burst-capable with 1-cycle SRAM latency)
    // =========================================================================
    logic [ID_WIDTH-1:0]   arid_reg;
    logic [ADDR_BITS-1:0]  raddr_cur;
    logic [7:0]            arlen_reg;
    logic [2:0]            arsize_reg;
    logic [7:0]            rbeat_cnt;
    logic                  rd_active;

    wire [ADDR_BITS-3:0]   r_word_idx = (rd_active) ? raddr_cur[ADDR_BITS-1:2] : s_axi_araddr[ADDR_BITS-1:2];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_arready <= 1'b1;
            s_axi_rvalid  <= 1'b0;
            s_axi_rid     <= '0;
            s_axi_rdata   <= '0;
            s_axi_rresp   <= RESP_OKAY;
            s_axi_rlast   <= 1'b0;
            arid_reg      <= '0;
            raddr_cur     <= '0;
            arlen_reg     <= '0;
            arsize_reg    <= '0;
            rbeat_cnt     <= '0;
            rd_active     <= 1'b0;
        end else begin
            // 1. Advance or complete active read burst
            if (s_axi_rvalid && s_axi_rready) begin
                if (s_axi_rlast) begin
                    // Burst complete
                    s_axi_rvalid  <= 1'b0;
                    s_axi_rlast   <= 1'b0;
                    rd_active     <= 1'b0;
                    s_axi_arready <= 1'b1;
                end else begin
                    // Next beat in burst
                    logic [ADDR_BITS-1:0] next_raddr;
                    next_raddr  = raddr_cur + (1 << arsize_reg);
                    raddr_cur   <= next_raddr;
                    s_axi_rdata <= mem[next_raddr[ADDR_BITS-1:2]];
                    rbeat_cnt   <= rbeat_cnt + 8'd1;
                    s_axi_rlast <= (rbeat_cnt + 8'd1 == arlen_reg);
                end
            end

            // 2. Capture new Read Address and issue first beat
            if (s_axi_arvalid && s_axi_arready) begin
                arid_reg      <= s_axi_arid;
                raddr_cur     <= s_axi_araddr[ADDR_BITS-1:0];
                arlen_reg     <= s_axi_arlen;
                arsize_reg    <= s_axi_arsize;
                rbeat_cnt     <= 8'd0;
                rd_active     <= 1'b1;
                s_axi_arready <= 1'b0;

                // First beat data
                s_axi_rvalid  <= 1'b1;
                s_axi_rid     <= s_axi_arid;
                s_axi_rdata   <= mem[s_axi_araddr[ADDR_BITS-1:2]];
                s_axi_rresp   <= RESP_OKAY;
                s_axi_rlast   <= (s_axi_arlen == 8'd0);
            end
        end
    end

endmodule
`default_nettype wire
