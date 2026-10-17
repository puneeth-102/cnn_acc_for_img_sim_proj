// =============================================================================
// File   : dma_axi_wrapper.sv
// Module : dma_axi_wrapper
// Purpose: High-performance, fully synthesizable 32-bit AXI4 Direct Memory Access (DMA)
//          controller implementing the official Section 6.3 and Section 11
//          specification of the CNN Anomaly Detection SoC.
//
// Register Map (Base: 0x2000_5000, 4 KB region):
//   Offset  Name        R/W  Description
//   0x00    CTRL        R/W  bit0: DMA_START, bit1: DMA_RESET, bit2: DMA_IRQ_EN
//   0x04    STATUS      R    bit0: DMA_BUSY, bit1: DMA_DONE, bit2: DMA_ERROR (W1C)
//   0x08    SRC_ADDR    R/W  Source memory address
//   0x0C    DST_ADDR    R/W  Destination memory address
//   0x10    LENGTH      R/W  Transfer length in bytes
//   0x14    ERROR_CODE  R    DMA error code (0: none, 1: bad len/align, 2: rd err, 3: wr err, 4: busy start)
//
// Bus Interfaces:
//   - Slave Port  : AXI4-Lite Slave at 0x2000_5000 (connected to Interconnect m07)
//   - Master Port : AXI4 Master (connected to Interconnect s01)
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module dma_axi_wrapper #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32,
    parameter int STRB_WIDTH = (DATA_WIDTH/8),
    parameter int ID_WIDTH   = 8
)(
    input  wire                     clk,
    input  wire                     rst_n,      // Active-low synchronous/asynchronous reset

    // -------------------------------------------------------------------------
    // AXI Slave Interface (CSR Configuration @ 0x2000_5000)
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
    // AXI Master Interface (Bulk Transfers via Interconnect s01)
    // -------------------------------------------------------------------------
    // Master Write Address Channel
    output logic [ID_WIDTH-1:0]     m_axi_awid,
    output logic [ADDR_WIDTH-1:0]   m_axi_awaddr,
    output logic [7:0]              m_axi_awlen,
    output logic [2:0]              m_axi_awsize,
    output logic [1:0]              m_axi_awburst,
    output logic                    m_axi_awlock,
    output logic [3:0]              m_axi_awcache,
    output logic [2:0]              m_axi_awprot,
    output logic [3:0]              m_axi_awqos,
    output logic                    m_axi_awvalid,
    input  wire                     m_axi_awready,

    // Master Write Data Channel
    output logic [DATA_WIDTH-1:0]   m_axi_wdata,
    output logic [STRB_WIDTH-1:0]   m_axi_wstrb,
    output logic                    m_axi_wlast,
    output logic                    m_axi_wvalid,
    input  wire                     m_axi_wready,

    // Master Write Response Channel
    input  wire  [ID_WIDTH-1:0]     m_axi_bid,
    input  wire  [1:0]              m_axi_bresp,
    input  wire                     m_axi_bvalid,
    output logic                    m_axi_bready,

    // Master Read Address Channel
    output logic [ID_WIDTH-1:0]     m_axi_arid,
    output logic [ADDR_WIDTH-1:0]   m_axi_araddr,
    output logic [7:0]              m_axi_arlen,
    output logic [2:0]              m_axi_arsize,
    output logic [1:0]              m_axi_arburst,
    output logic                    m_axi_arlock,
    output logic [3:0]              m_axi_arcache,
    output logic [2:0]              m_axi_arprot,
    output logic [3:0]              m_axi_arqos,
    output logic                    m_axi_arvalid,
    input  wire                     m_axi_arready,

    // Master Read Data Channel
    input  wire  [ID_WIDTH-1:0]     m_axi_rid,
    input  wire  [DATA_WIDTH-1:0]   m_axi_rdata,
    input  wire  [1:0]              m_axi_rresp,
    input  wire                     m_axi_rlast,
    input  wire                     m_axi_rvalid,
    output logic                    m_axi_rready,

    // -------------------------------------------------------------------------
    // Dedicated Signals & Interrupt (Specification Section 7 & 8)
    // -------------------------------------------------------------------------
    output logic                    dma_done_irq,
    output logic                    dma_busy,
    output logic                    dma_done,
    output logic                    dma_error
);

    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;
    localparam logic [1:0] RESP_DECERR = 2'b11;

    // =========================================================================
    // Control & Status Registers
    // =========================================================================
    logic        reg_ctrl_irq_en;
    logic        reg_status_busy;
    logic        reg_status_done;
    logic        reg_status_error;
    logic [31:0] reg_src_addr;
    logic [31:0] reg_dst_addr;
    logic [31:0] reg_length;
    logic [31:0] reg_error_code;

    logic        start_req;
    logic        soft_reset_req;

    // Assign hardware direct output flags
    assign dma_busy  = reg_status_busy;
    assign dma_done  = reg_status_done;
    assign dma_error = reg_status_error;

    // =========================================================================
    // Slave AXI-Lite Read Channel
    // =========================================================================
    logic [ID_WIDTH-1:0] s_arid_q;
    logic [11:0]         s_aroffset_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_arready <= 1'b1;
            s_axi_rvalid  <= 1'b0;
            s_axi_rid     <= '0;
            s_axi_rdata   <= '0;
            s_axi_rresp   <= RESP_OKAY;
            s_axi_rlast   <= 1'b0;
            s_arid_q      <= '0;
            s_aroffset_q  <= '0;
        end else begin
            // Clear rvalid when acknowledged
            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid  <= 1'b0;
                s_axi_rlast   <= 1'b0;
                s_axi_arready <= 1'b1;
            end

            // Capture read address and respond
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_arready <= 1'b0;
                s_axi_rvalid  <= 1'b1;
                s_axi_rlast   <= 1'b1;
                s_axi_rid     <= s_axi_arid;
                s_axi_rresp   <= RESP_OKAY;

                case (s_axi_araddr[11:0])
                    12'h000: s_axi_rdata <= {29'h0, reg_ctrl_irq_en, 1'b0, 1'b0};
                    12'h004: s_axi_rdata <= {29'h0, reg_status_error, reg_status_done, reg_status_busy};
                    12'h008: s_axi_rdata <= reg_src_addr;
                    12'h00C: s_axi_rdata <= reg_dst_addr;
                    12'h010: s_axi_rdata <= reg_length;
                    12'h014: s_axi_rdata <= reg_error_code;
                    default: s_axi_rdata <= 32'h0000_0000;
                endcase
            end
        end
    end

    // =========================================================================
    // Slave AXI-Lite Write Channel
    // =========================================================================
    logic [ID_WIDTH-1:0] s_awid_q;
    logic [11:0]         s_awoffset_q;
    logic                aw_latched;

    wire s_aw_hs = s_axi_awvalid && s_axi_awready;
    wire s_w_hs  = s_axi_wvalid  && s_axi_wready;

    // Internal pulse wires
    logic fsm_start_pulse;
    logic fsm_error_busy_start;
    // Write-1-to-clear request pulses for STATUS register
    logic w1c_done_req;
    logic w1c_error_req;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_awready   <= 1'b1;
            s_axi_wready    <= 1'b1;
            s_axi_bvalid    <= 1'b0;
            s_axi_bid       <= '0;
            s_axi_bresp     <= RESP_OKAY;
            aw_latched      <= 1'b0;
            s_awid_q        <= '0;
            s_awoffset_q    <= '0;
            reg_ctrl_irq_en <= 1'b0;
            reg_src_addr    <= 32'h1000_0000; // Default: DMEM start
            reg_dst_addr    <= 32'h2000_3100; // Default: CNN input buffer
            reg_length      <= 32'h0000_0000;
            start_req            <= 1'b0;
            soft_reset_req       <= 1'b0;
            fsm_error_busy_start <= 1'b0;
            w1c_done_req         <= 1'b0;
            w1c_error_req        <= 1'b0;
        end else begin
            start_req            <= 1'b0;
            soft_reset_req       <= 1'b0;
            fsm_error_busy_start <= 1'b0;
            w1c_done_req         <= 1'b0;
            w1c_error_req        <= 1'b0;

            // Clear bvalid on handshake
            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid  <= 1'b0;
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
            end

            // Capture AW if it arrives first
            if (s_aw_hs && !s_w_hs) begin
                s_awid_q      <= s_axi_awid;
                s_awoffset_q  <= s_axi_awaddr[11:0];
                aw_latched    <= 1'b1;
                s_axi_awready <= 1'b0;
            end

            // Process write data when available
            if ((s_aw_hs && s_w_hs) || (aw_latched && s_w_hs)) begin
                logic [11:0] write_offset;
                logic [ID_WIDTH-1:0] write_id;

                write_offset = aw_latched ? s_awoffset_q : s_axi_awaddr[11:0];
                write_id     = aw_latched ? s_awid_q     : s_axi_awid;

                s_axi_bvalid  <= 1'b1;
                s_axi_bid     <= write_id;
                s_axi_bresp   <= RESP_OKAY;
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
                aw_latched    <= 1'b0;

                case (write_offset)
                    12'h000: begin // CTRL
                        if (s_axi_wstrb[0]) begin
                            // bit0: DMA_START
                            if (s_axi_wdata[0]) begin
                                if (reg_status_busy) begin
                                    fsm_error_busy_start <= 1'b1; // Section 9: busy start
                                end else begin
                                    start_req <= 1'b1;
                                end
                            end
                            // bit1: DMA_RESET
                            if (s_axi_wdata[1]) begin
                                soft_reset_req <= 1'b1;
                            end
                            // bit2: DMA_IRQ_EN
                            reg_ctrl_irq_en <= s_axi_wdata[2];
                        end
                    end

                    12'h004: begin // STATUS: Write-1-to-clear on DONE / ERROR
                        if (s_axi_wstrb[0]) begin
                            if (s_axi_wdata[1]) w1c_done_req  <= 1'b1;
                            if (s_axi_wdata[2]) w1c_error_req <= 1'b1;
                        end
                    end

                    12'h008: begin // SRC_ADDR
                        for (int i = 0; i < 4; i++) begin
                            if (s_axi_wstrb[i]) reg_src_addr[i*8 +: 8] <= s_axi_wdata[i*8 +: 8];
                        end
                    end

                    12'h00C: begin // DST_ADDR
                        for (int i = 0; i < 4; i++) begin
                            if (s_axi_wstrb[i]) reg_dst_addr[i*8 +: 8] <= s_axi_wdata[i*8 +: 8];
                        end
                    end

                    12'h010: begin // LENGTH
                        for (int i = 0; i < 4; i++) begin
                            if (s_axi_wstrb[i]) reg_length[i*8 +: 8] <= s_axi_wdata[i*8 +: 8];
                        end
                    end

                    default: begin
                        // Unmapped access within 4KB region
                    end
                endcase
            end
        end
    end

    // =========================================================================
    // Master Transfer Engine State Machine (Section 11)
    // IDLE -> ARBITRATE -> READ -> WRITE -> COMPLETE / ERROR
    // =========================================================================
    typedef enum logic [2:0] {
        DMA_ST_IDLE,
        DMA_ST_READ_ADDR,
        DMA_ST_READ_DATA,
        DMA_ST_WRITE_ADDR_DATA,
        DMA_ST_WRITE_RESP,
        DMA_ST_COMPLETE,
        DMA_ST_ERROR
    } dma_state_t;

    dma_state_t state;

    logic [31:0] cur_src_addr;
    logic [31:0] cur_dst_addr;
    logic [31:0] bytes_remaining;
    logic [31:0] hold_data;

    logic        aw_handshaked;
    logic        w_handshaked;

    // Static master signal tie-offs
    assign m_axi_arid    = 8'h01;
    assign m_axi_arlen   = 8'd0;    // Single beat per word
    assign m_axi_arsize  = 3'b010;  // 4 bytes (32-bit word)
    assign m_axi_arburst = 2'b01;   // INCR
    assign m_axi_arlock  = 1'b0;
    assign m_axi_arcache = 4'b0000;
    assign m_axi_arprot  = 3'b000;
    assign m_axi_arqos   = 4'b0000;

    assign m_axi_awid    = 8'h01;
    assign m_axi_awlen   = 8'd0;    // Single beat per word
    assign m_axi_awsize  = 3'b010;  // 4 bytes (32-bit word)
    assign m_axi_awburst = 2'b01;   // INCR
    assign m_axi_awlock  = 1'b0;
    assign m_axi_awcache = 4'b0000;
    assign m_axi_awprot  = 3'b000;
    assign m_axi_awqos   = 4'b0000;

    assign m_axi_wlast   = 1'b1;
    assign m_axi_wdata   = hold_data;

    // Write strobes depending on remaining byte count on partial final word
    always_comb begin
        if (bytes_remaining >= 4) begin
            m_axi_wstrb = 4'b1111;
        end else if (bytes_remaining == 3) begin
            m_axi_wstrb = 4'b0111;
        end else if (bytes_remaining == 2) begin
            m_axi_wstrb = 4'b0011;
        end else if (bytes_remaining == 1) begin
            m_axi_wstrb = 4'b0001;
        end else begin
            m_axi_wstrb = 4'b0000;
        end
    end

    // Sequential Engine Process
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= DMA_ST_IDLE;
            m_axi_arvalid    <= 1'b0;
            m_axi_araddr     <= '0;
            m_axi_rready     <= 1'b0;
            m_axi_awvalid    <= 1'b0;
            m_axi_awaddr     <= '0;
            m_axi_wvalid     <= 1'b0;
            m_axi_bready     <= 1'b0;
            aw_handshaked    <= 1'b0;
            w_handshaked     <= 1'b0;
            cur_src_addr     <= '0;
            cur_dst_addr     <= '0;
            bytes_remaining  <= '0;
            hold_data        <= '0;
            reg_status_busy  <= 1'b0;
            reg_status_done  <= 1'b0;
            reg_status_error <= 1'b0;
            reg_error_code   <= 32'd0;
            dma_done_irq     <= 1'b0;
        end else if (soft_reset_req) begin
            // Synchronous soft reset (bit 1 of CTRL)
            state            <= DMA_ST_IDLE;
            m_axi_arvalid    <= 1'b0;
            m_axi_rready     <= 1'b0;
            m_axi_awvalid    <= 1'b0;
            m_axi_wvalid     <= 1'b0;
            m_axi_bready     <= 1'b0;
            aw_handshaked    <= 1'b0;
            w_handshaked     <= 1'b0;
            reg_status_busy  <= 1'b0;
            reg_status_done  <= 1'b0;
            reg_status_error <= 1'b0;
            reg_error_code   <= 32'd0;
            dma_done_irq     <= 1'b0;
        end else begin
            dma_done_irq <= 1'b0; // Default pulse behavior

            // Write-1-to-clear handling for STATUS register bits
            if (w1c_done_req) begin
                reg_status_done <= 1'b0;
            end
            if (w1c_error_req) begin
                reg_status_error <= 1'b0;
            end

            // Latch error if start was attempted while busy
            if (fsm_error_busy_start) begin
                reg_status_error <= 1'b1;
                reg_error_code   <= 32'd4; // Error 4: busy start violation
            end

            case (state)
                DMA_ST_IDLE: begin
                    m_axi_arvalid <= 1'b0;
                    m_axi_rready  <= 1'b0;
                    m_axi_awvalid <= 1'b0;
                    m_axi_wvalid  <= 1'b0;
                    m_axi_bready  <= 1'b0;

                    if (start_req) begin
                        // Validate transfer parameters (Section 9)
                        if (reg_length == 32'd0) begin
                            reg_status_busy  <= 1'b0;
                            reg_status_error <= 1'b1;
                            reg_error_code   <= 32'd1; // Error 1: invalid length
                            state            <= DMA_ST_ERROR;
                        end else begin
                            cur_src_addr     <= reg_src_addr;
                            cur_dst_addr     <= reg_dst_addr;
                            bytes_remaining  <= reg_length;
                            reg_status_busy  <= 1'b1;
                            reg_status_done  <= 1'b0;
                            reg_status_error <= 1'b0;
                            reg_error_code   <= 32'd0;
                            state            <= DMA_ST_READ_ADDR;
                        end
                    end
                end

                DMA_ST_READ_ADDR: begin
                    m_axi_arvalid <= 1'b1;
                    m_axi_araddr  <= cur_src_addr;

                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        state         <= DMA_ST_READ_DATA;
                    end
                end

                DMA_ST_READ_DATA: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        m_axi_rready <= 1'b0;

                        if (m_axi_rresp != RESP_OKAY) begin
                            // Bus Read Error (SLVERR or DECERR)
                            reg_status_busy  <= 1'b0;
                            reg_status_error <= 1'b1;
                            reg_error_code   <= 32'd2; // Error 2: Bus read error
                            state            <= DMA_ST_ERROR;
                        end else begin
                            hold_data     <= m_axi_rdata;
                            m_axi_awvalid <= 1'b1;
                            m_axi_awaddr  <= cur_dst_addr;
                            m_axi_wvalid  <= 1'b1;
                            aw_handshaked <= 1'b0;
                            w_handshaked  <= 1'b0;
                            state         <= DMA_ST_WRITE_ADDR_DATA;
                        end
                    end
                end

                DMA_ST_WRITE_ADDR_DATA: begin
                    if (m_axi_awvalid && m_axi_awready) begin
                        m_axi_awvalid <= 1'b0;
                        aw_handshaked <= 1'b1;
                    end
                    if (m_axi_wvalid && m_axi_wready) begin
                        m_axi_wvalid <= 1'b0;
                        w_handshaked <= 1'b1;
                    end

                    // Check if both address and data write phases completed
                    if ((aw_handshaked || (m_axi_awvalid && m_axi_awready)) &&
                        (w_handshaked  || (m_axi_wvalid  && m_axi_wready))) begin
                        m_axi_awvalid <= 1'b0;
                        m_axi_wvalid  <= 1'b0;
                        m_axi_bready  <= 1'b1;
                        state         <= DMA_ST_WRITE_RESP;
                    end
                end

                DMA_ST_WRITE_RESP: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 1'b0;

                        if (m_axi_bresp != RESP_OKAY) begin
                            // Bus Write Error (SLVERR or DECERR)
                            reg_status_busy  <= 1'b0;
                            reg_status_error <= 1'b1;
                            reg_error_code   <= 32'd3; // Error 3: Bus write error
                            state            <= DMA_ST_ERROR;
                        end else begin
                            // Advance source and destination pointers
                            cur_src_addr <= cur_src_addr + 32'd4;
                            cur_dst_addr <= cur_dst_addr + 32'd4;

                            if (bytes_remaining <= 32'd4) begin
                                bytes_remaining <= 32'd0;
                                state           <= DMA_ST_COMPLETE;
                            end else begin
                                bytes_remaining <= bytes_remaining - 32'd4;
                                state           <= DMA_ST_READ_ADDR;
                            end
                        end
                    end
                end

                DMA_ST_COMPLETE: begin
                    reg_status_busy <= 1'b0;
                    reg_status_done <= 1'b1;

                    if (reg_ctrl_irq_en) begin
                        dma_done_irq <= 1'b1; // Raise completion interrupt (Section 8)
                    end
                    state <= DMA_ST_IDLE;
                end

                DMA_ST_ERROR: begin
                    reg_status_busy  <= 1'b0;
                    reg_status_error <= 1'b1;
                    state            <= DMA_ST_IDLE;
                end

                default: begin
                    state <= DMA_ST_IDLE;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
