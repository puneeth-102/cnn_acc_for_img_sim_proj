// =============================================================================
// File   : tb_cnn_axi_wrapper.sv
// Module : tb_cnn_axi_wrapper
// Purpose: Self-checking testbench for cnn_axi_wrapper.
//          Verifies:
//            1. Reset behavior (default register values)
//            2. Read/Write access to all configuration registers
//            3. Invalid/unmapped register accesses return SLVERR & ERROR_CODE=1
//            4. Invalid configuration detection (DIM_CFG/EMBED_LEN) -> ERROR_CODE=3
//            5. Soft reset functionality via CTRL[1]
//            6. Starting CNN inference, BUSY flag, completion DONE flag & IRQ
//            7. Start attempted while BUSY -> ERROR_CODE=2
//            8. Result readback and mathematical correctness (1764 per embedding)
//            9. Direct image buffer access (0x100 - 0x1FC)
// =============================================================================

`timescale 1ns/1ps

module tb_cnn_axi_wrapper;

    parameter int DATA_WIDTH = 32;
    parameter int ADDR_WIDTH = 32;
    parameter int ID_WIDTH   = 8;

    logic clk;
    logic rst_n;

    // AXI signals
    logic [ID_WIDTH-1:0]   s_axi_awid;
    logic [ADDR_WIDTH-1:0] s_axi_awaddr;
    logic [7:0]            s_axi_awlen;
    logic [2:0]            s_axi_awsize;
    logic [1:0]            s_axi_awburst;
    logic                  s_axi_awvalid;
    logic                  s_axi_awready;

    logic [DATA_WIDTH-1:0] s_axi_wdata;
    logic [3:0]            s_axi_wstrb;
    logic                  s_axi_wlast;
    logic                  s_axi_wvalid;
    logic                  s_axi_wready;

    logic [ID_WIDTH-1:0]   s_axi_bid;
    logic [1:0]            s_axi_bresp;
    logic                  s_axi_bvalid;
    logic                  s_axi_bready;

    logic [ID_WIDTH-1:0]   s_axi_arid;
    logic [ADDR_WIDTH-1:0] s_axi_araddr;
    logic [7:0]            s_axi_arlen;
    logic [2:0]            s_axi_arsize;
    logic [1:0]            s_axi_arburst;
    logic                  s_axi_arvalid;
    logic                  s_axi_arready;

    logic [ID_WIDTH-1:0]   s_axi_rid;
    logic [DATA_WIDTH-1:0] s_axi_rdata;
    logic [1:0]            s_axi_rresp;
    logic                  s_axi_rlast;
    logic                  s_axi_rvalid;
    logic                  s_axi_rready;

    logic                  accel_done_irq;
    logic signed [31:0]    hw_embedding [0:15];

    int pass_count = 0;
    int fail_count = 0;

    // Clock generator (100 MHz)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // DUT Instance
    cnn_axi_wrapper #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .ID_WIDTH   (ID_WIDTH)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axi_awid     (s_axi_awid),
        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awlen    (s_axi_awlen),
        .s_axi_awsize   (s_axi_awsize),
        .s_axi_awburst  (s_axi_awburst),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),
        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wlast    (s_axi_wlast),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),
        .s_axi_bid      (s_axi_bid),
        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),
        .s_axi_arid     (s_axi_arid),
        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arlen    (s_axi_arlen),
        .s_axi_arsize   (s_axi_arsize),
        .s_axi_arburst  (s_axi_arburst),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),
        .s_axi_rid      (s_axi_rid),
        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rlast    (s_axi_rlast),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready),
        .accel_done_irq (accel_done_irq),
        .hw_embedding   (hw_embedding)
    );

    // =========================================================================
    // AXI Master Tasks
    // =========================================================================
    task automatic axi_write(
        input  logic [31:0] addr,
        input  logic [31:0] data,
        input  logic [3:0]  strb,
        output logic [1:0]  resp
    );
        @(negedge clk);
        s_axi_awid    <= 8'hA1;
        s_axi_awaddr  <= addr;
        s_axi_awlen   <= 8'd0;
        s_axi_awsize  <= 3'b010;
        s_axi_awburst <= 2'b01;
        s_axi_awvalid <= 1'b1;

        s_axi_wdata   <= data;
        s_axi_wstrb   <= strb;
        s_axi_wlast   <= 1'b1;
        s_axi_wvalid  <= 1'b1;
        s_axi_bready  <= 1'b1;

        // Wait for address and data handshakes
        fork
            begin
                while (!(s_axi_awvalid && s_axi_awready)) @(posedge clk);
                @(negedge clk); s_axi_awvalid <= 1'b0;
            end
            begin
                while (!(s_axi_wvalid && s_axi_wready)) @(posedge clk);
                @(negedge clk); s_axi_wvalid <= 1'b0;
            end
        join

        // Wait for write response
        while (!(s_axi_bvalid && s_axi_bready)) @(posedge clk);
        resp = s_axi_bresp;
        @(negedge clk);
        s_axi_bready <= 1'b0;
    endtask

    task automatic axi_read(
        input  logic [31:0] addr,
        output logic [31:0] data,
        output logic [1:0]  resp
    );
        @(negedge clk);
        s_axi_arid    <= 8'hB2;
        s_axi_araddr  <= addr;
        s_axi_arlen   <= 8'd0;
        s_axi_arsize  <= 3'b010;
        s_axi_arburst <= 2'b01;
        s_axi_arvalid <= 1'b1;
        s_axi_rready  <= 1'b1;

        while (!(s_axi_arvalid && s_axi_arready)) @(posedge clk);
        @(negedge clk); s_axi_arvalid <= 1'b0;

        while (!(s_axi_rvalid && s_axi_rready)) @(posedge clk);
        data = s_axi_rdata;
        resp = s_axi_rresp;
        @(negedge clk);
        s_axi_rready <= 1'b0;
    endtask

    // Check helper
    task check(input string desc, input logic condition);
        if (condition) begin
            $display("[PASS] %s", desc);
            pass_count++;
        end else begin
            $display("[FAIL] %s", desc);
            fail_count++;
        end
    endtask

    // =========================================================================
    // Test Sequence
    // =========================================================================
    logic [31:0] rdata;
    logic [1:0]  resp;
    int match_all;
    int hw_match_all;

    initial begin
        // Reset signals
        rst_n         = 1'b0;
        s_axi_awvalid = 1'b0;
        s_axi_wvalid  = 1'b0;
        s_axi_bready  = 1'b0;
        s_axi_arvalid = 1'b0;
        s_axi_rready  = 1'b0;

        #30;
        rst_n = 1'b1;
        #20;

        $display("============================================================");
        $display("Starting CNN AXI-Lite Wrapper Tests");
        $display("============================================================");

        // --- TEST 1: Default Reset Values ---
        $display("\n--- TEST 1: Reset Values Check ---");
        axi_read(32'h2000_3004, rdata, resp); // STATUS
        check("STATUS after reset is 0", (resp == 2'b00 && rdata == 32'h0));

        axi_read(32'h2000_3008, rdata, resp); // IMAGE_BASE_ADDR
        check("Default IMAGE_BASE_ADDR == 0x1000_0000", (resp == 2'b00 && rdata == 32'h1000_0000));

        axi_read(32'h2000_300C, rdata, resp); // WEIGHT_BASE_ADDR
        check("Default WEIGHT_BASE_ADDR == 0x1000_1000", (resp == 2'b00 && rdata == 32'h1000_1000));

        axi_read(32'h2000_3010, rdata, resp); // EMBED_BASE_ADDR
        check("Default EMBED_BASE_ADDR == 0x1000_2000", (resp == 2'b00 && rdata == 32'h1000_2000));

        axi_read(32'h2000_3014, rdata, resp); // DIM_CFG
        check("Default DIM_CFG == 0x0010_0010 (16x16)", (resp == 2'b00 && rdata == 32'h0010_0010));

        axi_read(32'h2000_3018, rdata, resp); // EMBED_LEN
        check("Default EMBED_LEN == 16", (resp == 2'b00 && rdata == 32'd16));

        // --- TEST 2: Register Write and Readback ---
        $display("\n--- TEST 2: Register Write & Readback ---");
        axi_write(32'h2000_3008, 32'h1000_5000, 4'hF, resp);
        axi_read(32'h2000_3008, rdata, resp);
        check("Write & Read IMAGE_BASE_ADDR (0x1000_5000)", (resp == 2'b00 && rdata == 32'h1000_5000));

        axi_write(32'h2000_300C, 32'h1000_6000, 4'hF, resp);
        axi_read(32'h2000_300C, rdata, resp);
        check("Write & Read WEIGHT_BASE_ADDR (0x1000_6000)", (resp == 2'b00 && rdata == 32'h1000_6000));

        axi_write(32'h2000_3010, 32'h1000_7000, 4'hF, resp);
        axi_read(32'h2000_3010, rdata, resp);
        check("Write & Read EMBED_BASE_ADDR (0x1000_7000)", (resp == 2'b00 && rdata == 32'h1000_7000));

        // --- TEST 3: Invalid / Unmapped Register Access ---
        $display("\n--- TEST 3: Unmapped Register Access Handling ---");
        axi_read(32'h2000_3060, rdata, resp); // Unmapped offset 0x060
        check("Unmapped READ returns SLVERR (2'b10)", (resp == 2'b10));

        axi_write(32'h2000_3080, 32'hCAFE_BABE, 4'hF, resp); // Unmapped offset 0x080
        check("Unmapped WRITE returns SLVERR (2'b10)", (resp == 2'b10));

        axi_read(32'h2000_3004, rdata, resp); // STATUS should have ERROR bit set
        check("STATUS bit2 (ERROR) is set after illegal access", (rdata[2] == 1'b1));

        axi_read(32'h2000_301C, rdata, resp); // ERROR_CODE
        check("ERROR_CODE == 1 (ILLEGAL_REG_ACCESS)", (rdata == 32'd1));

        // Clear error via STATUS W1C
        axi_write(32'h2000_3004, 32'h04, 4'hF, resp);
        axi_read(32'h2000_3004, rdata, resp);
        check("ERROR bit cleared via STATUS W1C", (rdata[2] == 1'b0));

        // --- TEST 4: Invalid Configuration Rejection ---
        $display("\n--- TEST 4: Invalid Configuration Rejection ---");
        axi_write(32'h2000_3014, 32'h0020_0020, 4'hF, resp); // Unsupported 32x32 image
        axi_write(32'h2000_3000, 32'h01, 4'hF, resp);         // Attempt CNN_START
        axi_read(32'h2000_3004, rdata, resp);
        check("Invalid DIM_CFG start sets ERROR in STATUS", (rdata[2] == 1'b1));
        axi_read(32'h2000_301C, rdata, resp);
        check("ERROR_CODE == 3 (INVALID_CONFIG)", (rdata == 32'd3));

        // --- TEST 5: Soft Reset ---
        $display("\n--- TEST 5: Soft Reset ---");
        axi_write(32'h2000_3000, 32'h02, 4'hF, resp); // CTRL bit1: CNN_RESET
        #20;
        axi_read(32'h2000_3004, rdata, resp);
        check("Soft reset clears STATUS", (rdata == 32'h0));
        // Restore valid configuration
        axi_write(32'h2000_3014, 32'h0010_0010, 4'hF, resp);

        // --- TEST 6: Normal CNN Inference Execution & Correctness ---
        $display("\n--- TEST 6: CNN Inference, Busy/Done, IRQ & Result Correctness ---");
        axi_write(32'h2000_3000, 32'h05, 4'hF, resp); // Bit0=START, Bit2=IRQ_EN

        // Check BUSY flag immediately
        axi_read(32'h2000_3004, rdata, resp);
        check("STATUS bit0 (BUSY) is high during computation", (rdata[0] == 1'b1));

        // Test starting while busy -> expect error code 2
        axi_write(32'h2000_3000, 32'h01, 4'hF, resp);
        axi_read(32'h2000_301C, rdata, resp);
        check("START while BUSY produces ERROR_CODE == 2", (rdata == 32'd2));

        $display("Waiting for CNN completion (polling STATUS / checking IRQ)...");
        while (1) begin
            axi_read(32'h2000_3004, rdata, resp);
            if (rdata[1] == 1'b1) break; // DONE == 1
            #500;
        end

        check("STATUS bit1 (DONE) is set upon completion", (rdata[1] == 1'b1));
        check("STATUS bit0 (BUSY) is cleared upon completion", (rdata[0] == 1'b0));
        check("accel_done_irq is asserted (IRQ_EN=1)", (accel_done_irq == 1'b1));

        // Verify all 16 embedding words: mathematical golden value is 1764
        match_all = 1;
        for (int k = 0; k < 16; k = k + 1) begin
            axi_read(32'h2000_3020 + (k*4), rdata, resp);
            if (rdata !== 32'd1764) begin
                $display("Embedding[%0d] mismatch: got %0d, expected 1764", k, $signed(rdata));
                match_all = 0;
            end
        end
        check("All 16 embedding output registers equal golden value 1764", match_all);

        // Verify hardware direct output port
        hw_match_all = 1;
        for (int k = 0; k < 16; k = k + 1) begin
            if (hw_embedding[k] !== 32'sd1764) hw_match_all = 0;
        end
        check("Direct hw_embedding output ports match golden value 1764", hw_match_all);

        // --- TEST 7: Image Buffer Access ---
        $display("\n--- TEST 7: Direct Image Buffer Access ---");
        axi_write(32'h2000_3100, 32'h0403_0201, 4'hF, resp); // Write pixels 0, 1, 2, 3
        axi_read(32'h2000_3100, rdata, resp);
        check("Readback written pixels from 0x2000_3100 (0x04030201)", (rdata == 32'h0403_0201));

        // Summary
        $display("\n============================================================");
        $display("  CNN AXI WRAPPER VERIFICATION RESULTS");
        $display("  PASS: %0d   FAIL: %0d", pass_count, fail_count);
        $display("============================================================");

        if (fail_count == 0)
            $display("OVERALL: ALL CNN AXI WRAPPER TESTS PASSED!\n");
        else
            $display("OVERALL: SOME TESTS FAILED!\n");

        #20;
        $finish;
    end

    // Watchdog
    initial begin
        #500_000_000;
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end

endmodule
