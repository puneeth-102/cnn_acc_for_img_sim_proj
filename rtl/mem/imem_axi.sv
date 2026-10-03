// =============================================================================
// File   : imem_axi.sv
// Module : imem_axi
// Purpose: True Dual-Port 64-KB AXI4 Instruction Memory (IMEM).
//          Specification Requirements:
//            - Base Address: 0x0000_0000 - 0x0000_FFFF (64 KB, 16-bit offset)
//            - Dual-Port Architecture:
//                * Port A: Dedicated direct CPU IFU instruction fetch (ifu32_*)
//                * Port B: AXI Interconnect m00 slave port (LSU / DMA / System)
//            - 32-bit Data Width, 32-bit Address Width
//            - Parameterizable ID widths (default 8 bits)
//            - 4-bit byte write strobes (wstrb) for byte, halfword, and word
//            - Supports single-beat and multi-beat AXI4 bursts (INCR mode)
//            - 1-cycle synchronous SRAM read latency
//            - Optional firmware preloading via INIT_FILE ($readmemh)
//            - Synthesizable true dual-port RAM structure
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module imem_axi #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32,
    parameter int STRB_WIDTH = (DATA_WIDTH/8),
    parameter int ID_WIDTH_A = 8,
    parameter int ID_WIDTH_B = 8,
    parameter int MEM_SIZE   = 65536,                 // 64 KB
    parameter int MEM_DEPTH  = MEM_SIZE / STRB_WIDTH, // 16,384 words (32-bit)
    parameter int ADDR_BITS  = 16,                    // 64 KB = 2^16
    parameter string INIT_FILE = ""                   // Optional hex init file
)(
    input  wire                     clk,
    input  wire                     rst_n,      // Active-low synchronous reset

    // =========================================================================
    // Port A: AXI4 Slave Interface (Dedicated CPU IFU instruction fetch)
    // =========================================================================
    // Write Address Channel
    input  wire [ID_WIDTH_A-1:0]    s_axi_a_awid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_a_awaddr,
    input  wire [7:0]               s_axi_a_awlen,
    input  wire [2:0]               s_axi_a_awsize,
    input  wire [1:0]               s_axi_a_awburst,
    input  wire                     s_axi_a_awvalid,
    output logic                    s_axi_a_awready,

    // Write Data Channel
    input  wire [DATA_WIDTH-1:0]    s_axi_a_wdata,
    input  wire [STRB_WIDTH-1:0]    s_axi_a_wstrb,
    input  wire                     s_axi_a_wlast,
    input  wire                     s_axi_a_wvalid,
    output logic                    s_axi_a_wready,

    // Write Response Channel
    output logic [ID_WIDTH_A-1:0]   s_axi_a_bid,
    output logic [1:0]              s_axi_a_bresp,
    output logic                    s_axi_a_bvalid,
    input  wire                     s_axi_a_bready,

    // Read Address Channel
    input  wire [ID_WIDTH_A-1:0]    s_axi_a_arid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_a_araddr,
    input  wire [7:0]               s_axi_a_arlen,
    input  wire [2:0]               s_axi_a_arsize,
    input  wire [1:0]               s_axi_a_arburst,
    input  wire                     s_axi_a_arvalid,
    output logic                    s_axi_a_arready,

    // Read Data Channel
    output logic [ID_WIDTH_A-1:0]   s_axi_a_rid,
    output logic [DATA_WIDTH-1:0]   s_axi_a_rdata,
    output logic [1:0]              s_axi_a_rresp,
    output logic                    s_axi_a_rlast,
    output logic                    s_axi_a_rvalid,
    input  wire                     s_axi_a_rready,

    // =========================================================================
    // Port B: AXI4 Slave Interface (Interconnect m00: LSU / DMA / System)
    // =========================================================================
    // Write Address Channel
    input  wire [ID_WIDTH_B-1:0]    s_axi_b_awid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_b_awaddr,
    input  wire [7:0]               s_axi_b_awlen,
    input  wire [2:0]               s_axi_b_awsize,
    input  wire [1:0]               s_axi_b_awburst,
    input  wire                     s_axi_b_awvalid,
    output logic                    s_axi_b_awready,

    // Write Data Channel
    input  wire [DATA_WIDTH-1:0]    s_axi_b_wdata,
    input  wire [STRB_WIDTH-1:0]    s_axi_b_wstrb,
    input  wire                     s_axi_b_wlast,
    input  wire                     s_axi_b_wvalid,
    output logic                    s_axi_b_wready,

    // Write Response Channel
    output logic [ID_WIDTH_B-1:0]   s_axi_b_bid,
    output logic [1:0]              s_axi_b_bresp,
    output logic                    s_axi_b_bvalid,
    input  wire                     s_axi_b_bready,

    // Read Address Channel
    input  wire [ID_WIDTH_B-1:0]    s_axi_b_arid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_b_araddr,
    input  wire [7:0]               s_axi_b_arlen,
    input  wire [2:0]               s_axi_b_arsize,
    input  wire [1:0]               s_axi_b_arburst,
    input  wire                     s_axi_b_arvalid,
    output logic                    s_axi_b_arready,

    // Read Data Channel
    output logic [ID_WIDTH_B-1:0]   s_axi_b_rid,
    output logic [DATA_WIDTH-1:0]   s_axi_b_rdata,
    output logic [1:0]              s_axi_b_rresp,
    output logic                    s_axi_b_rlast,
    output logic                    s_axi_b_rvalid,
    input  wire                     s_axi_b_rready
);

    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    // =========================================================================
    // Shared Memory Array (64 KB: 16,384 x 32-bit words)
    // =========================================================================
    logic [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // Optional Hex Preloading (for boot code / firmware)
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    // =========================================================================
    // PORT A LOGIC (Primarily IFU Instruction Fetch)
    // =========================================================================

    // Port A Write Channel State
    logic [ID_WIDTH_A-1:0] awid_a_reg;
    logic [ADDR_BITS-1:0]  waddr_a_cur;
    logic [7:0]            awlen_a_reg;
    logic [2:0]            awsize_a_reg;
    logic [7:0]            wbeat_a_cnt;
    logic                  wr_a_active;

    wire aw_a_hs = s_axi_a_awvalid && s_axi_a_awready;
    wire w_a_hs  = s_axi_a_wvalid && s_axi_a_wready;
    assign s_axi_a_wready = (wr_a_active || (s_axi_a_awvalid && s_axi_a_awready)) && !s_axi_a_bvalid;

    wire [ADDR_BITS-3:0] w_word_idx_a = (wr_a_active) ? waddr_a_cur[ADDR_BITS-1:2] : s_axi_a_awaddr[ADDR_BITS-1:2];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_a_awready <= 1'b1;
            s_axi_a_bvalid  <= 1'b0;
            s_axi_a_bid     <= '0;
            s_axi_a_bresp   <= RESP_OKAY;
            awid_a_reg      <= '0;
            waddr_a_cur     <= '0;
            awlen_a_reg     <= '0;
            awsize_a_reg    <= '0;
            wbeat_a_cnt     <= '0;
            wr_a_active     <= 1'b0;
        end else begin
            // 1. Single-beat or burst start when AW and W arrive together
            if (aw_a_hs && w_a_hs) begin
                if (s_axi_a_awlen == 8'd0) begin
                    // Single-beat write completed in 1 cycle
                    s_axi_a_bvalid  <= 1'b1;
                    s_axi_a_bid     <= s_axi_a_awid;
                    s_axi_a_bresp   <= RESP_OKAY;
                    s_axi_a_awready <= 1'b0;
                    wr_a_active     <= 1'b0;
                end else begin
                    // Multi-beat burst write initiated
                    awid_a_reg      <= s_axi_a_awid;
                    waddr_a_cur     <= s_axi_a_awaddr[ADDR_BITS-1:0] + (1 << s_axi_a_awsize);
                    awlen_a_reg     <= s_axi_a_awlen;
                    awsize_a_reg    <= s_axi_a_awsize;
                    wbeat_a_cnt     <= 8'd1;
                    wr_a_active     <= 1'b1;
                    s_axi_a_awready <= 1'b0;
                end
            // 2. AW arrived alone
            end else if (aw_a_hs) begin
                awid_a_reg      <= s_axi_a_awid;
                waddr_a_cur     <= s_axi_a_awaddr[ADDR_BITS-1:0];
                awlen_a_reg     <= s_axi_a_awlen;
                awsize_a_reg    <= s_axi_a_awsize;
                wbeat_a_cnt     <= 8'd0;
                wr_a_active     <= 1'b1;
                s_axi_a_awready <= 1'b0;
            // 3. Ongoing W beats for active burst or delayed W
            end else if (w_a_hs && wr_a_active) begin
                waddr_a_cur <= waddr_a_cur + (1 << awsize_a_reg);
                wbeat_a_cnt <= wbeat_a_cnt + 8'd1;
                if (s_axi_a_wlast || (wbeat_a_cnt + 8'd1 > awlen_a_reg)) begin
                    s_axi_a_bvalid <= 1'b1;
                    s_axi_a_bid    <= awid_a_reg;
                    s_axi_a_bresp  <= RESP_OKAY;
                    wr_a_active    <= 1'b0;
                end
            end

            // 4. Response handshake
            if (s_axi_a_bvalid && s_axi_a_bready) begin
                s_axi_a_bvalid  <= 1'b0;
                s_axi_a_awready <= 1'b1;
            end
        end
    end

    // Port A Read Channel State
    logic [ID_WIDTH_A-1:0] arid_a_reg;
    logic [ADDR_BITS-1:0]  raddr_a_cur;
    logic [7:0]            arlen_a_reg;
    logic [2:0]            arsize_a_reg;
    logic [7:0]            rbeat_a_cnt;
    logic                  rd_a_active;

    wire [ADDR_BITS-3:0] r_word_idx_a = (rd_a_active) ? raddr_a_cur[ADDR_BITS-1:2] : s_axi_a_araddr[ADDR_BITS-1:2];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_a_arready <= 1'b1;
            s_axi_a_rvalid  <= 1'b0;
            s_axi_a_rid     <= '0;
            s_axi_a_rdata   <= '0;
            s_axi_a_rresp   <= RESP_OKAY;
            s_axi_a_rlast   <= 1'b0;
            arid_a_reg      <= '0;
            raddr_a_cur     <= '0;
            arlen_a_reg     <= '0;
            arsize_a_reg    <= '0;
            rbeat_a_cnt     <= '0;
            rd_a_active     <= 1'b0;
        end else begin
            // 1. Advance or complete active read burst
            if (s_axi_a_rvalid && s_axi_a_rready) begin
                if (s_axi_a_rlast) begin
                    s_axi_a_rvalid  <= 1'b0;
                    s_axi_a_rlast   <= 1'b0;
                    rd_a_active     <= 1'b0;
                    s_axi_a_arready <= 1'b1;
                end else begin
                    logic [ADDR_BITS-1:0] next_raddr_a;
                    next_raddr_a    = raddr_a_cur + (1 << arsize_a_reg);
                    raddr_a_cur     <= next_raddr_a;
                    s_axi_a_rdata   <= mem[next_raddr_a[ADDR_BITS-1:2]];
                    rbeat_a_cnt     <= rbeat_a_cnt + 8'd1;
                    s_axi_a_rlast   <= (rbeat_a_cnt + 8'd1 == arlen_a_reg);
                end
            end

            // 2. Capture new Read Address and issue first beat
            if (s_axi_a_arvalid && s_axi_a_arready) begin
                arid_a_reg      <= s_axi_a_arid;
                raddr_a_cur     <= s_axi_a_araddr[ADDR_BITS-1:0];
                arlen_a_reg     <= s_axi_a_arlen;
                arsize_a_reg    <= s_axi_a_arsize;
                rbeat_a_cnt     <= 8'd0;
                rd_a_active     <= 1'b1;
                s_axi_a_arready <= 1'b0;

                s_axi_a_rvalid  <= 1'b1;
                s_axi_a_rid     <= s_axi_a_arid;
                s_axi_a_rdata   <= mem[s_axi_a_araddr[ADDR_BITS-1:2]];
                s_axi_a_rresp   <= RESP_OKAY;
                s_axi_a_rlast   <= (s_axi_a_arlen == 8'd0);
            end
        end
    end

    // =========================================================================
    // PORT B LOGIC (Interconnect m00: LSU / DMA / System)
    // =========================================================================

    // Port B Write Channel State
    logic [ID_WIDTH_B-1:0] awid_b_reg;
    logic [ADDR_BITS-1:0]  waddr_b_cur;
    logic [7:0]            awlen_b_reg;
    logic [2:0]            awsize_b_reg;
    logic [7:0]            wbeat_b_cnt;
    logic                  wr_b_active;

    wire aw_b_hs = s_axi_b_awvalid && s_axi_b_awready;
    wire w_b_hs  = s_axi_b_wvalid && s_axi_b_wready;
    assign s_axi_b_wready = (wr_b_active || (s_axi_b_awvalid && s_axi_b_awready)) && !s_axi_b_bvalid;

    wire [ADDR_BITS-3:0] w_word_idx_b = (wr_b_active) ? waddr_b_cur[ADDR_BITS-1:2] : s_axi_b_awaddr[ADDR_BITS-1:2];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_b_awready <= 1'b1;
            s_axi_b_bvalid  <= 1'b0;
            s_axi_b_bid     <= '0;
            s_axi_b_bresp   <= RESP_OKAY;
            awid_b_reg      <= '0;
            waddr_b_cur     <= '0;
            awlen_b_reg     <= '0;
            awsize_b_reg    <= '0;
            wbeat_b_cnt     <= '0;
            wr_b_active     <= 1'b0;
        end else begin
            // 1. Single-beat or burst start when AW and W arrive together
            if (aw_b_hs && w_b_hs) begin
                if (s_axi_b_awlen == 8'd0) begin
                    // Single-beat write completed in 1 cycle
                    s_axi_b_bvalid  <= 1'b1;
                    s_axi_b_bid     <= s_axi_b_awid;
                    s_axi_b_bresp   <= RESP_OKAY;
                    s_axi_b_awready <= 1'b0;
                    wr_b_active     <= 1'b0;
                end else begin
                    // Multi-beat burst write initiated
                    awid_b_reg      <= s_axi_b_awid;
                    waddr_b_cur     <= s_axi_b_awaddr[ADDR_BITS-1:0] + (1 << s_axi_b_awsize);
                    awlen_b_reg     <= s_axi_b_awlen;
                    awsize_b_reg    <= s_axi_b_awsize;
                    wbeat_b_cnt     <= 8'd1;
                    wr_b_active     <= 1'b1;
                    s_axi_b_awready <= 1'b0;
                end
            // 2. AW arrived alone
            end else if (aw_b_hs) begin
                awid_b_reg      <= s_axi_b_awid;
                waddr_b_cur     <= s_axi_b_awaddr[ADDR_BITS-1:0];
                awlen_b_reg     <= s_axi_b_awlen;
                awsize_b_reg    <= s_axi_b_awsize;
                wbeat_b_cnt     <= 8'd0;
                wr_b_active     <= 1'b1;
                s_axi_b_awready <= 1'b0;
            // 3. Ongoing W beats for active burst or delayed W
            end else if (w_b_hs && wr_b_active) begin
                waddr_b_cur <= waddr_b_cur + (1 << awsize_b_reg);
                wbeat_b_cnt <= wbeat_b_cnt + 8'd1;
                if (s_axi_b_wlast || (wbeat_b_cnt + 8'd1 > awlen_b_reg)) begin
                    s_axi_b_bvalid <= 1'b1;
                    s_axi_b_bid    <= awid_b_reg;
                    s_axi_b_bresp  <= RESP_OKAY;
                    wr_b_active    <= 1'b0;
                end
            end

            // 4. Response handshake
            if (s_axi_b_bvalid && s_axi_b_bready) begin
                s_axi_b_bvalid  <= 1'b0;
                s_axi_b_awready <= 1'b1;
            end
        end
    end

    // Port B Read Channel State
    logic [ID_WIDTH_B-1:0] arid_b_reg;
    logic [ADDR_BITS-1:0]  raddr_b_cur;
    logic [7:0]            arlen_b_reg;
    logic [2:0]            arsize_b_reg;
    logic [7:0]            rbeat_b_cnt;
    logic                  rd_b_active;

    wire [ADDR_BITS-3:0] r_word_idx_b = (rd_b_active) ? raddr_b_cur[ADDR_BITS-1:2] : s_axi_b_araddr[ADDR_BITS-1:2];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_b_arready <= 1'b1;
            s_axi_b_rvalid  <= 1'b0;
            s_axi_b_rid     <= '0;
            s_axi_b_rdata   <= '0;
            s_axi_b_rresp   <= RESP_OKAY;
            s_axi_b_rlast   <= 1'b0;
            arid_b_reg      <= '0;
            raddr_b_cur     <= '0;
            arlen_b_reg     <= '0;
            arsize_b_reg    <= '0;
            rbeat_b_cnt     <= '0;
            rd_b_active     <= 1'b0;
        end else begin
            // 1. Advance or complete active read burst
            if (s_axi_b_rvalid && s_axi_b_rready) begin
                if (s_axi_b_rlast) begin
                    s_axi_b_rvalid  <= 1'b0;
                    s_axi_b_rlast   <= 1'b0;
                    rd_b_active     <= 1'b0;
                    s_axi_b_arready <= 1'b1;
                end else begin
                    logic [ADDR_BITS-1:0] next_raddr_b;
                    next_raddr_b    = raddr_b_cur + (1 << arsize_b_reg);
                    raddr_b_cur     <= next_raddr_b;
                    s_axi_b_rdata   <= mem[next_raddr_b[ADDR_BITS-1:2]];
                    rbeat_b_cnt     <= rbeat_b_cnt + 8'd1;
                    s_axi_b_rlast   <= (rbeat_b_cnt + 8'd1 == arlen_b_reg);
                end
            end

            // 2. Capture new Read Address and issue first beat
            if (s_axi_b_arvalid && s_axi_b_arready) begin
                arid_b_reg      <= s_axi_b_arid;
                raddr_b_cur     <= s_axi_b_araddr[ADDR_BITS-1:0];
                arlen_b_reg     <= s_axi_b_arlen;
                arsize_b_reg    <= s_axi_b_arsize;
                rbeat_b_cnt     <= 8'd0;
                rd_b_active     <= 1'b1;
                s_axi_b_arready <= 1'b0;

                s_axi_b_rvalid  <= 1'b1;
                s_axi_b_rid     <= s_axi_b_arid;
                s_axi_b_rdata   <= mem[s_axi_b_araddr[ADDR_BITS-1:2]];
                s_axi_b_rresp   <= RESP_OKAY;
                s_axi_b_rlast   <= (s_axi_b_arlen == 8'd0);
            end
        end
    end

    // =========================================================================
    // Dual-Port Synchronous Memory Write Execution (Byte-masked)
    // =========================================================================
    wire wr_en_a = w_a_hs;
    wire wr_en_b = w_b_hs;

    always @(posedge clk) begin
        // Port A Write (if active)
        if (wr_en_a) begin
            if (s_axi_a_wstrb[0]) mem[w_word_idx_a][7:0]   <= s_axi_a_wdata[7:0];
            if (s_axi_a_wstrb[1]) mem[w_word_idx_a][15:8]  <= s_axi_a_wdata[15:8];
            if (s_axi_a_wstrb[2]) mem[w_word_idx_a][23:16] <= s_axi_a_wdata[23:16];
            if (s_axi_a_wstrb[3]) mem[w_word_idx_a][31:24] <= s_axi_a_wdata[31:24];
        end

        // Port B Write (Port B takes priority in collision case)
        if (wr_en_b) begin
            if (s_axi_b_wstrb[0]) mem[w_word_idx_b][7:0]   <= s_axi_b_wdata[7:0];
            if (s_axi_b_wstrb[1]) mem[w_word_idx_b][15:8]  <= s_axi_b_wdata[15:8];
            if (s_axi_b_wstrb[2]) mem[w_word_idx_b][23:16] <= s_axi_b_wdata[23:16];
            if (s_axi_b_wstrb[3]) mem[w_word_idx_b][31:24] <= s_axi_b_wdata[31:24];
        end
    end

endmodule
`default_nettype wire
