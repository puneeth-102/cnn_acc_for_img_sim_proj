// ============================================================
// aes_reg_map.v
// AES register map and AES core control/status logic.
//
// Register map (byte addresses, 32-bit wide):
//   0x00  CPSR      R/W  [0]=LD [1]=DONE [2]=KLD [3]=KDONE [4]=RST [5]=MODE
//   0x04  KEY0      R/W  key[31:0]
//   0x08  KEY1      R/W  key[63:32]
//   0x0C  KEY2      R/W  key[95:64]
//   0x10  KEY3      R/W  key[127:96]
//   0x14  TEXT_IN0  R/W  text_in[31:0]
//   0x18  TEXT_IN1  R/W  text_in[63:32]
//   0x1C  TEXT_IN2  R/W  text_in[95:64]
//   0x20  TEXT_IN3  R/W  text_in[127:96]
//   0x24  TEXT_OUT0 R    text_out[31:0]
//   0x28  TEXT_OUT1 R    text_out[63:32]
//   0x2C  TEXT_OUT2 R    text_out[95:64]
//   0x30  TEXT_OUT3 R    text_out[127:96]
// ============================================================
`include "timescale.v"

module aes_reg_map (
    input  wire        clk,
    input  wire        resetn,     // active-low reset (from AXI aresetn)

    // Register bus from AXI slave
    input  wire        wr_en,
    input  wire [5:0]  wr_addr,
    input  wire [31:0] wr_data,
    input  wire [3:0]  wr_strb,

    input  wire        rd_en,
    input  wire [5:0]  rd_addr,
    output reg  [31:0] rd_data,

    // AES core connections
    output wire        aes_rst,       // active-low, fed to both cores
    output reg         aes_ld,        // one-cycle pulse -> ld
    output reg         aes_kld,       // one-cycle pulse -> kld (inv core)
    output wire        aes_mode,      // 0=enc, 1=dec
    output wire [127:0] aes_key,
    output wire [127:0] aes_text_in,
    input  wire [127:0] aes_enc_out,  // from cipher core
    input  wire [127:0] aes_dec_out,  // from inv cipher core
    input  wire        aes_done_in,   // latched done (enc or dec, from top)
    // kdone latched in top, passed here for CPSR readback
    input  wire        aes_kdone_in   // latched kdone from top
);

// -------------------------------------------------------
// Address decode constants
// -------------------------------------------------------
localparam ADDR_CPSR     = 6'h00;
localparam ADDR_KEY0     = 6'h04;
localparam ADDR_KEY1     = 6'h08;
localparam ADDR_KEY2     = 6'h0C;
localparam ADDR_KEY3     = 6'h10;
localparam ADDR_TXIN0    = 6'h14;
localparam ADDR_TXIN1    = 6'h18;
localparam ADDR_TXIN2    = 6'h1C;
localparam ADDR_TXIN3    = 6'h20;
localparam ADDR_TXOUT0   = 6'h24;
localparam ADDR_TXOUT1   = 6'h28;
localparam ADDR_TXOUT2   = 6'h2C;
localparam ADDR_TXOUT3   = 6'h30;

// -------------------------------------------------------
// Storage registers
// -------------------------------------------------------
reg [31:0] KEY0, KEY1, KEY2, KEY3;
reg [31:0] TXIN0, TXIN1, TXIN2, TXIN3;

// CPSR storage (writable fields only: RST, MODE)
// LD and KLD generate one-cycle pulses and are not stored
reg        cpsr_rst;   // CPSR[4]     mapped to aes_rst (active-low: 0=reset)
reg        cpsr_mode;  // CPSR[5]

// -------------------------------------------------------
// AES core outputs visible as registers
// -------------------------------------------------------
wire [31:0] TXOUT0 = aes_mode ? aes_dec_out[31:0]   : aes_enc_out[31:0];
wire [31:0] TXOUT1 = aes_mode ? aes_dec_out[63:32]  : aes_enc_out[63:32];
wire [31:0] TXOUT2 = aes_mode ? aes_dec_out[95:64]  : aes_enc_out[95:64];
wire [31:0] TXOUT3 = aes_mode ? aes_dec_out[127:96] : aes_enc_out[127:96];

wire        done_live  = aes_done_in;
wire        kdone_live = aes_kdone_in;

// -------------------------------------------------------
// Output assignments
// -------------------------------------------------------
assign aes_key      = {KEY3, KEY2, KEY1, KEY0};
assign aes_text_in  = {TXIN3, TXIN2, TXIN1, TXIN0};
assign aes_rst      = cpsr_rst;    // 1=normal, 0=reset (active-low)
assign aes_mode     = cpsr_mode;

// -------------------------------------------------------
// WRITE logic
// -------------------------------------------------------
// Helper: apply write-strobes to a 32-bit register
function [31:0] strobe_write;
    input [31:0] orig;
    input [31:0] wdata;
    input [3:0]  strb;
    begin
        strobe_write[7:0]   = strb[0] ? wdata[7:0]   : orig[7:0];
        strobe_write[15:8]  = strb[1] ? wdata[15:8]  : orig[15:8];
        strobe_write[23:16] = strb[2] ? wdata[23:16] : orig[23:16];
        strobe_write[31:24] = strb[3] ? wdata[31:24] : orig[31:24];
    end
endfunction

always @(posedge clk) begin
    if (!resetn) begin
        KEY0       <= 32'd0;  KEY1  <= 32'd0;
        KEY2       <= 32'd0;  KEY3  <= 32'd0;
        TXIN0      <= 32'd0;  TXIN1 <= 32'd0;
        TXIN2      <= 32'd0;  TXIN3 <= 32'd0;
        cpsr_rst   <= 1'b1;   // deassert AES reset by default after sync reset
        cpsr_mode  <= 1'b0;
        aes_ld     <= 1'b0;
        aes_kld    <= 1'b0;
    end else begin
        // Default: clear one-cycle pulses every cycle
        aes_ld  <= 1'b0;
        aes_kld <= 1'b0;

        if (wr_en) begin
            case (wr_addr)
                ADDR_CPSR: begin
                    // RST  bit[4]: store it
                    if (wr_strb[0]) cpsr_rst  <= wr_data[4];
                    // MODE bit[5]
                    if (wr_strb[0]) cpsr_mode <= wr_data[5];
                    // LD   bit[0]: generate one-cycle pulse
                    if (wr_strb[0] && wr_data[0]) aes_ld  <= 1'b1;
                    // KLD  bit[2]: generate one-cycle pulse
                    if (wr_strb[0] && wr_data[2]) aes_kld <= 1'b1;
                end
                ADDR_KEY0:  KEY0  <= strobe_write(KEY0,  wr_data, wr_strb);
                ADDR_KEY1:  KEY1  <= strobe_write(KEY1,  wr_data, wr_strb);
                ADDR_KEY2:  KEY2  <= strobe_write(KEY2,  wr_data, wr_strb);
                ADDR_KEY3:  KEY3  <= strobe_write(KEY3,  wr_data, wr_strb);
                ADDR_TXIN0: TXIN0 <= strobe_write(TXIN0, wr_data, wr_strb);
                ADDR_TXIN1: TXIN1 <= strobe_write(TXIN1, wr_data, wr_strb);
                ADDR_TXIN2: TXIN2 <= strobe_write(TXIN2, wr_data, wr_strb);
                ADDR_TXIN3: TXIN3 <= strobe_write(TXIN3, wr_data, wr_strb);
                // TEXT_OUT registers are read-only; writes are silently ignored
                default: ;
            endcase
        end
    end
end

// -------------------------------------------------------
// READ logic      purely combinational address decode.
// rd_addr is held by the AXI slave for the full read
// pipeline, so rd_data is stable when the slave
// registers it into s_axi_rdata.
// -------------------------------------------------------
always @(*) begin
    case (rd_addr)
 ADDR_CPSR:   rd_data = {26'd0,
                                 cpsr_mode,   // [5]
                                 cpsr_rst,    // [4]
                                 aes_kdone_in,  // [3]
                                 aes_kld,     // [2]
                                 aes_done_in,   // [1]
                                 aes_ld};     // [0]

        ADDR_KEY0:   rd_data = KEY0;
        ADDR_KEY1:   rd_data = KEY1;
        ADDR_KEY2:   rd_data = KEY2;
        ADDR_KEY3:   rd_data = KEY3;
        ADDR_TXIN0:  rd_data = TXIN0;
        ADDR_TXIN1:  rd_data = TXIN1;
        ADDR_TXIN2:  rd_data = TXIN2;
        ADDR_TXIN3:  rd_data = TXIN3;
        ADDR_TXOUT0: rd_data = TXOUT0;
        ADDR_TXOUT1: rd_data = TXOUT1;
        ADDR_TXOUT2: rd_data = TXOUT2;
        ADDR_TXOUT3: rd_data = TXOUT3;
        default:     rd_data = 32'hDEAD_C0DE;
    endcase
end

endmodule
