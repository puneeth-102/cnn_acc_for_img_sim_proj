// =============================================================================
// File   : cnn_axi_wrapper.sv
// Module : cnn_axi_wrapper
// Purpose: AXI4-Lite slave wrapper for cnn_top accelerator IP.
//          Implements the memory-mapped register interface defined in Section 6.1
//          of the CNN Anomaly Detection SoC Specification.
//
// Register Map (Base: 0x2000_3000, 4 KB region):
//   Offset  Name             R/W  Description
//   0x00    CTRL             R/W  bit0: CNN_START, bit1: CNN_RESET, bit2: CNN_IRQ_EN
//   0x04    STATUS           R    bit0: CNN_BUSY, bit1: CNN_DONE, bit2: CNN_ERROR (W1C on bit1)
//   0x08    IMAGE_BASE_ADDR  R/W  Input image memory base address (default: 0x1000_0000)
//   0x0C    WEIGHT_BASE_ADDR R/W  CNN weight memory base address (default: 0x1000_1000)
//   0x10    EMBED_BASE_ADDR  R/W  Generated embedding destination address (default: 0x1000_2000)
//   0x14    DIM_CFG          R/W  Dimension configuration (default: 0x0010_0010: 16x16)
//   0x18    EMBED_LEN        R/W  Embedding length (default: 16)
//   0x1C    ERROR_CODE       R    Error code (0: none, 1: unmapped/illegal access, 2: start while busy, 3: invalid cfg)
//   0x20..  EMBEDDING[0..15] R    Direct readback of 16-element 32-bit embedding results (0x20 - 0x5C)
//   0x100.. IMAGE_BUFFER     R/W  Input image pixel buffer (64 32-bit words = 256 bytes)
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module cnn_axi_wrapper #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32,
    parameter int STRB_WIDTH = (DATA_WIDTH/8),
    parameter int ID_WIDTH   = 8
)(
    input  wire                     clk,
    input  wire                     rst_n,      // Active-low synchronous/asynchronous reset

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
    // Interrupt & Hardware Direct Signals
    // -------------------------------------------------------------------------
    output logic                    accel_done_irq,
    output logic signed [31:0]      hw_embedding [0:15]
);

    // =========================================================================
    // Registers and Internal Storage
    // =========================================================================
    logic        reg_ctrl_irq_en;
    logic        reg_status_busy;
    logic        reg_status_done;
    logic        reg_status_error;

    logic [31:0] reg_image_base_addr;
    logic [31:0] reg_weight_base_addr;
    logic [31:0] reg_embed_base_addr;
    logic [31:0] reg_dim_cfg;
    logic [31:0] reg_embed_len;
    logic [31:0] reg_error_code;

    // Latched embedding result
    logic signed [31:0] latched_embedding [0:15];

    // Image pixel memory (256 pixels, INT8)
    logic signed [7:0] image_mem [0:255];

    // CNN weights and bias memories
    logic signed [7:0]  conv_weights_mem [0:35];
    logic signed [7:0]  fc_weights_mem   [0:15][0:195];
    logic signed [31:0] fc_bias_mem      [0:15];

    // CNN core control & status
    logic cnn_core_rst;
    logic cnn_core_start;
    logic cnn_core_busy;
    logic cnn_core_done;
    logic signed [31:0] cnn_core_embedding [0:15];

    // Assign hardware direct output
    assign hw_embedding = latched_embedding;

    // Interrupt output
    assign accel_done_irq = reg_status_done && reg_ctrl_irq_en;

    // =========================================================================
    // Instantiate Core CNN
    // =========================================================================
    cnn_top #(
        .IMAGE_SIZE  (16),
        .NUM_FILTERS (4),
        .DATA_WIDTH  (32),
        .FEATURE_W   (8),
        .EMBEDDING_W (32)
    ) u_cnn_top (
        .clk          (clk),
        .rst          (cnn_core_rst),
        .start        (cnn_core_start),
        .image        (image_mem),
        .conv_weights (conv_weights_mem),
        .fc_weights   (fc_weights_mem),
        .fc_bias      (fc_bias_mem),
        .embedding    (cnn_core_embedding),
        .busy         (cnn_core_busy),
        .done         (cnn_core_done)
    );

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

    // Response states
    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    // Address decode helper for 4 KB aperture
    wire [11:0] wr_offset = awaddr_latched[11:0];
    wire [11:0] rd_offset = araddr_latched[11:0];

    // Check if address is valid
    function automatic logic is_valid_addr(input logic [11:0] off);
        if (off <= 12'h01C) is_valid_addr = 1'b1;                                  // Registers 0x00 - 0x1C
        else if (off >= 12'h020 && off <= 12'h05C && (off[1:0] == 2'b00)) is_valid_addr = 1'b1; // Embedding results 0x20 - 0x5C
        else if (off >= 12'h100 && off <= 12'h1FC && (off[1:0] == 2'b00)) is_valid_addr = 1'b1; // Image buffer 0x100 - 0x1FC
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

    // Detect write execute cycle
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

                // Read decoding
                if (!is_valid_addr(s_axi_araddr[11:0])) begin
                    s_axi_rresp <= RESP_SLVERR;
                    s_axi_rdata <= 32'hDEAD_BEEF;
                end else begin
                    s_axi_rresp <= RESP_OKAY;
                    case (s_axi_araddr[11:0])
                        12'h000: s_axi_rdata <= {29'b0, reg_ctrl_irq_en, 2'b00};
                        12'h004: s_axi_rdata <= {29'b0, reg_status_error, reg_status_done, reg_status_busy};
                        12'h008: s_axi_rdata <= reg_image_base_addr;
                        12'h00C: s_axi_rdata <= reg_weight_base_addr;
                        12'h010: s_axi_rdata <= reg_embed_base_addr;
                        12'h014: s_axi_rdata <= reg_dim_cfg;
                        12'h018: s_axi_rdata <= reg_embed_len;
                        12'h01C: s_axi_rdata <= reg_error_code;
                        default: begin
                            if (s_axi_araddr[11:0] >= 12'h020 && s_axi_araddr[11:0] <= 12'h05C) begin
                                int emb_idx;
                                emb_idx = (s_axi_araddr[11:0] - 12'h020) >> 2;
                                s_axi_rdata <= latched_embedding[emb_idx];
                            end else if (s_axi_araddr[11:0] >= 12'h100 && s_axi_araddr[11:0] <= 12'h1FC) begin
                                int word_idx;
                                word_idx = (s_axi_araddr[11:0] - 12'h100) >> 2;
                                s_axi_rdata <= {image_mem[word_idx*4 + 3],
                                                image_mem[word_idx*4 + 2],
                                                image_mem[word_idx*4 + 1],
                                                image_mem[word_idx*4 + 0]};
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
    // Core Sequencing & Register Management
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_ctrl_irq_en     <= 1'b0;
            reg_status_busy     <= 1'b0;
            reg_status_done     <= 1'b0;
            reg_status_error    <= 1'b0;

            reg_image_base_addr  <= 32'h1000_0000;
            reg_weight_base_addr <= 32'h1000_1000;
            reg_embed_base_addr  <= 32'h1000_2000;
            reg_dim_cfg          <= 32'h0010_0010; // 16x16
            reg_embed_len        <= 32'd16;
            reg_error_code       <= 32'd0;

            cnn_core_rst         <= 1'b1;
            cnn_core_start       <= 1'b0;

            for (int k = 0; k < 16; k = k + 1)
                latched_embedding[k] <= 32'sd0;

            // Default image samples: all 1
            for (int p = 0; p < 256; p = p + 1)
                image_mem[p] <= 8'sd1;

            // Default conv weights: all 1
            for (int w = 0; w < 36; w = w + 1)
                conv_weights_mem[w] <= 8'sd1;

            // Default FC weights: all 1
            for (int n = 0; n < 16; n = n + 1)
                for (int f = 0; f < 196; f = f + 1)
                    fc_weights_mem[n][f] <= 8'sd1;

            // Default FC biases: all 0
            for (int b = 0; b < 16; b = b + 1)
                fc_bias_mem[b] <= 32'sd0;

        end else begin
            // Default pulse signals
            cnn_core_start <= 1'b0;
            cnn_core_rst   <= 1'b0;

            // Track CNN core completion
            if (cnn_core_done) begin
                reg_status_busy <= 1'b0;
                reg_status_done <= 1'b1;
                for (int k = 0; k < 16; k = k + 1) begin
                    latched_embedding[k] <= cnn_core_embedding[k];
                end
            end

            // Process AXI Register Writes
            if (wr_execute) begin
                logic [11:0] off;
                logic [31:0] dat;
                logic [3:0]  strb;

                off  = aw_received ? awaddr_latched[11:0] : s_axi_awaddr[11:0];
                dat  = w_received  ? wdata_latched        : s_axi_wdata;
                strb = w_received  ? wstrb_latched        : s_axi_wstrb;

                if (!is_valid_addr(off)) begin
                    // Section 9: Unsupported offset -> Set ERROR status; return error response
                    reg_status_error <= 1'b1;
                    reg_error_code   <= 32'd1; // 1: ILLEGAL_REG_ACCESS
                end else begin
                    case (off)
                        12'h000: begin // CTRL
                            // Bit 1: CNN_RESET
                            if (dat[1]) begin
                                cnn_core_rst     <= 1'b1;
                                reg_status_busy  <= 1'b0;
                                reg_status_done  <= 1'b0;
                                reg_status_error <= 1'b0;
                                reg_error_code   <= 32'd0;
                                reg_ctrl_irq_en  <= 1'b0;
                            end else if (reg_status_busy || cnn_core_busy) begin
                                // Section 9: START written while BUSY=1
                                if (dat[0]) begin
                                    reg_status_error <= 1'b1;
                                    reg_error_code   <= 32'd2; // 2: BUSY_START
                                end
                            end else begin
                                // Bit 2: IRQ_EN
                                reg_ctrl_irq_en <= dat[2];

                                // Bit 0: CNN_START
                                if (dat[0]) begin
                                    if (reg_dim_cfg != 32'h0010_0010 || reg_embed_len != 32'd16) begin
                                        reg_status_error <= 1'b1;
                                        reg_error_code   <= 32'd3; // 3: INVALID_CONFIG
                                    end else begin
                                        reg_status_busy  <= 1'b1;
                                        reg_status_done  <= 1'b0;
                                        reg_status_error <= 1'b0;
                                        reg_error_code   <= 32'd0;
                                        cnn_core_start   <= 1'b1;
                                    end
                                end
                            end
                        end

                        12'h004: begin // STATUS write-1-to-clear
                            if (dat[1]) reg_status_done  <= 1'b0;
                            if (dat[2]) reg_status_error <= 1'b0;
                        end

                        12'h008: reg_image_base_addr  <= dat;
                        12'h00C: reg_weight_base_addr <= dat;
                        12'h010: reg_embed_base_addr  <= dat;
                        12'h014: reg_dim_cfg          <= dat;
                        12'h018: reg_embed_len        <= dat;

                        default: begin
                            // Image buffer writes (0x100 - 0x1FC)
                            if (off >= 12'h100 && off <= 12'h1FC) begin
                                int word_idx;
                                word_idx = (off - 12'h100) >> 2;
                                if (strb[0]) image_mem[word_idx*4 + 0] <= dat[7:0];
                                if (strb[1]) image_mem[word_idx*4 + 1] <= dat[15:8];
                                if (strb[2]) image_mem[word_idx*4 + 2] <= dat[23:16];
                                if (strb[3]) image_mem[word_idx*4 + 3] <= dat[31:24];
                            end
                        end
                    endcase
                end
            end
        end
    end

endmodule : cnn_axi_wrapper
`default_nettype wire
