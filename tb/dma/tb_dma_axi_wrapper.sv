// =============================================================================
// File   : tb_dma_axi_wrapper.sv
// Module : tb_dma_axi_wrapper
// Purpose: Comprehensive, self-checking SystemVerilog testbench verifying the
//          32-bit AXI4 DMA controller (dma_axi_wrapper) against the requirements
//          in Section 6.3, 7, 8, 9, 10, 11 of the project specification.
// =============================================================================

`timescale 1ns/1ps

module tb_dma_axi_wrapper;

    // -------------------------------------------------------------------------
    // Parameters & Clocks
    // -------------------------------------------------------------------------
    localparam real CLK_PERIOD_NS = 10.0; // 100 MHz
    localparam int  DATA_WIDTH    = 32;
    localparam int  ADDR_WIDTH    = 32;
    localparam int  STRB_WIDTH    = 4;
    localparam int  ID_WIDTH      = 8;

    logic clk;
    logic rst_n;

    // Test tracking
    int pass_count = 0;
    int fail_count = 0;

    // -------------------------------------------------------------------------
    // DUT Interface Signals
    // -------------------------------------------------------------------------
    // Slave Interface (CPU -> DMA CSRs)
    logic [ID_WIDTH-1:0]   s_axi_awid;
    logic [ADDR_WIDTH-1:0] s_axi_awaddr;
    logic [7:0]            s_axi_awlen;
    logic [2:0]            s_axi_awsize;
    logic [1:0]            s_axi_awburst;
    logic                  s_axi_awvalid;
    wire                   s_axi_awready;

    logic [DATA_WIDTH-1:0] s_axi_wdata;
    logic [STRB_WIDTH-1:0] s_axi_wstrb;
    logic                  s_axi_wlast;
    logic                  s_axi_wvalid;
    wire                   s_axi_wready;

    wire  [ID_WIDTH-1:0]   s_axi_bid;
    wire  [1:0]            s_axi_bresp;
    wire                   s_axi_bvalid;
    logic                  s_axi_bready;

    logic [ID_WIDTH-1:0]   s_axi_arid;
    logic [ADDR_WIDTH-1:0] s_axi_araddr;
    logic [7:0]            s_axi_arlen;
    logic [2:0]            s_axi_arsize;
    logic [1:0]            s_axi_arburst;
    logic                  s_axi_arvalid;
    wire                   s_axi_arready;

    wire  [ID_WIDTH-1:0]   s_axi_rid;
    wire  [DATA_WIDTH-1:0] s_axi_rdata;
    wire  [1:0]            s_axi_rresp;
    wire                   s_axi_rlast;
    wire                   s_axi_rvalid;
    logic                  s_axi_rready;

    // Master Interface (DMA -> Memory / Slaves)
    wire  [ID_WIDTH-1:0]   m_axi_awid;
    wire  [ADDR_WIDTH-1:0] m_axi_awaddr;
    wire  [7:0]            m_axi_awlen;
    wire  [2:0]            m_axi_awsize;
    wire  [1:0]            m_axi_awburst;
    wire                   m_axi_awlock;
    wire  [3:0]            m_axi_awcache;
    wire  [2:0]            m_axi_awprot;
    wire  [3:0]            m_axi_awqos;
    wire                   m_axi_awvalid;
    logic                  m_axi_awready;

    wire  [DATA_WIDTH-1:0] m_axi_wdata;
    wire  [STRB_WIDTH-1:0] m_axi_wstrb;
    wire                   m_axi_wlast;
    wire                   m_axi_wvalid;
    logic                  m_axi_wready;

    logic [ID_WIDTH-1:0]   m_axi_bid;
    logic [1:0]            m_axi_bresp;
    logic                  m_axi_bvalid;
    wire                   m_axi_bready;

    wire  [ID_WIDTH-1:0]   m_axi_arid;
    wire  [ADDR_WIDTH-1:0] m_axi_araddr;
    wire  [7:0]            m_axi_arlen;
    wire  [2:0]            m_axi_arsize;
    wire  [1:0]            m_axi_arburst;
    wire                   m_axi_arlock;
    wire  [3:0]            m_axi_arcache;
    wire  [2:0]            m_axi_arprot;
    wire  [3:0]            m_axi_arqos;
    wire                   m_axi_arvalid;
    logic                  m_axi_arready;

    logic [ID_WIDTH-1:0]   m_axi_rid;
    logic [DATA_WIDTH-1:0] m_axi_rdata;
    logic [1:0]            m_axi_rresp;
    logic                  m_axi_rlast;
    logic                  m_axi_rvalid;
    wire                   m_axi_rready;

    // Dedicated signals & interrupt
    wire                   dma_done_irq;
    wire                   dma_busy;
    wire                   dma_done;
    wire                   dma_error;

    // -------------------------------------------------------------------------
    // Instantiate DUT: dma_axi_wrapper
    // -------------------------------------------------------------------------
    dma_axi_wrapper #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .STRB_WIDTH (STRB_WIDTH),
        .ID_WIDTH   (ID_WIDTH)
    ) u_dut (
        .clk             (clk),
        .rst_n           (rst_n),

        .s_axi_awid      (s_axi_awid),
        .s_axi_awaddr    (s_axi_awaddr),
        .s_axi_awlen     (s_axi_awlen),
        .s_axi_awsize    (s_axi_awsize),
        .s_axi_awburst   (s_axi_awburst),
        .s_axi_awvalid   (s_axi_awvalid),
        .s_axi_awready   (s_axi_awready),
        .s_axi_wdata     (s_axi_wdata),
        .s_axi_wstrb     (s_axi_wstrb),
        .s_axi_wlast     (s_axi_wlast),
        .s_axi_wvalid    (s_axi_wvalid),
        .s_axi_wready    (s_axi_wready),
        .s_axi_bid       (s_axi_bid),
        .s_axi_bresp     (s_axi_bresp),
        .s_axi_bvalid    (s_axi_bvalid),
        .s_axi_bready    (s_axi_bready),
        .s_axi_arid      (s_axi_arid),
        .s_axi_araddr    (s_axi_araddr),
        .s_axi_arlen     (s_axi_arlen),
        .s_axi_arsize    (s_axi_arsize),
        .s_axi_arburst   (s_axi_arburst),
        .s_axi_arvalid   (s_axi_arvalid),
        .s_axi_arready   (s_axi_arready),
        .s_axi_rid       (s_axi_rid),
        .s_axi_rdata     (s_axi_rdata),
        .s_axi_rresp     (s_axi_rresp),
        .s_axi_rlast     (s_axi_rlast),
        .s_axi_rvalid    (s_axi_rvalid),
        .s_axi_rready    (s_axi_rready),

        .m_axi_awid      (m_axi_awid),
        .m_axi_awaddr    (m_axi_awaddr),
        .m_axi_awlen     (m_axi_awlen),
        .m_axi_awsize    (m_axi_awsize),
        .m_axi_awburst   (m_axi_awburst),
        .m_axi_awlock    (m_axi_awlock),
        .m_axi_awcache   (m_axi_awcache),
        .m_axi_awprot    (m_axi_awprot),
        .m_axi_awqos     (m_axi_awqos),
        .m_axi_awvalid   (m_axi_awvalid),
        .m_axi_awready   (m_axi_awready),
        .m_axi_wdata     (m_axi_wdata),
        .m_axi_wstrb     (m_axi_wstrb),
        .m_axi_wlast     (m_axi_wlast),
        .m_axi_wvalid    (m_axi_wvalid),
        .m_axi_wready    (m_axi_wready),
        .m_axi_bid       (m_axi_bid),
        .m_axi_bresp     (m_axi_bresp),
        .m_axi_bvalid    (m_axi_bvalid),
        .m_axi_bready    (m_axi_bready),
        .m_axi_arid      (m_axi_arid),
        .m_axi_araddr    (m_axi_araddr),
        .m_axi_arlen     (m_axi_arlen),
        .m_axi_arsize    (m_axi_arsize),
        .m_axi_arburst   (m_axi_arburst),
        .m_axi_arlock    (m_axi_arlock),
        .m_axi_arcache   (m_axi_arcache),
        .m_axi_arprot    (m_axi_arprot),
        .m_axi_arqos     (m_axi_arqos),
        .m_axi_arvalid   (m_axi_arvalid),
        .m_axi_arready   (m_axi_arready),
        .m_axi_rid       (m_axi_rid),
        .m_axi_rdata     (m_axi_rdata),
        .m_axi_rresp     (m_axi_rresp),
        .m_axi_rlast     (m_axi_rlast),
        .m_axi_rvalid    (m_axi_rvalid),
        .m_axi_rready    (m_axi_rready),

        .dma_done_irq    (dma_done_irq),
        .dma_busy        (dma_busy),
        .dma_done        (dma_done),
        .dma_error       (dma_error)
    );

    // -------------------------------------------------------------------------
    // Clock Generation
    // -------------------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD_NS / 2.0) clk = ~clk;
    end

    // -------------------------------------------------------------------------
    // Simulated Memory System for DMA Master Operations
    // Supports 64 KB memory space (indexed by address[15:2])
    // -------------------------------------------------------------------------
    logic [31:0] sim_mem [0:16383]; // 64 KB memory

    // Fault injection controls
    logic inject_read_error  = 1'b0;
    logic inject_write_error = 1'b0;

    // Memory Read Responder
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axi_arready <= 1'b1;
            m_axi_rvalid  <= 1'b0;
            m_axi_rdata   <= '0;
            m_axi_rresp   <= 2'b00;
            m_axi_rlast   <= 1'b0;
            m_axi_rid     <= '0;
        end else begin
            if (m_axi_rvalid && m_axi_rready) begin
                m_axi_rvalid  <= 1'b0;
                m_axi_rlast   <= 1'b0;
                m_axi_arready <= 1'b1;
            end

            if (m_axi_arvalid && m_axi_arready) begin
                m_axi_arready <= 1'b0;
                m_axi_rvalid  <= 1'b1;
                m_axi_rlast   <= 1'b1;
                m_axi_rid     <= m_axi_arid;
                m_axi_rdata   <= sim_mem[m_axi_araddr[15:2]];

                if (inject_read_error) begin
                    m_axi_rresp <= 2'b10; // SLVERR
                end else begin
                    m_axi_rresp <= 2'b00; // OKAY
                end
            end
        end
    end

    // Memory Write Responder
    logic [15:2] wr_word_addr;
    logic        aw_captured;
    logic [ID_WIDTH-1:0] wr_captured_id;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axi_awready <= 1'b1;
            m_axi_wready  <= 1'b1;
            m_axi_bvalid  <= 1'b0;
            m_axi_bresp   <= 2'b00;
            m_axi_bid     <= '0;
            aw_captured   <= 1'b0;
            wr_word_addr  <= '0;
            wr_captured_id<= '0;
        end else begin
            if (m_axi_bvalid && m_axi_bready) begin
                m_axi_bvalid  <= 1'b0;
                m_axi_awready <= 1'b1;
                m_axi_wready  <= 1'b1;
            end

            // Capture write address if it arrives first
            if (m_axi_awvalid && m_axi_awready && !(m_axi_wvalid && m_axi_wready)) begin
                wr_word_addr   <= m_axi_awaddr[15:2];
                wr_captured_id <= m_axi_awid;
                aw_captured    <= 1'b1;
                m_axi_awready  <= 1'b0;
            end

            // Write data handling
            if ((m_axi_awvalid && m_axi_awready && m_axi_wvalid && m_axi_wready) ||
                (aw_captured && m_axi_wvalid && m_axi_wready)) begin
                logic [15:2] target_word;
                logic [ID_WIDTH-1:0] target_id;

                target_word = aw_captured ? wr_word_addr : m_axi_awaddr[15:2];
                target_id   = aw_captured ? wr_captured_id : m_axi_awid;

                // Apply byte strobes to memory word
                for (int b = 0; b < 4; b++) begin
                    if (m_axi_wstrb[b]) begin
                        sim_mem[target_word][b*8 +: 8] <= m_axi_wdata[b*8 +: 8];
                    end
                end

                m_axi_bvalid  <= 1'b1;
                m_axi_bid     <= target_id;
                if (inject_write_error) begin
                    m_axi_bresp <= 2'b10; // SLVERR
                end else begin
                    m_axi_bresp <= 2'b00; // OKAY
                end

                m_axi_awready <= 1'b0;
                m_axi_wready  <= 1'b0;
                aw_captured   <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Helper Tasks for CPU AXI Slave Access
    // -------------------------------------------------------------------------
    task automatic csr_write(input [31:0] addr, input [31:0] data);
        @(posedge clk);
        s_axi_awaddr  <= addr;
        s_axi_awvalid <= 1'b1;
        s_axi_wdata   <= data;
        s_axi_wstrb   <= 4'b1111;
        s_axi_wvalid  <= 1'b1;
        s_axi_bready  <= 1'b1;

        fork
            begin
                while (!s_axi_awready) @(posedge clk);
                @(posedge clk);
                s_axi_awvalid <= 1'b0;
            end
            begin
                while (!s_axi_wready) @(posedge clk);
                @(posedge clk);
                s_axi_wvalid <= 1'b0;
            end
        join

        while (!s_axi_bvalid) @(posedge clk);
        @(posedge clk);
        s_axi_bready <= 1'b0;
        #(CLK_PERIOD_NS);
    endtask

    task automatic csr_read(input [31:0] addr, output [31:0] data);
        @(posedge clk);
        s_axi_araddr  <= addr;
        s_axi_arvalid <= 1'b1;
        s_axi_rready  <= 1'b1;

        while (!s_axi_arready) @(posedge clk);
        @(posedge clk);
        s_axi_arvalid <= 1'b0;

        while (!s_axi_rvalid) @(posedge clk);
        data = s_axi_rdata;
        @(posedge clk);
        s_axi_rready <= 1'b0;
        #(CLK_PERIOD_NS);
    endtask

    // -------------------------------------------------------------------------
    // Main Verification Process
    // -------------------------------------------------------------------------
    logic [31:0] rd_val;

    initial begin
        // Initialize inputs
        rst_n         = 1'b0;
        s_axi_awid    = '0;
        s_axi_awaddr  = '0;
        s_axi_awlen   = '0;
        s_axi_awsize  = 3'b010;
        s_axi_awburst = 2'b01;
        s_axi_awvalid = 1'b0;
        s_axi_wdata   = '0;
        s_axi_wstrb   = 4'b1111;
        s_axi_wlast   = 1'b1;
        s_axi_wvalid  = 1'b0;
        s_axi_bready  = 1'b0;
        s_axi_arid    = '0;
        s_axi_araddr  = '0;
        s_axi_arlen   = '0;
        s_axi_arsize  = 3'b010;
        s_axi_arburst = 2'b01;
        s_axi_arvalid = 1'b0;
        s_axi_rready  = 1'b0;

        // Initialize simulated memory with 0
        for (int i = 0; i < 16384; i++) begin
            sim_mem[i] = 32'h0;
        end

        $display("==================================================================");
        $display("Starting AXI4 DMA Controller (dma_axi_wrapper) Verification");
        $display("==================================================================");

        // Apply reset for 50 ns
        #(CLK_PERIOD_NS * 5);
        @(posedge clk);
        rst_n = 1'b1;
        #(CLK_PERIOD_NS * 2);

        // =====================================================================
        // TEST 1: Register Read/Write Access & Reset Defaults
        // =====================================================================
        $display("\n--- TEST 1: Register Read/Write Access & Reset Defaults ---");

        csr_read(32'h2000_5000, rd_val); // CTRL
        if (rd_val == 32'h0) begin
            $display("[PASS] Reset CTRL == 0x00000000"); pass_count++;
        end else begin
            $display("[FAIL] Reset CTRL expected 0, got 0x%08X", rd_val); fail_count++;
        end

        csr_read(32'h2000_5004, rd_val); // STATUS
        if (rd_val == 32'h0) begin
            $display("[PASS] Reset STATUS == 0x00000000 (BUSY=0, DONE=0, ERROR=0)"); pass_count++;
        end else begin
            $display("[FAIL] Reset STATUS expected 0, got 0x%08X", rd_val); fail_count++;
        end

        // Write SRC_ADDR, DST_ADDR, LENGTH
        csr_write(32'h2000_5008, 32'h1000_0100);
        csr_read(32'h2000_5008, rd_val);
        if (rd_val == 32'h1000_0100) begin
            $display("[PASS] SRC_ADDR configured and readback == 0x10000100"); pass_count++;
        end else begin
            $display("[FAIL] SRC_ADDR expected 0x10000100, got 0x%08X", rd_val); fail_count++;
        end

        csr_write(32'h2000_500C, 32'h2000_3100);
        csr_read(32'h2000_500C, rd_val);
        if (rd_val == 32'h2000_3100) begin
            $display("[PASS] DST_ADDR configured and readback == 0x20003100"); pass_count++;
        end else begin
            $display("[FAIL] DST_ADDR expected 0x20003100, got 0x%08X", rd_val); fail_count++;
        end

        csr_write(32'h2000_5010, 32'd64);
        csr_read(32'h2000_5010, rd_val);
        if (rd_val == 32'd64) begin
            $display("[PASS] LENGTH configured and readback == 64 bytes"); pass_count++;
        end else begin
            $display("[FAIL] LENGTH expected 64, got %0d", rd_val); fail_count++;
        end

        // =====================================================================
        // TEST 2: Basic Memory-to-Memory Transfer (16 bytes = 4 words)
        // =====================================================================
        $display("\n--- TEST 2: Basic Memory-to-Memory Transfer (16 bytes = 4 words) ---");
        // Preload source memory @ offset 0x100 (words 64..67)
        sim_mem[64] = 32'hDEADBEEF;
        sim_mem[65] = 32'hCAFEBABE;
        sim_mem[66] = 32'h12345678;
        sim_mem[67] = 32'hAABBCCDD;

        // Destination @ offset 0x200 (words 128..131) set to zero
        sim_mem[128] = 32'h0;
        sim_mem[129] = 32'h0;
        sim_mem[130] = 32'h0;
        sim_mem[131] = 32'h0;

        // Program DMA
        csr_write(32'h2000_5008, 32'h0000_0100); // SRC = 0x100
        csr_write(32'h2000_500C, 32'h0000_0200); // DST = 0x200
        csr_write(32'h2000_5010, 32'd16);        // 16 bytes
        csr_write(32'h2000_5000, 32'h1);         // START=1

        // Poll for completion (BUSY == 0, DONE == 1)
        rd_val = 32'h1;
        while (rd_val[0]) begin // while BUSY
            csr_read(32'h2000_5004, rd_val);
        end

        if (rd_val[1] == 1'b1 && rd_val[2] == 1'b0) begin
            $display("[PASS] DMA transfer completed with DONE=1, ERROR=0"); pass_count++;
        end else begin
            $display("[FAIL] DMA transfer status unexpected: 0x%08X", rd_val); fail_count++;
        end

        // Verify data in destination memory
        if (sim_mem[128] == 32'hDEADBEEF &&
            sim_mem[129] == 32'hCAFEBABE &&
            sim_mem[130] == 32'h12345678 &&
            sim_mem[131] == 32'hAABBCCDD) begin
            $display("[PASS] All 4 words (16 bytes) verified successfully at destination!"); pass_count++;
        end else begin
            $display("[FAIL] Destination mismatch! Got: 0x%08X 0x%08X 0x%08X 0x%08X",
                     sim_mem[128], sim_mem[129], sim_mem[130], sim_mem[131]); fail_count++;
        end

        // =====================================================================
        // TEST 3: Bulk Image Transfer (256 bytes = 64 words, full 16x16 INT8 image)
        // =====================================================================
        $display("\n--- TEST 3: Bulk Image Transfer (256 bytes = 64 words, 16x16 Image) ---");
        // Preload 64 words @ source 0x400 (word idx 256..319)
        for (int i = 0; i < 64; i++) begin
            sim_mem[256 + i] = (i * 32'h01010101) + 32'hA0000000;
            sim_mem[512 + i] = 32'h0; // Clear destination 0x800
        end

        csr_write(32'h2000_5008, 32'h0000_0400); // SRC = 0x400
        csr_write(32'h2000_500C, 32'h0000_0800); // DST = 0x800
        csr_write(32'h2000_5010, 32'd256);       // 256 bytes
        csr_write(32'h2000_5000, 32'h1);         // START=1

        rd_val = 32'h1;
        while (rd_val[0]) begin
            csr_read(32'h2000_5004, rd_val);
        end

        if (rd_val[1] == 1'b1) begin
            $display("[PASS] Bulk image transfer finished: DONE=1"); pass_count++;
        end else begin
            $display("[FAIL] Bulk image transfer failed: 0x%08X", rd_val); fail_count++;
        end

        // Verify all 64 words
        begin
            int mismatches = 0;
            for (int i = 0; i < 64; i++) begin
                if (sim_mem[512 + i] != ((i * 32'h01010101) + 32'hA0000000)) begin
                    mismatches++;
                end
            end
            if (mismatches == 0) begin
                $display("[PASS] All 64 image words (256 bytes) verified with ZERO mismatches!"); pass_count++;
            end else begin
                $display("[FAIL] Bulk image transfer had %0d mismatches!", mismatches); fail_count++;
            end
        end

        // =====================================================================
        // TEST 4: Partial / Odd Byte Length (13 bytes = 3 words + 1 byte)
        // =====================================================================
        $display("\n--- TEST 4: Partial / Odd Byte Length (13 bytes = 3 words + 1 byte) ---");
        sim_mem[100] = 32'h11223344;
        sim_mem[101] = 32'h55667788;
        sim_mem[102] = 32'h99AABBCC;
        sim_mem[103] = 32'hFFFF0055; // Only lowest byte (0x55) should be written!

        sim_mem[150] = 32'h0;
        sim_mem[151] = 32'h0;
        sim_mem[152] = 32'h0;
        sim_mem[153] = 32'hAAAAAAAA; // Preload sentinel pattern

        csr_write(32'h2000_5008, 32'h0000_0190); // 100 * 4 = 0x190
        csr_write(32'h2000_500C, 32'h0000_0258); // 150 * 4 = 0x258
        csr_write(32'h2000_5010, 32'd13);        // 13 bytes
        csr_write(32'h2000_5000, 32'h1);         // START

        rd_val = 32'h1;
        while (rd_val[0]) csr_read(32'h2000_5004, rd_val);

        if (sim_mem[150] == 32'h11223344 &&
            sim_mem[151] == 32'h55667788 &&
            sim_mem[152] == 32'h99AABBCC &&
            sim_mem[153] == 32'hAAAAAA55) begin // byte 0 updated, upper 3 bytes preserved!
            $display("[PASS] 13-byte partial transfer strobing verified (last word: 0x%08X)", sim_mem[153]); pass_count++;
        end else begin
            $display("[FAIL] Partial transfer strobe mismatch! word 153 = 0x%08X (Expected 0xAAAAAA55)", sim_mem[153]); fail_count++;
        end

        // =====================================================================
        // TEST 5: Interrupt Generation (DMA_DONE_IRQ)
        // =====================================================================
        $display("\n--- TEST 5: Interrupt Generation (dma_done_irq) ---");
        // Enable IRQ (bit 2) and start transfer
        csr_write(32'h2000_5000, 32'h5); // IRQ_EN=1 (bit2), START=1 (bit0)

        // Wait for interrupt pulse
        @(posedge dma_done_irq);
        $display("[PASS] Dedicated dma_done_irq interrupt pulse asserted upon completion!"); pass_count++;

        // =====================================================================
        // TEST 6: Error Handling & Fault Injection (Section 9)
        // =====================================================================
        $display("\n--- TEST 6: Error Handling & Fault Injection ---");

        // Subtest 6A: Zero Length Error
        csr_write(32'h2000_5010, 32'd0); // LENGTH = 0
        csr_write(32'h2000_5000, 32'h1); // START
        #(CLK_PERIOD_NS * 2);
        csr_read(32'h2000_5004, rd_val); // STATUS
        if (rd_val[2] == 1'b1) begin // ERROR bit set
            csr_read(32'h2000_5014, rd_val); // ERROR_CODE
            if (rd_val == 32'd1) begin
                $display("[PASS] Subtest 6A: Zero-length rejected with ERROR=1, ERROR_CODE=1"); pass_count++;
            end else begin
                $display("[FAIL] Subtest 6A: Expected ERROR_CODE=1, got %0d", rd_val); fail_count++;
            end
        end else begin
            $display("[FAIL] Subtest 6A: ERROR bit was not set on zero-length transfer!"); fail_count++;
        end

        // Clear error via W1C
        csr_write(32'h2000_5004, 32'h4); // clear bit 2
        csr_read(32'h2000_5004, rd_val);
        if (rd_val[2] == 1'b0) begin
            $display("[PASS] STATUS error bit cleared via W1C"); pass_count++;
        end

        // Subtest 6B: Bus Read Error (SLVERR on read)
        inject_read_error = 1'b1;
        csr_write(32'h2000_5010, 32'd16); // LENGTH = 16
        csr_write(32'h2000_5000, 32'h1);  // START
        #(CLK_PERIOD_NS * 5);
        csr_read(32'h2000_5004, rd_val);
        if (rd_val[2] == 1'b1) begin
            csr_read(32'h2000_5014, rd_val);
            if (rd_val == 32'd2) begin
                $display("[PASS] Subtest 6B: AXI Read SLVERR correctly caught (ERROR_CODE=2)"); pass_count++;
            end else begin
                $display("[FAIL] Subtest 6B: Expected ERROR_CODE=2, got %0d", rd_val); fail_count++;
            end
        end else begin
            $display("[FAIL] Subtest 6B: Read error was not flagged!"); fail_count++;
        end
        inject_read_error = 1'b0;

        // Subtest 6C: Bus Write Error (SLVERR on write)
        csr_write(32'h2000_5004, 32'h4); // Clear error
        inject_write_error = 1'b1;
        csr_write(32'h2000_5010, 32'd16);
        csr_write(32'h2000_5000, 32'h1);
        #(CLK_PERIOD_NS * 10);
        csr_read(32'h2000_5004, rd_val);
        if (rd_val[2] == 1'b1) begin
            csr_read(32'h2000_5014, rd_val);
            if (rd_val == 32'd3) begin
                $display("[PASS] Subtest 6C: AXI Write SLVERR correctly caught (ERROR_CODE=3)"); pass_count++;
            end else begin
                $display("[FAIL] Subtest 6C: Expected ERROR_CODE=3, got %0d", rd_val); fail_count++;
            end
        end else begin
            $display("[FAIL] Subtest 6C: Write error was not flagged!"); fail_count++;
        end
        inject_write_error = 1'b0;

        // =====================================================================
        // TEST 7: Soft Reset (DMA_RESET in CTRL)
        // =====================================================================
        $display("\n--- TEST 7: Soft Reset (DMA_RESET) ---");
        csr_write(32'h2000_5004, 32'h6); // Clear done & error
        csr_write(32'h2000_5010, 32'd1024); // Large transfer
        csr_write(32'h2000_5000, 32'h1);    // START
        #(CLK_PERIOD_NS * 5);
        if (dma_busy) begin
            $display("[INFO] DMA engine active (BUSY=1), asserting soft reset...");
            csr_write(32'h2000_5000, 32'h2); // bit 1: DMA_RESET
            #(CLK_PERIOD_NS * 2);
            csr_read(32'h2000_5004, rd_val);
            if (rd_val[0] == 1'b0) begin
                $display("[PASS] Soft reset halted DMA operation: BUSY=0"); pass_count++;
            end else begin
                $display("[FAIL] Soft reset failed to stop engine: STATUS=0x%08X", rd_val); fail_count++;
            end
        end

        // =====================================================================
        // Results Summary
        // =====================================================================
        $display("\n==================================================================");
        $display("AXI4 DMA CONTROLLER VERIFICATION SUMMARY:");
        $display("  PASSED: %0d", pass_count);
        $display("  FAILED: %0d", fail_count);
        $display("==================================================================");

        if (fail_count == 0) begin
            $display("[TESTBENCH PASSED] ALL DMA TESTS COMPLETED SUCCESSFULLY!\n");
            $finish(0);
        end else begin
            $display("[TESTBENCH FAILED] ERRORS ENCOUNTERED DURING DMA VERIFICATION!\n");
            $finish(1);
        end
    end

endmodule
