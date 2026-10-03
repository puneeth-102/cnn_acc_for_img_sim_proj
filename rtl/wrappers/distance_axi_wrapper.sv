// =============================================================================
// File   : distance_axi_wrapper.sv
// Module : distance_axi_wrapper
// Purpose: AXI4-Lite slave wrapper for Distance/Similarity Anomaly Detection IP.
//          Implements the memory-mapped register interface defined in Section 6.2
//          of the CNN Anomaly Detection SoC Specification.
//
// Register Map (Base: 0x2000_4000, 4 KB region):
//   Offset  Name             R/W  Description
//   0x00    CTRL             R/W  bit0: DIST_START, bit1: DIST_RESET, bit2: DIST_IRQ_EN
//   0x04    STATUS           R    bit0: DIST_BUSY, bit1: DIST_DONE, bit2: DIST_ERROR (W1C on bit1/bit2)
//   0x08    EMBED_BASE_ADDR  R/W  Query embedding memory address (default: 0x1000_2000)
//   0x0C    REF_BASE_ADDR    R/W  Reference embedding base address (default: 0x1000_3000)
//   0x10    REF_COUNT        R/W  Number of reference embeddings to compare (default: 1)
//   0x14    METRIC           R/W  Distance metric selection (0: Manhattan L1 distance)
//   0x18    THRESHOLD        R/W  Programmable anomaly threshold (default: 100)
//   0x1C    RESULT           R    Classification result (bit0: 1 = MATCH / similar, 0 = ANOMALY)
//   0x20    MIN_DISTANCE     R    Minimum calculated distance (32-bit integer)
//   0x24    ERROR_CODE       R    Error code (0: none, 1: illegal reg/unmapped, 2: busy start, 3: invalid ref count, 4: invalid metric)
//   0x100.. QUERY_EMBEDDING  R/W  Query embedding vector (16 32-bit words = 64 bytes)
//   0x200.. REF_EMBEDDING    R/W  Reference embedding vector 0 (16 32-bit words = 64 bytes)
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module distance_axi_wrapper #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32,
    parameter int STRB_WIDTH = (DATA_WIDTH/8),
    parameter int ID_WIDTH   = 8
)(
    input  wire                     clk,
    input  wire                     rst_n,      // Active-low reset

    // -------------------------------------------------------------------------
    // AXI Slave Interface
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
    input  wire                     s_axi_rready,

    // -------------------------------------------------------------------------
    // Hardware Direct Coupling & Interrupt
    // -------------------------------------------------------------------------
    input  wire signed [31:0]       hw_query_embedding [0:15],
    output logic                    score_done_irq
);

    // =========================================================================
    // Registers
    // =========================================================================
    logic        reg_ctrl_irq_en;
    logic        reg_status_busy;
    logic        reg_status_done;
    logic        reg_status_error;

    logic [31:0] reg_embed_base_addr;
    logic [31:0] reg_ref_base_addr;
    logic [31:0] reg_ref_count;
    logic [31:0] reg_metric;
    logic [31:0] reg_threshold;
    logic [31:0] reg_result;
    logic [31:0] reg_min_distance;
    logic [31:0] reg_error_code;

    // Internal Query & Reference Embeddings
    logic signed [31:0] query_mem [0:15];
    logic signed [31:0] ref_mem   [0:15];
    logic               query_written_by_axi;

    // Distance calculation module interface
    logic signed [39:0] calc_distance;
    logic               calc_similar;

    distance #(
        .DATA_W (32),
        .EMB_W  (16),
        .DIST_W (40)
    ) u_dist (
        .embedding_a (query_mem),
        .embedding_b (ref_mem),
        .distance    (calc_distance)
    );

    threshold #(
        .DIST_W (40)
    ) u_thresh (
        .distance        (calc_distance),
        .threshold_value ({{8{reg_threshold[31]}}, reg_threshold}),
        .similar         (calc_similar)
    );

    // Interrupt output
    assign score_done_irq = reg_status_done && reg_ctrl_irq_en;

    // =========================================================================
    // AXI4-Lite Handshake Registers
    // =========================================================================
    logic [ADDR_WIDTH-1:0] awaddr_latched;
    logic [ID_WIDTH-1:0]   awid_latched;
    logic                  aw_received;

    logic [DATA_WIDTH-1:0] wdata_latched;
    logic [STRB_WIDTH-1:0] wstrb_latched;
    logic                  w_received;

    logic [ADDR_WIDTH-1:0] araddr_latched;
    logic [ID_WIDTH-1:0]   arid_latched;

    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    // Check if address is valid
    function automatic logic is_valid_addr(input logic [11:0] off);
        if (off <= 12'h024) is_valid_addr = 1'b1;                                  // Registers 0x00 - 0x24
        else if (off >= 12'h100 && off <= 12'h13C && (off[1:0] == 2'b00)) is_valid_addr = 1'b1; // Query vector 0x100 - 0x13C
        else if (off >= 12'h200 && off <= 12'h23C && (off[1:0] == 2'b00)) is_valid_addr = 1'b1; // Ref vector 0x200 - 0x23C
        else is_valid_addr = 1'b0;
    endfunction

    // =========================================================================
    // AXI Write Channel Logic
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_awready   <= 1'b1;
            s_axi_wready    <= 1'b1;
            s_axi_bvalid    <= 1'b0;
            s_axi_bid       <= '0;
            s_axi_bresp     <= RESP_OKAY;
            aw_received     <= 1'b0;
            w_received      <= 1'b0;
            awaddr_latched  <= '0;
            awid_latched    <= '0;
            wdata_latched   <= '0;
            wstrb_latched   <= '0;
        end else begin
            // Latch AW
            if (s_axi_awvalid && s_axi_awready) begin
                awaddr_latched <= s_axi_awaddr;
                awid_latched   <= s_axi_awid;
                aw_received    <= 1'b1;
                s_axi_awready  <= 1'b0;
            end

            // Latch W
            if (s_axi_wvalid && s_axi_wready) begin
                wdata_latched <= s_axi_wdata;
                wstrb_latched <= s_axi_wstrb;
                w_received    <= 1'b1;
                s_axi_wready  <= 1'b0;
            end

            // When both received, prepare BVALID
            if ((aw_received || (s_axi_awvalid && s_axi_awready)) &&
                (w_received  || (s_axi_wvalid  && s_axi_wready))) begin
                
                logic [11:0] target_off;
                target_off = aw_received ? awaddr_latched[11:0] : s_axi_awaddr[11:0];

                s_axi_bvalid <= 1'b1;
                s_axi_bid    <= aw_received ? awid_latched : s_axi_awid;
                s_axi_bresp  <= is_valid_addr(target_off) ? RESP_OKAY : RESP_SLVERR;

                aw_received  <= 1'b0;
                w_received   <= 1'b0;
            end

            // Clear BVALID upon BREADY
            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid  <= 1'b0;
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
            end
        end
    end

    wire wr_execute = (aw_received || (s_axi_awvalid && s_axi_awready)) &&
                      (w_received  || (s_axi_wvalid  && s_axi_wready)) && !s_axi_bvalid;

    // =========================================================================
    // AXI Read Channel Logic
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_arready  <= 1'b1;
            s_axi_rvalid   <= 1'b0;
            s_axi_rid      <= '0;
            s_axi_rdata    <= '0;
            s_axi_rresp    <= RESP_OKAY;
            s_axi_rlast    <= 1'b1;
            araddr_latched <= '0;
            arid_latched   <= '0;
        end else begin
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_arready  <= 1'b0;
                s_axi_rvalid   <= 1'b1;
                s_axi_rid      <= s_axi_arid;
                s_axi_rlast    <= 1'b1;
                araddr_latched <= s_axi_araddr;
                arid_latched   <= s_axi_arid;

                if (!is_valid_addr(s_axi_araddr[11:0])) begin
                    s_axi_rresp <= RESP_SLVERR;
                    s_axi_rdata <= 32'hDEAD_BEEF;
                end else begin
                    s_axi_rresp <= RESP_OKAY;
                    case (s_axi_araddr[11:0])
                        12'h000: s_axi_rdata <= {29'b0, reg_ctrl_irq_en, 2'b00};
                        12'h004: s_axi_rdata <= {29'b0, reg_status_error, reg_status_done, reg_status_busy};
                        12'h008: s_axi_rdata <= reg_embed_base_addr;
                        12'h00C: s_axi_rdata <= reg_ref_base_addr;
                        12'h010: s_axi_rdata <= reg_ref_count;
                        12'h014: s_axi_rdata <= reg_metric;
                        12'h018: s_axi_rdata <= reg_threshold;
                        12'h01C: s_axi_rdata <= reg_result;
                        12'h020: s_axi_rdata <= reg_min_distance;
                        12'h024: s_axi_rdata <= reg_error_code;
                        default: begin
                            if (s_axi_araddr[11:0] >= 12'h100 && s_axi_araddr[11:0] <= 12'h13C) begin
                                int idx;
                                idx = (s_axi_araddr[11:0] - 12'h100) >> 2;
                                s_axi_rdata <= query_written_by_axi ? query_mem[idx] : hw_query_embedding[idx];
                            end else if (s_axi_araddr[11:0] >= 12'h200 && s_axi_araddr[11:0] <= 12'h23C) begin
                                int idx;
                                idx = (s_axi_araddr[11:0] - 12'h200) >> 2;
                                s_axi_rdata <= ref_mem[idx];
                            end else begin
                                s_axi_rdata <= '0;
                            end
                        end
                    endcase
                end
            end

            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid  <= 1'b0;
                s_axi_arready <= 1'b1;
            end
        end
    end

    // =========================================================================
    // Core Distance / Scoring Processing
    // =========================================================================
    logic calc_pending;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_ctrl_irq_en      <= 1'b0;
            reg_status_busy      <= 1'b0;
            reg_status_done      <= 1'b0;
            reg_status_error     <= 1'b0;

            reg_embed_base_addr  <= 32'h1000_2000;
            reg_ref_base_addr    <= 32'h1000_3000;
            reg_ref_count        <= 32'd1;
            reg_metric           <= 32'd0;       // 0: Manhattan L1
            reg_threshold        <= 32'd100;     // default threshold 100
            reg_result           <= 32'd0;
            reg_min_distance     <= 32'd0;
            reg_error_code       <= 32'd0;
            calc_pending         <= 1'b0;
            query_written_by_axi <= 1'b0;

            // Initialize default vectors to match default CNN output (1764)
            for (int k = 0; k < 16; k = k + 1) begin
                query_mem[k] <= 32'sd1764;
                ref_mem[k]   <= 32'sd1764;
            end

        end else begin
            // Complete calculation when pending
            if (calc_pending) begin
                calc_pending     <= 1'b0;
                reg_status_busy  <= 1'b0;
                reg_status_done  <= 1'b1;
                reg_min_distance <= calc_distance[31:0];
                reg_result       <= {31'b0, calc_similar};
            end

            // Process writes
            if (wr_execute) begin
                logic [11:0] off;
                logic [31:0] dat;

                off = aw_received ? awaddr_latched[11:0] : s_axi_awaddr[11:0];
                dat = w_received  ? wdata_latched        : s_axi_wdata;

                if (!is_valid_addr(off)) begin
                    reg_status_error <= 1'b1;
                    reg_error_code   <= 32'd1; // ILLEGAL_REG_ACCESS
                end else begin
                    case (off)
                        12'h000: begin // CTRL
                            if (dat[1]) begin // Soft reset
                                reg_status_busy      <= 1'b0;
                                reg_status_done      <= 1'b0;
                                reg_status_error     <= 1'b0;
                                reg_error_code       <= 32'd0;
                                reg_ctrl_irq_en      <= 1'b0;
                                calc_pending         <= 1'b0;
                                query_written_by_axi <= 1'b0;
                            end else if (reg_status_busy || calc_pending) begin
                                if (dat[0]) begin
                                    reg_status_error <= 1'b1;
                                    reg_error_code   <= 32'd2; // BUSY_START
                                end
                            end else begin
                                reg_ctrl_irq_en <= dat[2];

                                if (dat[0]) begin // DIST_START
                                    if (reg_ref_count == 0 || reg_ref_count > 16) begin
                                        reg_status_error <= 1'b1;
                                        reg_error_code   <= 32'd3; // INVALID_REF_COUNT
                                    end else if (reg_metric != 0) begin
                                        reg_status_error <= 1'b1;
                                        reg_error_code   <= 32'd4; // INVALID_METRIC
                                    end else begin
                                        reg_status_busy  <= 1'b1;
                                        reg_status_done  <= 1'b0;
                                        reg_status_error <= 1'b0;
                                        reg_error_code   <= 32'd0;
                                        calc_pending     <= 1'b1;
                                        if (!query_written_by_axi) begin
                                            for (int k = 0; k < 16; k = k + 1) begin
                                                query_mem[k] <= hw_query_embedding[k];
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        12'h004: begin // STATUS W1C
                            if (dat[1]) reg_status_done  <= 1'b0;
                            if (dat[2]) reg_status_error <= 1'b0;
                        end

                        12'h008: reg_embed_base_addr <= dat;
                        12'h00C: reg_ref_base_addr   <= dat;
                        12'h010: reg_ref_count       <= dat;
                        12'h014: reg_metric          <= dat;
                        12'h018: reg_threshold       <= dat;

                        default: begin
                            if (off >= 12'h100 && off <= 12'h13C) begin
                                int idx;
                                idx = (off - 12'h100) >> 2;
                                query_mem[idx]       <= dat;
                                query_written_by_axi <= 1'b1;
                            end else if (off >= 12'h200 && off <= 12'h23C) begin
                                int idx;
                                idx = (off - 12'h200) >> 2;
                                ref_mem[idx] <= dat;
                            end
                        end
                    endcase
                end
            end
        end
    end

endmodule : distance_axi_wrapper
`default_nettype wire
