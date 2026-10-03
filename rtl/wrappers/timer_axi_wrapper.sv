// =============================================================================
// File   : timer_axi_wrapper.sv
// Module : timer_axi_wrapper
// Purpose: AXI4-Lite Slave Wrapper for RISC-V 64-bit Timer IP.
//          Integrates OpenTitan timer_core engine (mtime/mtimecmp/prescaler).
//          Supports:
//            - Standard RISC-V 64-bit Timer registers (offsets 0x00-0x24)
//            - OpenTitan rv_timer register map compatibility (offsets 0x100-0x11C)
//            - 12-bit addressable memory space (0x2000_1000 - 0x2000_1FFF, m03)
//            - Full 5-channel AXI4-Lite handshake with ID tracking
//            - Configurable prescaler, step increment, and compare interrupts
//            - SlvErr and error code capture on unmapped accesses
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

module timer_axi_wrapper #(
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
    // Interrupt Output
    // -------------------------------------------------------------------------
    output logic                    timer_irq_o
);

    // =========================================================================
    // Registers & Internal State
    // =========================================================================
    logic        reg_ctrl_active;
    logic        reg_intr_en;
    logic        reg_intr_state;
    logic [11:0] reg_prescaler;
    logic [7:0]  reg_step;
    logic [63:0] reg_mtime;
    logic [63:0] reg_mtimecmp;
    logic [31:0] reg_error_code;

    // Timer core signals
    logic [63:0] timer_mtimecmp_arr [0:0];
    assign timer_mtimecmp_arr[0] = reg_mtimecmp;

    logic        timer_tick;
    logic [63:0] timer_mtime_next;
    logic [0:0]  timer_intr_raw;

    // Instantiate OpenTitan hardware timer engine
    timer_core #(
        .N(1)
    ) u_timer_core (
        .clk_i      (clk),
        .rst_ni     (rst_n),
        .active     (reg_ctrl_active),
        .prescaler  (reg_prescaler),
        .step       (reg_step),
        .tick       (timer_tick),
        .mtime_d    (timer_mtime_next),
        .mtime      (reg_mtime),
        .mtimecmp   (timer_mtimecmp_arr),
        .intr       (timer_intr_raw)
    );

    // Active timer interrupt
    assign timer_irq_o = reg_intr_state && reg_intr_en;

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

    // Address decoder validation
    function automatic logic is_valid_addr(input logic [11:0] off);
        case (off)
            12'h000, 12'h004, 12'h008, 12'h00C,
            12'h010, 12'h014, 12'h018, 12'h01C,
            12'h020, 12'h024: is_valid_addr = 1'b1;
            // OpenTitan rv_timer offsets
            12'h100, 12'h104, 12'h108, 12'h10C,
            12'h110, 12'h114, 12'h118, 12'h11C: is_valid_addr = 1'b1;
            default: is_valid_addr = 1'b0;
        endcase
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
                        12'h000: s_axi_rdata <= {31'b0, reg_ctrl_active};
                        12'h004: s_axi_rdata <= {30'b0, reg_intr_state, reg_ctrl_active};
                        12'h008: s_axi_rdata <= {31'b0, reg_intr_en};
                        12'h00C: s_axi_rdata <= {31'b0, reg_intr_state};
                        12'h010: s_axi_rdata <= {8'b0, reg_step, 4'b0, reg_prescaler};
                        12'h014: s_axi_rdata <= reg_mtime[31:0];
                        12'h018: s_axi_rdata <= reg_mtime[63:32];
                        12'h01C: s_axi_rdata <= reg_mtimecmp[31:0];
                        12'h020: s_axi_rdata <= reg_mtimecmp[63:32];
                        12'h024: s_axi_rdata <= reg_error_code;

                        // OpenTitan rv_timer register map
                        12'h100: s_axi_rdata <= {31'b0, reg_intr_en};
                        12'h104: s_axi_rdata <= {31'b0, reg_intr_state};
                        12'h108: s_axi_rdata <= 32'h0; // INTR_TEST reads back 0
                        12'h10C: s_axi_rdata <= {8'b0, reg_step, 4'b0, reg_prescaler};
                        12'h110: s_axi_rdata <= reg_mtime[31:0];
                        12'h114: s_axi_rdata <= reg_mtime[63:32];
                        12'h118: s_axi_rdata <= reg_mtimecmp[31:0];
                        12'h11C: s_axi_rdata <= reg_mtimecmp[63:32];

                        default: s_axi_rdata <= '0;
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
    // Core Timer Operation & Register Updates
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_ctrl_active <= 1'b0;
            reg_intr_en     <= 1'b0;
            reg_intr_state  <= 1'b0;
            reg_prescaler   <= 12'h0;
            reg_step        <= 8'h01;
            reg_mtime       <= 64'h0;
            reg_mtimecmp    <= 64'hFFFF_FFFF_FFFF_FFFF;
            reg_error_code  <= 32'h0;
        end else begin
            // Increment mtime when timer_core produces a tick
            if (timer_tick) begin
                reg_mtime <= timer_mtime_next;
            end

            // Latch interrupt event when compare match occurs
            if (timer_intr_raw[0]) begin
                reg_intr_state <= 1'b1;
            end

            // Process AXI Writes
            if (wr_execute) begin
                logic [11:0] off;
                logic [31:0] dat;

                off = aw_received ? awaddr_latched[11:0] : s_axi_awaddr[11:0];
                dat = w_received  ? wdata_latched        : s_axi_wdata;

                if (!is_valid_addr(off)) begin
                    reg_error_code <= 32'd1; // ILLEGAL_REG_ACCESS
                end else begin
                    case (off)
                        12'h000: begin // CTRL
                            if (dat[1]) begin // Soft reset
                                reg_ctrl_active <= 1'b0;
                                reg_intr_en     <= 1'b0;
                                reg_intr_state  <= 1'b0;
                                reg_prescaler   <= 12'h0;
                                reg_step        <= 8'h01;
                                reg_mtime       <= 64'h0;
                                reg_mtimecmp    <= 64'hFFFF_FFFF_FFFF_FFFF;
                                reg_error_code  <= 32'h0;
                            end else begin
                                reg_ctrl_active <= dat[0];
                            end
                        end

                        12'h004: begin // STATUS W1C
                            if (dat[1] && !timer_intr_raw[0]) reg_intr_state <= 1'b0;
                        end

                        12'h008, 12'h100: begin // INTR_ENABLE / INTR_ENABLE0
                            reg_intr_en <= dat[0];
                        end

                        12'h00C, 12'h104: begin // INTR_STATE / INTR_STATE0 (W1C)
                            if (dat[0] && !timer_intr_raw[0]) reg_intr_state <= 1'b0;
                        end

                        12'h108: begin // INTR_TEST0
                            if (dat[0]) reg_intr_state <= 1'b1;
                        end

                        12'h010, 12'h10C: begin // CFG / CFG0
                            reg_prescaler <= dat[11:0];
                            reg_step      <= (dat[23:16] == 8'h0) ? 8'h01 : dat[23:16];
                        end

                        12'h014, 12'h110: begin // TIMER_V_LOWER / TIMER_V_LOWER0
                            reg_mtime[31:0] <= dat;
                        end

                        12'h018, 12'h114: begin // TIMER_V_UPPER / TIMER_V_UPPER0
                            reg_mtime[63:32] <= dat;
                        end

                        12'h01C, 12'h118: begin // COMPARE_LOWER / COMPARE_LOWER0_0
                            reg_mtimecmp[31:0] <= dat;
                        end

                        12'h020, 12'h11C: begin // COMPARE_UPPER / COMPARE_UPPER0_0
                            reg_mtimecmp[63:32] <= dat;
                        end

                        default: ;
                    endcase
                end
            end
        end
    end

endmodule : timer_axi_wrapper
`default_nettype wire
