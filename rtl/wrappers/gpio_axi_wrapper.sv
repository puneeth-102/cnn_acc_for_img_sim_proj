// =============================================================================
// File   : gpio_axi_wrapper.sv
// Module : gpio_axi_wrapper
// Purpose: AXI4-Lite Slave Wrapper for PULP Platform GPIO IP.
//          Integrates PULP Platform 32-bit GPIO peripheral:
//            - 32 general-purpose digital I/O lines
//            - Input synchronizers (2 stages)
//            - Output direction control: Input, Push-Pull, Open-Drain0/1
//            - Atomic bit manipulation: Set (0x200), Clear (0x280), Toggle (0x300)
//            - Flexible edge & level interrupt generation:
//                * Rising edge, falling edge, high level, low level
//                * Global interrupt (level/pulse) and per-pin interrupts
//            - SlvErr and 0xDEAD_BEEF return on unmapped address accesses
// =============================================================================

`timescale 1ns/1ps
`default_nettype none

`include "register_interface/typedef.svh"
`include "register_interface/assign.svh"

module gpio_axi_wrapper #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32,
    parameter int STRB_WIDTH = (DATA_WIDTH/8),
    parameter int ID_WIDTH   = 8,
    parameter int GPIO_COUNT = 32
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
    // External GPIO Interface
    // -------------------------------------------------------------------------
    input  wire [GPIO_COUNT-1:0]    gpio_i,
    output logic [GPIO_COUNT-1:0]   gpio_o,
    output logic [GPIO_COUNT-1:0]   gpio_dir_o,       // 0: RX (input), 1: TX (output)
    output logic [GPIO_COUNT-1:0]   gpio_in_sync_o,   // Synchronized input signals

    // -------------------------------------------------------------------------
    // Interrupt Outputs
    // -------------------------------------------------------------------------
    output logic                    gpio_irq_o,       // Global interrupt output
    output logic [GPIO_COUNT-1:0]   gpio_pin_irq_o    // Per-pin interrupt outputs
);

    // =========================================================================
    // Local Parameters & Types
    // =========================================================================
    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    typedef logic [10:0] reg_addr_t;
    typedef logic [31:0] reg_data_t;
    typedef logic [3:0]  reg_strb_t;

    `REG_BUS_TYPEDEF_ALL(reg_bus, reg_addr_t, reg_data_t, reg_strb_t)

    reg_bus_req_t reg_req;
    reg_bus_rsp_t reg_rsp;

    // Address decoder validation function for PULP GPIO registers
    function automatic logic is_valid_gpio_addr(input logic [11:0] off);
        if (off[11]) return 1'b0; // Above 2KB offset in 4KB aperture
        case (off[10:0])
            11'h000, // INFO
            11'h004, // CFG
            11'h008, // GPIO_MODE_0
            11'h00C, // GPIO_MODE_1
            11'h080, // GPIO_EN
            11'h100, // GPIO_IN
            11'h180, // GPIO_OUT
            11'h200, // GPIO_SET
            11'h280, // GPIO_CLEAR
            11'h300, // GPIO_TOGGLE
            11'h380, // INTRPT_RISE_EN
            11'h400, // INTRPT_FALL_EN
            11'h480, // INTRPT_LVL_HIGH_EN
            11'h500, // INTRPT_LVL_LOW_EN
            11'h580, // INTRPT_STATUS
            11'h600, // INTRPT_RISE_STATUS
            11'h680, // INTRPT_FALL_STATUS
            11'h700, // INTRPT_LVL_HIGH_STATUS
            11'h780: // INTRPT_LVL_LOW_STATUS
                is_valid_gpio_addr = 1'b1;
            default:
                is_valid_gpio_addr = 1'b0;
        endcase
    endfunction

    // =========================================================================
    // Core PULP GPIO IP Instantiation
    // =========================================================================
    gpio #(
        .DATA_WIDTH (32),
        .reg_req_t  (reg_bus_req_t),
        .reg_rsp_t  (reg_bus_rsp_t)
    ) u_pulp_gpio (
        .clk_i                  (clk),
        .rst_ni                 (rst_n),
        .gpio_in                (gpio_i),
        .gpio_out               (gpio_o),
        .gpio_tx_en_o           (gpio_dir_o),
        .gpio_in_sync_o         (gpio_in_sync_o),
        .global_interrupt_o     (gpio_irq_o),
        .pin_level_interrupts_o (gpio_pin_irq_o),
        .reg_req_i              (reg_req),
        .reg_rsp_o              (reg_rsp)
    );

    // =========================================================================
    // AXI Write Channel FSM
    // =========================================================================
    typedef enum logic [1:0] {
        W_IDLE,
        W_EXEC,
        W_RESP
    } wstate_t;

    wstate_t wstate;

    logic [ADDR_WIDTH-1:0] awaddr_latched;
    logic [ID_WIDTH-1:0]   awid_latched;
    logic [DATA_WIDTH-1:0] wdata_latched;
    logic [STRB_WIDTH-1:0] wstrb_latched;
    logic                  aw_captured;
    logic                  w_captured;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wstate         <= W_IDLE;
            s_axi_awready  <= 1'b1;
            s_axi_wready   <= 1'b1;
            s_axi_bvalid   <= 1'b0;
            s_axi_bid      <= '0;
            s_axi_bresp    <= RESP_OKAY;
            awaddr_latched <= '0;
            awid_latched   <= '0;
            wdata_latched  <= '0;
            wstrb_latched  <= '0;
            aw_captured    <= 1'b0;
            w_captured     <= 1'b0;
        end else begin
            case (wstate)
                W_IDLE: begin
                    logic aw_now, w_now;
                    aw_now = aw_captured;
                    w_now  = w_captured;

                    // Capture AW
                    if (s_axi_awvalid && s_axi_awready) begin
                        awaddr_latched <= s_axi_awaddr;
                        awid_latched   <= s_axi_awid;
                        aw_captured    <= 1'b1;
                        s_axi_awready  <= 1'b0;
                        aw_now = 1'b1;
                    end

                    // Capture W
                    if (s_axi_wvalid && s_axi_wready) begin
                        wdata_latched  <= s_axi_wdata;
                        wstrb_latched  <= s_axi_wstrb;
                        w_captured     <= 1'b1;
                        s_axi_wready   <= 1'b0;
                        w_now = 1'b1;
                    end

                    if (aw_now && w_now) begin
                        s_axi_awready <= 1'b0;
                        s_axi_wready  <= 1'b0;
                        wstate        <= W_EXEC;
                    end
                end

                W_EXEC: begin
                    // 1 cycle for register write execution into u_pulp_gpio
                    s_axi_bvalid <= 1'b1;
                    s_axi_bid    <= awid_latched;
                    s_axi_bresp  <= (is_valid_gpio_addr(awaddr_latched[11:0]) && !reg_rsp.error) ? RESP_OKAY : RESP_SLVERR;
                    wstate       <= W_RESP;
                end

                W_RESP: begin
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid  <= 1'b0;
                        s_axi_awready <= 1'b1;
                        s_axi_wready  <= 1'b1;
                        aw_captured   <= 1'b0;
                        w_captured    <= 1'b0;
                        wstate        <= W_IDLE;
                    end
                end

                default: wstate <= W_IDLE;
            endcase
        end
    end

    // =========================================================================
    // AXI Read Channel FSM
    // =========================================================================
    typedef enum logic [1:0] {
        R_IDLE,
        R_WAIT_BUS,
        R_EXEC,
        R_RESP
    } rstate_t;

    rstate_t rstate;

    logic [ADDR_WIDTH-1:0] araddr_latched;
    logic [ID_WIDTH-1:0]   arid_latched;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rstate         <= R_IDLE;
            s_axi_arready  <= 1'b1;
            s_axi_rvalid   <= 1'b0;
            s_axi_rid      <= '0;
            s_axi_rdata    <= '0;
            s_axi_rresp    <= RESP_OKAY;
            s_axi_rlast    <= 1'b1;
            araddr_latched <= '0;
            arid_latched   <= '0;
        end else begin
            case (rstate)
                R_IDLE: begin
                    if (s_axi_arvalid && s_axi_arready) begin
                        araddr_latched <= s_axi_araddr;
                        arid_latched   <= s_axi_arid;
                        s_axi_arready  <= 1'b0;
                        if (wstate == W_EXEC) begin
                            rstate <= R_WAIT_BUS;
                        end else begin
                            rstate <= R_EXEC;
                        end
                    end
                end

                R_WAIT_BUS: begin
                    if (wstate != W_EXEC) begin
                        rstate <= R_EXEC;
                    end
                end

                R_EXEC: begin
                    s_axi_rvalid <= 1'b1;
                    s_axi_rid    <= arid_latched;
                    s_axi_rlast  <= 1'b1;

                    if (!is_valid_gpio_addr(araddr_latched[11:0]) || reg_rsp.error) begin
                        s_axi_rdata <= 32'hDEAD_BEEF;
                        s_axi_rresp <= RESP_SLVERR;
                    end else begin
                        s_axi_rdata <= reg_rsp.rdata;
                        s_axi_rresp <= RESP_OKAY;
                    end
                    rstate <= R_RESP;
                end

                R_RESP: begin
                    if (s_axi_rvalid && s_axi_rready) begin
                        s_axi_rvalid  <= 1'b0;
                        s_axi_arready <= 1'b1;
                        rstate        <= R_IDLE;
                    end
                end

                default: rstate <= R_IDLE;
            endcase
        end
    end

    // =========================================================================
    // Register Bus Request Arbitration
    // =========================================================================
    always_comb begin
        if (wstate == W_EXEC) begin
            reg_req.valid = 1'b1;
            reg_req.write = 1'b1;
            reg_req.addr  = awaddr_latched[10:0];
            reg_req.wdata = wdata_latched;
            reg_req.wstrb = wstrb_latched;
        end else if (rstate == R_EXEC) begin
            reg_req.valid = 1'b1;
            reg_req.write = 1'b0;
            reg_req.addr  = araddr_latched[10:0];
            reg_req.wdata = '0;
            reg_req.wstrb = 4'b1111;
        end else begin
            reg_req.valid = 1'b0;
            reg_req.write = 1'b0;
            reg_req.addr  = '0;
            reg_req.wdata = '0;
            reg_req.wstrb = '0;
        end
    end

endmodule
`default_nettype wire
