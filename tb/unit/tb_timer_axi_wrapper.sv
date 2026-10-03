// =============================================================================
// File   : tb_timer_axi_wrapper.sv
// Module : tb_timer_axi_wrapper
// Purpose: Standalone self-checking AXI4-Lite verification testbench for
//          timer_axi_wrapper integrating OpenTitan timer_core.
// =============================================================================

`timescale 1ns/1ps

module tb_timer_axi_wrapper;

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

    logic                  timer_irq_o;

    int pass_count = 0;
    int fail_count = 0;

    // Clock generation (100 MHz)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // DUT
    timer_axi_wrapper #(
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
        .timer_irq_o    (timer_irq_o)
    );

    // =========================================================================
    // AXI Bus Tasks
    // =========================================================================
    task automatic axi_write(
        input  logic [31:0] addr,
        input  logic [31:0] data,
        input  logic [3:0]  strb,
        output logic [1:0]  resp
    );
        int timeout;
        @(negedge clk);
        s_axi_awid    <= 8'h01;
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

        timeout = 0;
        fork
            begin
                while (!(s_axi_awvalid && s_axi_awready) && timeout < 100) begin
                    @(posedge clk); timeout++;
                end
                @(negedge clk); s_axi_awvalid <= 1'b0;
            end
            begin
                while (!(s_axi_wvalid && s_axi_wready) && timeout < 100) begin
                    @(posedge clk); timeout++;
                end
                @(negedge clk); s_axi_wvalid <= 1'b0;
            end
        join

        timeout = 0;
        while (!(s_axi_bvalid && s_axi_bready) && timeout < 100) begin
            @(posedge clk); timeout++;
        end
        resp = s_axi_bresp;
        @(negedge clk);
        s_axi_bready <= 1'b0;
    endtask

    task automatic axi_read(
        input  logic [31:0] addr,
        output logic [31:0] data,
        output logic [1:0]  resp
    );
        int timeout;
        @(negedge clk);
        s_axi_arid    <= 8'h02;
        s_axi_araddr  <= addr;
        s_axi_arlen   <= 8'd0;
        s_axi_arsize  <= 3'b010;
        s_axi_arburst <= 2'b01;
        s_axi_arvalid <= 1'b1;
        s_axi_rready  <= 1'b1;

        timeout = 0;
        while (!(s_axi_arvalid && s_axi_arready) && timeout < 100) begin
            @(posedge clk); timeout++;
        end
        @(negedge clk); s_axi_arvalid <= 1'b0;

        timeout = 0;
        while (!(s_axi_rvalid && s_axi_rready) && timeout < 100) begin
            @(posedge clk); timeout++;
        end
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

        #30;
        rst_n = 1'b1;
        #20;

        $display("============================================================");
        $display("Starting RISC-V Timer (OpenTitan timer_core) AXI-Lite Tests");
        $display("============================================================");

        // --- TEST 1: Reset Values ---
        $display("\n--- TEST 1: Reset Values Check ---");
        axi_read(32'h2000_1000, rdata, resp); // CTRL
        check("CTRL after reset is 0 (timer inactive)", (resp == 2'b00 && rdata == 32'h0));

        axi_read(32'h2000_1008, rdata, resp); // INTR_ENABLE
        check("INTR_ENABLE after reset is 0", (resp == 2'b00 && rdata == 32'h0));

        axi_read(32'h2000_1010, rdata, resp); // CFG
        check("Default CFG is step=1, prescale=0", (resp == 2'b00 && rdata[23:16] == 8'd1 && rdata[11:0] == 12'd0));

        axi_read(32'h2000_1014, rdata, resp); // MTIME_LOW
        check("Default MTIME_LOW == 0", (resp == 2'b00 && rdata == 32'd0));

        axi_read(32'h2000_101C, rdata, resp); // MTIMECMP_LOW
        check("Default MTIMECMP_LOW == 0xFFFF_FFFF", (resp == 2'b00 && rdata == 32'hFFFF_FFFF));

        // --- TEST 2: Register Write & Readback ---
        $display("\n--- TEST 2: Register Write & Readback ---");
        axi_write(32'h2000_1010, {8'h0, 8'd5, 4'h0, 12'd10}, 4'hF, resp); // step=5, prescale=10
        axi_read(32'h2000_1010, rdata, resp);
        check("Write & Read CFG (step=5, prescale=10)", (resp == 2'b00 && rdata[23:16] == 8'd5 && rdata[11:0] == 12'd10));

        axi_write(32'h2000_1014, 32'h1234_5678, 4'hF, resp); // MTIME_LOW
        axi_read(32'h2000_1014, rdata, resp);
        check("Write & Read MTIME_LOW (0x1234_5678)", (resp == 2'b00 && rdata == 32'h1234_5678));

        axi_write(32'h2000_1018, 32'h0000_00AB, 4'hF, resp); // MTIME_HIGH
        axi_read(32'h2000_1018, rdata, resp);
        check("Write & Read MTIME_HIGH (0xAB)", (resp == 2'b00 && rdata == 32'hAB));

        axi_write(32'h2000_101C, 32'h8765_4321, 4'hF, resp); // MTIMECMP_LOW
        axi_read(32'h2000_101C, rdata, resp);
        check("Write & Read MTIMECMP_LOW (0x8765_4321)", (resp == 2'b00 && rdata == 32'h8765_4321));

        // --- TEST 3: OpenTitan Alias Offsets (0x100+) ---
        $display("\n--- TEST 3: OpenTitan rv_timer Register Offsets (0x100+) ---");
        axi_write(32'h2000_1100, 32'h1, 4'hF, resp); // INTR_ENABLE0
        axi_read(32'h2000_1008, rdata, resp);       // read back via standard offset
        check("INTR_ENABLE0 at 0x100 updates INTR_ENABLE at 0x008", (resp == 2'b00 && rdata == 32'h1));

        axi_write(32'h2000_1110, 32'hDEAD_0001, 4'hF, resp); // TIMER_V_LOWER0
        axi_read(32'h2000_1014, rdata, resp);                 // MTIME_LOW
        check("TIMER_V_LOWER0 at 0x110 updates MTIME_LOW at 0x014", (resp == 2'b00 && rdata == 32'hDEAD_0001));

        // --- TEST 4: Unmapped Register Access Handling ---
        $display("\n--- TEST 4: Unmapped Register Access ---");
        axi_read(32'h2000_1080, rdata, resp);
        check("Unmapped READ returns SLVERR (2'b10)", (resp == 2'b10));
        check("Unmapped READ returns 0xDEAD_BEEF", (rdata == 32'hDEAD_BEEF));

        axi_write(32'h2000_1090, 32'hCAFE, 4'hF, resp);
        check("Unmapped WRITE returns SLVERR (2'b10)", (resp == 2'b10));

        axi_read(32'h2000_1024, rdata, resp); // ERROR_CODE
        check("ERROR_CODE == 1 after illegal access", (resp == 2'b00 && rdata == 32'd1));

        // --- TEST 5: Soft Reset ---
        $display("\n--- TEST 5: Soft Reset Verification ---");
        axi_write(32'h2000_1000, 32'h2, 4'hF, resp); // CTRL[1] = 1 (reset)
        axi_read(32'h2000_1014, rdata, resp);         // MTIME_LOW
        check("Soft reset clears MTIME_LOW to 0", (resp == 2'b00 && rdata == 32'd0));
        axi_read(32'h2000_1024, rdata, resp);         // ERROR_CODE
        check("Soft reset clears ERROR_CODE to 0", (resp == 2'b00 && rdata == 32'd0));

        // --- TEST 6: Timer Counting & Increment ---
        $display("\n--- TEST 6: Timer Counting Operation ---");
        // Configure: step = 1, prescale = 0 (increments every cycle)
        axi_write(32'h2000_1010, {8'h0, 8'd1, 4'h0, 12'd0}, 4'hF, resp); // CFG
        axi_write(32'h2000_1014, 32'd0, 4'hF, resp);                      // MTIME_LOW = 0
        axi_write(32'h2000_1018, 32'd0, 4'hF, resp);                      // MTIME_HIGH = 0
        axi_write(32'h2000_1000, 32'h1, 4'hF, resp);                      // CTRL[0] = 1 (active)

        #100; // Let timer run for 10 clock cycles (100 ns)
        axi_read(32'h2000_1014, rdata, resp);
        check("Timer is active and MTIME_LOW is incrementing (> 0)", (resp == 2'b00 && rdata > 0));

        // --- TEST 7: Compare Match & Interrupt Generation ---
        $display("\n--- TEST 7: Compare Match & Interrupt Assertion ---");
        // Stop timer, reset counter to 0
        axi_write(32'h2000_1000, 32'h0, 4'hF, resp);
        axi_write(32'h2000_1014, 32'd0, 4'hF, resp);
        axi_write(32'h2000_1018, 32'd0, 4'hF, resp);

        // Set compare threshold = 15
        axi_write(32'h2000_101C, 32'd15, 4'hF, resp);
        axi_write(32'h2000_1020, 32'd0, 4'hF, resp);

        // Enable interrupt
        axi_write(32'h2000_1008, 32'h1, 4'hF, resp);

        // Start timer
        axi_write(32'h2000_1000, 32'h1, 4'hF, resp);

        // Wait for counter to reach 15
        #250;
        check("Dedicated timer_irq_o pin asserted upon compare match", timer_irq_o == 1'b1);

        axi_read(32'h2000_100C, rdata, resp); // INTR_STATE
        check("INTR_STATE reports interrupt active (IS=1)", (resp == 2'b00 && rdata[0] == 1'b1));

        // --- TEST 8: INTR_TEST0 Software Injection ---
        $display("\n--- TEST 8: OpenTitan INTR_TEST0 Software Trigger ---");
        // Clear previous interrupt by advancing mtimecmp beyond mtime
        axi_write(32'h2000_101C, 32'hFFFF_FFFF, 4'hF, resp);
        axi_write(32'h2000_100C, 32'h1, 4'hF, resp); // Clear INTR_STATE W1C
        #20;
        check("timer_irq_o deasserts after compare cleared and W1C", timer_irq_o == 1'b0);

        // Trigger software interrupt via INTR_TEST0 (0x108)
        axi_write(32'h2000_1108, 32'h1, 4'hF, resp);
        #10;
        check("Software interrupt injection via INTR_TEST0 asserts timer_irq_o", timer_irq_o == 1'b1);

        // =====================================================================
        // Summary
        // =====================================================================
        $display("\n============================================================");
        $display("  TIMER AXI WRAPPER VERIFICATION RESULTS");
        $display("  PASS: %0d   FAIL: %0d   TOTAL: %0d", pass_count, fail_count, pass_count + fail_count);
        $display("============================================================");

        if (fail_count == 0)
            $display("OVERALL: ALL TIMER AXI WRAPPER TESTS PASSED!\n");
        else
            $display("OVERALL: SOME TESTS FAILED!\n");

        #50;
        $finish;
    end

    // Safety watchdog
    initial begin
        #50_000_000;
        $display("[ERROR] Watchdog timeout!");
        $finish;
    end

endmodule
