// ============================================================
// aes_axi_top.v
// Top-level: connects AXI4-Lite slave, register map,
// AES-128 cipher (encryption) and AES-128 inverse cipher
// (decryption).
//
// kdone is generated locally because aes_inv_cipher_top
// does not expose it as a port.  Key expansion takes 12
// clock cycles after kld, so we count to 12 here.
// ============================================================
`include "timescale.v"

module aes_axi_top (
    // AXI global
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,

    // Write address
    input  wire [5:0]  s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,

    // Write data
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,

    // Write response
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,

    // Read address
    input  wire [5:0]  s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,

    // Read data
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready
);

// -----------------------------------------------------------
// Internal wires between slave and register map
// -----------------------------------------------------------
wire        wr_en, rd_en;
wire [5:0]  wr_addr, rd_addr;
wire [31:0] wr_data, rd_data;
wire [3:0]  wr_strb;

// -----------------------------------------------------------
// AES control/data signals from register map
// -----------------------------------------------------------
wire        aes_rst;      // active-low (1=run, 0=reset)
wire        aes_ld;       // one-cycle pulse
wire        aes_kld;      // one-cycle pulse
wire        aes_mode;     // 0=enc, 1=dec
wire [127:0] aes_key;
wire [127:0] aes_text_in;

wire [127:0] enc_text_out;
wire [127:0] dec_text_out;
wire         enc_done;
wire         dec_done;

// -----------------------------------------------------------
// Latch text_out at the done pulse so AXI reads are stable.
// The AES cipher text_out register keeps updating every cycle;
// we capture it exactly when done asserts.
// -----------------------------------------------------------
reg [127:0] enc_text_lat;
reg [127:0] dec_text_lat;

always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
        enc_text_lat <= 128'd0;
        dec_text_lat <= 128'd0;
    end else begin
        if (enc_done) enc_text_lat <= enc_text_out;
        if (dec_done) dec_text_lat <= dec_text_out;
    end
end

// -----------------------------------------------------------
// kdone generation: count 12 cycles after kld pulse
// -----------------------------------------------------------
reg [4:0] kcnt;
reg       kdone_pulse;  // one-cycle pulse when key expansion done

always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
        kcnt        <= 5'd0;
        kdone_pulse <= 1'b0;
    end else begin
        kdone_pulse <= 1'b0;
        if (aes_kld) begin
            kcnt <= 5'd1;
        end else if (kcnt != 5'd0) begin
            if (kcnt == 5'd12) begin
                kdone_pulse <= 1'b1;
                kcnt        <= 5'd0;
            end else begin
                kcnt <= kcnt + 5'd1;
            end
        end
    end
end

// -----------------------------------------------------------
// Latch done/kdone so software can poll via AXI reads.
// Cleared when a new LD (or KLD) pulse is issued.
// -----------------------------------------------------------
reg done_lat;    // latched enc or dec done
reg kdone_lat;   // latched kdone

always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
        done_lat  <= 1'b0;
        kdone_lat <= 1'b0;
    end else begin
        // Set on done pulse
        if (enc_done | dec_done) done_lat  <= 1'b1;
        if (kdone_pulse)         kdone_lat <= 1'b1;
        // Clear when LD re-asserted (new operation starts)
        if (aes_ld)  done_lat  <= 1'b0;
        if (aes_kld) kdone_lat <= 1'b0;
    end
end

wire kdone_r = kdone_lat;

// -----------------------------------------------------------
// AXI4-Lite Slave
// -----------------------------------------------------------
aes_axi_slave u_slave (
    .s_axi_aclk    (s_axi_aclk),
    .s_axi_aresetn (s_axi_aresetn),
    // Write address
    .s_axi_awaddr  (s_axi_awaddr),
    .s_axi_awvalid (s_axi_awvalid),
    .s_axi_awready (s_axi_awready),
    // Write data
    .s_axi_wdata   (s_axi_wdata),
    .s_axi_wstrb   (s_axi_wstrb),
    .s_axi_wvalid  (s_axi_wvalid),
    .s_axi_wready  (s_axi_wready),
    // Write response
    .s_axi_bresp   (s_axi_bresp),
    .s_axi_bvalid  (s_axi_bvalid),
    .s_axi_bready  (s_axi_bready),
    // Read address
    .s_axi_araddr  (s_axi_araddr),
    .s_axi_arvalid (s_axi_arvalid),
    .s_axi_arready (s_axi_arready),
    // Read data
    .s_axi_rdata   (s_axi_rdata),
    .s_axi_rresp   (s_axi_rresp),
    .s_axi_rvalid  (s_axi_rvalid),
    .s_axi_rready  (s_axi_rready),
    // Register bus
    .wr_en         (wr_en),
    .wr_addr       (wr_addr),
    .wr_data       (wr_data),
    .wr_strb       (wr_strb),
    .rd_en         (rd_en),
    .rd_addr       (rd_addr),
    .rd_data       (rd_data)
);

// -----------------------------------------------------------
// Register Map
// -----------------------------------------------------------
aes_reg_map u_regmap (
    .clk           (s_axi_aclk),
    .resetn        (s_axi_aresetn),
    // Register bus
    .wr_en         (wr_en),
    .wr_addr       (wr_addr),
    .wr_data       (wr_data),
    .wr_strb       (wr_strb),
    .rd_en         (rd_en),
    .rd_addr       (rd_addr),
    .rd_data       (rd_data),
    // AES signals
    .aes_rst       (aes_rst),
    .aes_ld        (aes_ld),
    .aes_kld       (aes_kld),
    .aes_mode      (aes_mode),
    .aes_key       (aes_key),
    .aes_text_in   (aes_text_in),
    .aes_enc_out   (enc_text_lat),
    .aes_dec_out   (dec_text_lat),
    .aes_done_in   (done_lat),
    .aes_kdone_in  (kdone_r)
);

// -----------------------------------------------------------
// AES Cipher (Encryption) core
// -----------------------------------------------------------
aes_cipher_top u_enc (
    .clk      (s_axi_aclk),
    .rst      (aes_rst),
    .ld       (aes_ld),
    .done     (enc_done),
    .key      (aes_key),
    .text_in  (aes_text_in),
    .text_out (enc_text_out)
);

// -----------------------------------------------------------
// AES Inverse Cipher (Decryption) core
// -----------------------------------------------------------
aes_inv_cipher_top u_dec (
    .clk      (s_axi_aclk),
    .rst      (aes_rst),
    .kld      (aes_kld),
    .ld       (aes_ld),
    .done     (dec_done),
    .key      (aes_key),
    .text_in  (aes_text_in),
    .text_out (dec_text_out)
);

endmodule
