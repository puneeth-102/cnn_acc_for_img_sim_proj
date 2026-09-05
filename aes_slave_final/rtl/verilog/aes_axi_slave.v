// ============================================================
// aes_axi_slave.v
// AXI4-Lite slave protocol handler.
// Decouples AXI handshake from register logic.
// Outputs: wr_en, wr_addr, wr_data, wr_strb (write side)
//          rd_en, rd_addr              (read  side)
// Inputs:  rd_data                     (read  data from reg map)
// ============================================================
`include "timescale.v"

module aes_axi_slave (
    // Global
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,

    // Write address channel
    input  wire [5:0]  s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,

    // Write data channel
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,

    // Write response channel
    output reg  [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,

    // Read address channel
    input  wire [5:0]  s_axi_araddr,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,

    // Read data channel
    output reg  [31:0] s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,

    // Register interface – write side
    output reg         wr_en,
    output reg  [5:0]  wr_addr,
    output reg  [31:0] wr_data,
    output reg  [3:0]  wr_strb,

    // Register interface – read side
    output reg         rd_en,
    output reg  [5:0]  rd_addr,
    input  wire [31:0] rd_data
);

// ---------- internal state ----------
reg [5:0] aw_addr_lat;   // latched write address
reg       aw_valid_lat;  // write address latched flag

// ======================================================
// WRITE PATH
// AW and W channels accepted independently, combined
// once both are present.
// ======================================================
always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
        s_axi_awready  <= 1'b0;
        s_axi_wready   <= 1'b0;
        s_axi_bvalid   <= 1'b0;
        s_axi_bresp    <= 2'b00;
        wr_en          <= 1'b0;
        wr_addr        <= 6'd0;
        wr_data        <= 32'd0;
        wr_strb        <= 4'hF;
        aw_addr_lat    <= 6'd0;
        aw_valid_lat   <= 1'b0;
    end else begin
        // Default: deassert pulses
        wr_en         <= 1'b0;
        s_axi_awready <= 1'b0;
        s_axi_wready  <= 1'b0;

        // Latch AW address as soon as it is presented
        if (s_axi_awvalid && !aw_valid_lat) begin
            aw_addr_lat  <= s_axi_awaddr;
            aw_valid_lat <= 1'b1;
            s_axi_awready <= 1'b1;   // accept in same cycle
        end

        // Once we have both address and data, do the write
        if (aw_valid_lat && s_axi_wvalid && !s_axi_bvalid) begin
            s_axi_wready  <= 1'b1;
            wr_en         <= 1'b1;
            wr_addr       <= aw_addr_lat;
            wr_data       <= s_axi_wdata;
            wr_strb       <= s_axi_wstrb;
            aw_valid_lat  <= 1'b0;
            // Issue write response
            s_axi_bvalid  <= 1'b1;
            s_axi_bresp   <= 2'b00; // OKAY
        end

        // Clear bvalid once master accepts response
        if (s_axi_bvalid && s_axi_bready) begin
            s_axi_bvalid <= 1'b0;
        end
    end
end

// ======================================================
// READ PATH
// ======================================================
always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
        s_axi_arready <= 1'b0;
        s_axi_rvalid  <= 1'b0;
        s_axi_rdata   <= 32'd0;
        s_axi_rresp   <= 2'b00;
        rd_en         <= 1'b0;
        rd_addr       <= 6'd0;
    end else begin
        rd_en         <= 1'b0;
        s_axi_arready <= 1'b0;

        if (s_axi_arvalid && !s_axi_rvalid) begin
            s_axi_arready <= 1'b1;
            rd_en         <= 1'b1;
            rd_addr       <= s_axi_araddr;
        end

        // Present read data on cycle after rd_en
        if (rd_en) begin
            s_axi_rdata  <= rd_data;
            s_axi_rresp  <= 2'b00;
            s_axi_rvalid <= 1'b1;
        end

        // Clear rvalid once master accepts
        if (s_axi_rvalid && s_axi_rready) begin
            s_axi_rvalid <= 1'b0;
        end
    end
end

endmodule
