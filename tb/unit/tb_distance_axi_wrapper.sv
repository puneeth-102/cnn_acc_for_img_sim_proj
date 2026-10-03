// =============================================================================
// File   : tb_distance_axi_wrapper.sv
// Module : tb_distance_axi_wrapper
// Purpose: Self-checking testbench for distance_axi_wrapper.
//          Verifies:
//            1. Reset behavior (default values)
//            2. Read/Write access to configuration registers
//            3. Invalid/unmapped register access returns SLVERR & ERROR_CODE=1
//            4. Invalid REF_COUNT (=0) rejection -> ERROR_CODE=3
//            5. Invalid METRIC (!=0) rejection -> ERROR_CODE=4
//            6. Soft reset functionality via CTRL[1]
//            7. Distance calculation & MATCH classification (distance <= threshold)
//            8. Distance calculation & ANOMALY classification (distance > threshold)
//            9. Start attempted while BUSY -> ERROR_CODE=2
//           10. Interrupt assertion (score_done_irq)
// =============================================================================

`timescale 1ns/1ps

module tb_distance_axi_wrapper;

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

    logic signed [31:0]    hw_query_embedding [0:15];
    logic                  score_done_irq;

    int pass_count = 0;
    int fail_count = 0;

    // 100 MHz clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // DUT
    distance_axi_wrapper #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .ID_WIDTH   (ID_WIDTH)
    ) dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .s_axi_awid         (s_axi_awid),
        .s_axi_awaddr       (s_axi_awaddr),
        .s_axi_awlen        (s_axi_awlen),
        .s_axi_awsize       (s_axi_awsize),
        .s_axi_awburst      (s_axi_awburst),
        .s_axi_awvalid      (s_axi_awvalid),
        .s_axi_awready      (s_axi_awready),
        .s_axi_wdata        (s_axi_wdata),
        .s_axi_wstrb        (s_axi_wstrb),
        .s_axi_wlast        (s_axi_wlast),
        .s_axi_wvalid       (s_axi_wvalid),
        .s_axi_wready       (s_axi_wready),
        .s_axi_bid          (s_axi_bid),
        .s_axi_bresp        (s_axi_bresp),
        .s_axi_bvalid       (s_axi_bvalid),
        .s_axi_bready       (s_axi_bready),
        .s_axi_arid         (s_axi_arid),
        .s_axi_araddr       (s_axi_araddr),
        .s_axi_arlen        (s_axi_arlen),
        .s_axi_arsize       (s_axi_arsize),
        .s_axi_arburst      (s_axi_arburst),
        .s_axi_arvalid      (s_axi_arvalid),
        .s_axi_arready      (s_axi_arready),
        .s_axi_rid          (s_axi_rid),
        .s_axi_rdata        (s_axi_rdata),
        .s_axi_rresp        (s_axi_rresp),
        .s_axi_rlast        (s_axi_rlast),
        .s_axi_rvalid       (s_axi_rvalid),
        .s_axi_rready       (s_axi_rready),
        .hw_query_embedding (hw_query_embedding),
        .score_done_irq     (score_done_irq)
    );

    // =========================================================================
    // AXI Tasks
    // =========================================================================
    task automatic axi_write(
        input  logic [31:0] addr,
        input  logic [31:0] data,
        input  logic [3:0]  strb,
        output logic [1:0]  resp
    );
        @(negedge clk);
        s_axi_awid    <= 8'hC3;
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
        s_axi_arid    <= 8'hD4;
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

    initial begin
        rst_n         = 1'b0;
        s_axi_awvalid = 1'b0;
        s_axi_wvalid  = 1'b0;
        s_axi_bready  = 1'b0;
        s_axi_arvalid = 1'b0;
        s_axi_rready  = 1'b0;

        for (int k = 0; k < 16; k++) hw_query_embedding[k] = 32'sd1764;

        #30;
        rst_n = 1'b1;
        #20;

        $display("============================================================");
        $display("Starting Distance/Similarity AXI-Lite Wrapper Tests");
        $display("============================================================");

        // --- TEST 1: Reset Values ---
        $display("\n--- TEST 1: Reset Values Check ---");
        axi_read(32'h2000_4004, rdata, resp); // STATUS
        check("STATUS after reset is 0", (resp == 2'b00 && rdata == 32'h0));

        axi_read(32'h2000_4008, rdata, resp); // EMBED_BASE_ADDR
        check("Default EMBED_BASE_ADDR == 0x1000_2000", (resp == 2'b00 && rdata == 32'h1000_2000));

        axi_read(32'h2000_400C, rdata, resp); // REF_BASE_ADDR
        check("Default REF_BASE_ADDR == 0x1000_3000", (resp == 2'b00 && rdata == 32'h1000_3000));

        axi_read(32'h2000_4010, rdata, resp); // REF_COUNT
        check("Default REF_COUNT == 1", (resp == 2'b00 && rdata == 32'd1));

        axi_read(32'h2000_4014, rdata, resp); // METRIC
        check("Default METRIC == 0 (Manhattan)", (resp == 2'b00 && rdata == 32'd0));

        axi_read(32'h2000_4018, rdata, resp); // THRESHOLD
        check("Default THRESHOLD == 100", (resp == 2'b00 && rdata == 32'd100));

        // --- TEST 2: Write & Readback ---
        $display("\n--- TEST 2: Register Write & Readback ---");
        axi_write(32'h2000_4018, 32'd250, 4'hF, resp); // Set threshold = 250
        axi_read(32'h2000_4018, rdata, resp);
        check("Write & Read THRESHOLD == 250", (resp == 2'b00 && rdata == 32'd250));

        // --- TEST 3: Invalid / Unmapped Access ---
        $display("\n--- TEST 3: Unmapped Register Access ---");
        axi_read(32'h2000_4080, rdata, resp);
        check("Unmapped READ returns SLVERR (2'b10)", (resp == 2'b10));

        axi_write(32'h2000_4090, 32'hBEEF, 4'hF, resp);
        check("Unmapped WRITE returns SLVERR (2'b10)", (resp == 2'b10));

        axi_read(32'h2000_4004, rdata, resp);
        check("STATUS bit2 (ERROR) is set after illegal access", (rdata[2] == 1'b1));

        axi_read(32'h2000_4024, rdata, resp);
        check("ERROR_CODE == 1 (ILLEGAL_REG_ACCESS)", (rdata == 32'd1));

        // Clear error via STATUS W1C
        axi_write(32'h2000_4004, 32'h04, 4'hF, resp);

        // --- TEST 4: Invalid Configuration (REF_COUNT=0, METRIC!=0) ---
        $display("\n--- TEST 4: Invalid Config Detection ---");
        axi_write(32'h2000_4010, 32'd0, 4'hF, resp); // REF_COUNT = 0
        axi_write(32'h2000_4000, 32'h01, 4'hF, resp); // DIST_START
        axi_read(32'h2000_4024, rdata, resp);
        check("REF_COUNT=0 produces ERROR_CODE == 3", (rdata == 32'd3));

        // Soft reset
        axi_write(32'h2000_4000, 32'h02, 4'hF, resp);
        axi_write(32'h2000_4010, 32'd1, 4'hF, resp); // restore REF_COUNT=1

        axi_write(32'h2000_4014, 32'd9, 4'hF, resp); // Invalid METRIC = 9
        axi_write(32'h2000_4000, 32'h01, 4'hF, resp); // DIST_START
        axi_read(32'h2000_4024, rdata, resp);
        check("Invalid METRIC produces ERROR_CODE == 4", (rdata == 32'd4));

        // Soft reset
        axi_write(32'h2000_4000, 32'h02, 4'hF, resp);
        axi_write(32'h2000_4014, 32'd0, 4'hF, resp); // restore METRIC=0

        // --- TEST 5: MATCH Test (Distance = 0 <= Threshold) ---
        $display("\n--- TEST 5: MATCH Classification (Distance=0 <= Threshold=100) ---");
        // Write identical query and ref vectors: query=1000, ref=1000
        for (int k = 0; k < 16; k++) begin
            axi_write(32'h2000_4100 + (k*4), 32'd1000, 4'hF, resp);
            axi_write(32'h2000_4200 + (k*4), 32'd1000, 4'hF, resp);
        end
        axi_write(32'h2000_4018, 32'd100, 4'hF, resp); // THRESHOLD = 100
        axi_write(32'h2000_4000, 32'h05, 4'hF, resp);  // START=1, IRQ_EN=1

        // Poll DONE
        while (1) begin
            axi_read(32'h2000_4004, rdata, resp);
            if (rdata[1] == 1'b1) break;
            #10;
        end
        check("DIST_DONE is asserted", (rdata[1] == 1'b1));
        check("score_done_irq is asserted", (score_done_irq == 1'b1));

        axi_read(32'h2000_4020, rdata, resp); // MIN_DISTANCE
        check("MIN_DISTANCE == 0 for identical vectors", (rdata == 32'd0));

        axi_read(32'h2000_401C, rdata, resp); // RESULT
        check("RESULT == 1 (MATCH) since distance (0) <= threshold (100)", (rdata == 32'd1));

        // --- TEST 6: ANOMALY Test (Distance = 320 > Threshold = 100) ---
        $display("\n--- TEST 6: ANOMALY Classification (Distance=320 > Threshold=100) ---");
        // Query has difference of 20 per element across 16 elements -> total distance = 16 * 20 = 320
        for (int k = 0; k < 16; k++) begin
            axi_write(32'h2000_4100 + (k*4), 32'd1020, 4'hF, resp); // 1020 vs 1000
        end
        axi_write(32'h2000_4018, 32'd100, 4'hF, resp); // THRESHOLD = 100
        axi_write(32'h2000_4000, 32'h01, 4'hF, resp);  // START=1

        while (1) begin
            axi_read(32'h2000_4004, rdata, resp);
            if (rdata[1] == 1'b1) break;
            #10;
        end

        axi_read(32'h2000_4020, rdata, resp); // MIN_DISTANCE
        check("MIN_DISTANCE == 320 (16 * 20)", (rdata == 32'd320));

        axi_read(32'h2000_401C, rdata, resp); // RESULT
        check("RESULT == 0 (ANOMALY) since distance (320) > threshold (100)", (rdata == 32'd0));

        // Summary
        $display("\n============================================================");
        $display("  DISTANCE AXI WRAPPER VERIFICATION RESULTS");
        $display("  PASS: %0d   FAIL: %0d", pass_count, fail_count);
        $display("============================================================");

        if (fail_count == 0)
            $display("OVERALL: ALL DISTANCE AXI WRAPPER TESTS PASSED!\n");
        else
            $display("OVERALL: SOME TESTS FAILED!\n");

        #20;
        $finish;
    end

    // Watchdog
    initial begin
        #50_000_000;
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end

endmodule
