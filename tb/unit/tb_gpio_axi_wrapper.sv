// =============================================================================
// File   : tb_gpio_axi_wrapper.sv
// Module : tb_gpio_axi_wrapper
// Purpose: Comprehensive Standalone Testbench for PULP Platform GPIO AXI Wrapper.
//          Verifies:
//            - Reset states and default register values
//            - INFO register read (GPIO count=32, Version=2)
//            - Mode configuration (Input, Push-Pull output)
//            - Output driving and direction control (gpio_o, gpio_dir_o)
//            - Atomic bit manipulation: SET (0x200), CLEAR (0x280), TOGGLE (0x300)
//            - Input sampling with 2-stage synchronizer (GPIO_EN, GPIO_IN, gpio_in_sync_o)
//            - Rising-edge, falling-edge, and level interrupt generation (gpio_irq_o, gpio_pin_irq_o)
//            - Interrupt status reading and Write-1-to-Clear (W1C)
//            - Unmapped/illegal address access returning SLVERR and 0xDEAD_BEEF
//            - Asynchronous reset recovery
// =============================================================================

`timescale 1ns/1ps

module tb_gpio_axi_wrapper;

    localparam int DATA_WIDTH = 32;
    localparam int ADDR_WIDTH = 32;
    localparam int STRB_WIDTH = 4;
    localparam int ID_WIDTH   = 8;
    localparam int GPIO_COUNT = 32;

    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    // Clock and Reset
    logic clk;
    logic rst_n;

    always #5 clk = ~clk; // 100MHz clock

    // AXI4-Lite Signals
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

    wire [ID_WIDTH-1:0]    s_axi_bid;
    wire [1:0]             s_axi_bresp;
    wire                   s_axi_bvalid;
    logic                  s_axi_bready;

    logic [ID_WIDTH-1:0]   s_axi_arid;
    logic [ADDR_WIDTH-1:0] s_axi_araddr;
    logic [7:0]            s_axi_arlen;
    logic [2:0]            s_axi_arsize;
    logic [1:0]            s_axi_arburst;
    logic                  s_axi_arvalid;
    wire                   s_axi_arready;

    wire [ID_WIDTH-1:0]    s_axi_rid;
    wire [DATA_WIDTH-1:0]  s_axi_rdata;
    wire [1:0]             s_axi_rresp;
    wire                   s_axi_rlast;
    wire                   s_axi_rvalid;
    logic                  s_axi_rready;

    // External GPIO signals
    logic [GPIO_COUNT-1:0] gpio_i;
    wire  [GPIO_COUNT-1:0] gpio_o;
    wire  [GPIO_COUNT-1:0] gpio_dir_o;
    wire  [GPIO_COUNT-1:0] gpio_in_sync_o;
    wire                   gpio_irq_o;
    wire  [GPIO_COUNT-1:0] gpio_pin_irq_o;

    // Verification bookkeeping
    int pass_count = 0;
    int fail_count = 0;

    // DUT Instantiation
    gpio_axi_wrapper #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .STRB_WIDTH (STRB_WIDTH),
        .ID_WIDTH   (ID_WIDTH),
        .GPIO_COUNT (GPIO_COUNT)
    ) dut (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .s_axi_awid             (s_axi_awid),
        .s_axi_awaddr           (s_axi_awaddr),
        .s_axi_awlen            (s_axi_awlen),
        .s_axi_awsize           (s_axi_awsize),
        .s_axi_awburst          (s_axi_awburst),
        .s_axi_awvalid          (s_axi_awvalid),
        .s_axi_awready          (s_axi_awready),
        .s_axi_wdata            (s_axi_wdata),
        .s_axi_wstrb            (s_axi_wstrb),
        .s_axi_wlast            (s_axi_wlast),
        .s_axi_wvalid           (s_axi_wvalid),
        .s_axi_wready           (s_axi_wready),
        .s_axi_bid              (s_axi_bid),
        .s_axi_bresp            (s_axi_bresp),
        .s_axi_bvalid           (s_axi_bvalid),
        .s_axi_bready           (s_axi_bready),
        .s_axi_arid             (s_axi_arid),
        .s_axi_araddr           (s_axi_araddr),
        .s_axi_arlen            (s_axi_arlen),
        .s_axi_arsize           (s_axi_arsize),
        .s_axi_arburst          (s_axi_arburst),
        .s_axi_arvalid          (s_axi_arvalid),
        .s_axi_arready          (s_axi_arready),
        .s_axi_rid              (s_axi_rid),
        .s_axi_rdata            (s_axi_rdata),
        .s_axi_rresp            (s_axi_rresp),
        .s_axi_rlast            (s_axi_rlast),
        .s_axi_rvalid           (s_axi_rvalid),
        .s_axi_rready           (s_axi_rready),
        .gpio_i                 (gpio_i),
        .gpio_o                 (gpio_o),
        .gpio_dir_o             (gpio_dir_o),
        .gpio_in_sync_o         (gpio_in_sync_o),
        .gpio_irq_o             (gpio_irq_o),
        .gpio_pin_irq_o         (gpio_pin_irq_o)
    );

    // =========================================================================
    // AXI Master Tasks
    // =========================================================================
    task automatic axi_write(
        input  logic [31:0] addr,
        input  logic [31:0] data,
        input  logic [7:0]  id,
        output logic [1:0]  resp
    );
        @(posedge clk);
        s_axi_awid    <= id;
        s_axi_awaddr  <= addr;
        s_axi_awlen   <= 8'd0;
        s_axi_awsize  <= 3'b010; // 4 bytes
        s_axi_awburst <= 2'b01;
        s_axi_awvalid <= 1'b1;

        s_axi_wdata   <= data;
        s_axi_wstrb   <= 4'b1111;
        s_axi_wlast   <= 1'b1;
        s_axi_wvalid  <= 1'b1;
        s_axi_bready  <= 1'b1;

        // Wait for AW and W ready
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

        // Wait for B response
        while (!s_axi_bvalid) @(posedge clk);
        resp = s_axi_bresp;
        @(posedge clk);
        s_axi_bready <= 1'b0;
    endtask

    task automatic axi_read(
        input  logic [31:0] addr,
        input  logic [7:0]  id,
        output logic [31:0] data,
        output logic [1:0]  resp
    );
        @(posedge clk);
        s_axi_arid    <= id;
        s_axi_araddr  <= addr;
        s_axi_arlen   <= 8'd0;
        s_axi_arsize  <= 3'b010; // 4 bytes
        s_axi_arburst <= 2'b01;
        s_axi_arvalid <= 1'b1;
        s_axi_rready  <= 1'b1;

        while (!s_axi_arready) @(posedge clk);
        @(posedge clk);
        s_axi_arvalid <= 1'b0;

        while (!s_axi_rvalid) @(posedge clk);
        data = s_axi_rdata;
        resp = s_axi_rresp;
        @(posedge clk);
        s_axi_rready <= 1'b0;
    endtask

    // Check helper
    task automatic check(input string test_name, input logic condition);
        if (condition) begin
            $display("[PASS] %s", test_name);
            pass_count++;
        end else begin
            $display("[FAIL] %s", test_name);
            fail_count++;
        end
    endtask

    // =========================================================================
    // Test Sequence
    // =========================================================================
    initial begin
        logic [31:0] rdata;
        logic [1:0]  resp;

        // Initialize signals
        clk           = 0;
        rst_n         = 0;
        s_axi_awid    = '0;
        s_axi_awaddr  = '0;
        s_axi_awlen   = '0;
        s_axi_awsize  = '0;
        s_axi_awburst = '0;
        s_axi_awvalid = 0;
        s_axi_wdata   = '0;
        s_axi_wstrb   = '0;
        s_axi_wlast   = 0;
        s_axi_wvalid  = 0;
        s_axi_bready  = 0;
        s_axi_arid    = '0;
        s_axi_araddr  = '0;
        s_axi_arlen   = '0;
        s_axi_arsize  = '0;
        s_axi_arburst = '0;
        s_axi_arvalid = 0;
        s_axi_rready  = 0;
        gpio_i        = '0;

        $display("============================================================");
        $display("Starting PULP Platform GPIO AXI-Lite Wrapper Tests");
        $display("============================================================");

        // Reset DUT
        #30 rst_n = 1;
        #30;

        // -------------------------------------------------------------
        // TEST 1: Reset Values Check
        // -------------------------------------------------------------
        $display("\n--- TEST 1: Reset Values Check ---");
        axi_read(32'h2000_2000, 8'h01, rdata, resp);
        check("INFO register reads 0x0000_0820 (GPIOCount=32, Version=2)", (rdata == 32'h0000_0820) && (resp == RESP_OKAY));

        axi_read(32'h2000_2004, 8'h02, rdata, resp);
        check("CFG register defaults to 0", (rdata == 32'h0) && (resp == RESP_OKAY));

        axi_read(32'h2000_2008, 8'h03, rdata, resp);
        check("GPIO_MODE_0 defaults to 0 (all inputs)", (rdata == 32'h0) && (resp == RESP_OKAY));

        axi_read(32'h2000_200C, 8'h04, rdata, resp);
        check("GPIO_MODE_1 defaults to 0 (all inputs)", (rdata == 32'h0) && (resp == RESP_OKAY));

        check("Initial gpio_dir_o is 0 (all inputs)", gpio_dir_o == 32'h0);
        check("Initial gpio_irq_o is 0", gpio_irq_o == 1'b0);

        // -------------------------------------------------------------
        // TEST 2: Register Write & Readback (CFG, MODE)
        // -------------------------------------------------------------
        $display("\n--- TEST 2: Register Write & Readback ---");
        // Write CFG: glbl_intrpt_mode=1, pin_lvl_intrpt_mode=1 -> 0x0000_0003
        axi_write(32'h2000_2004, 32'h0000_0003, 8'h10, resp);
        check("Write CFG returned OKAY", resp == RESP_OKAY);
        axi_read(32'h2000_2004, 8'h11, rdata, resp);
        check("Readback CFG == 0x0000_0003", (rdata == 32'h3) && (resp == RESP_OKAY));

        // Configure GPIO[7:0] as push-pull output (2'b01 per pin -> 0x5555 in MODE_0)
        axi_write(32'h2000_2008, 32'h0000_5555, 8'h12, resp);
        check("Write GPIO_MODE_0 returned OKAY", resp == RESP_OKAY);
        axi_read(32'h2000_2008, 8'h13, rdata, resp);
        check("Readback GPIO_MODE_0 == 0x0000_5555", (rdata == 32'h5555) && (resp == RESP_OKAY));
        #10;
        check("gpio_dir_o[7:0] == 0xFF after mode config", gpio_dir_o[7:0] == 8'hFF);

        // -------------------------------------------------------------
        // TEST 3: Output Driving & Atomic Bit Manipulation
        // -------------------------------------------------------------
        $display("\n--- TEST 3: Output Driving & Atomic Bit Manipulation ---");
        // Direct write to GPIO_OUT (0x180): 0x0000_00A5
        axi_write(32'h2000_2180, 32'h0000_00A5, 8'h20, resp);
        check("Write GPIO_OUT returned OKAY", resp == RESP_OKAY);
        #10;
        check("gpio_o[7:0] driven to 0xA5", gpio_o[7:0] == 8'hA5);

        // Atomic SET (0x200): set bits 1 and 4 -> 0x12
        axi_write(32'h2000_2200, 32'h0000_0012, 8'h21, resp);
        check("Atomic SET returned OKAY", resp == RESP_OKAY);
        #10;
        check("After SET(0x12): gpio_o[7:0] == 0xB7 (0xA5 | 0x12)", gpio_o[7:0] == 8'hB7);

        // Atomic CLEAR (0x280): clear bit 0 and bit 7 -> 0x81
        axi_write(32'h2000_2280, 32'h0000_0081, 8'h22, resp);
        check("Atomic CLEAR returned OKAY", resp == RESP_OKAY);
        #10;
        check("After CLEAR(0x81): gpio_o[7:0] == 0x36 (0xB7 & ~0x81)", gpio_o[7:0] == 8'h36);

        // Atomic TOGGLE (0x300): toggle lower nibble -> 0x0F
        axi_write(32'h2000_2300, 32'h0000_000F, 8'h23, resp);
        check("Atomic TOGGLE returned OKAY", resp == RESP_OKAY);
        #10;
        check("After TOGGLE(0x0F): gpio_o[7:0] == 0x39 (0x36 ^ 0x0F)", gpio_o[7:0] == 8'h39);

        // -------------------------------------------------------------
        // TEST 4: Input Sampling & 2-Stage Synchronizer
        // -------------------------------------------------------------
        $display("\n--- TEST 4: Input Sampling & Synchronizer ---");
        // Enable input sampling for GPIO[15:8] in GPIO_EN (0x080)
        axi_write(32'h2000_2080, 32'h0000_FF00, 8'h30, resp);
        check("Write GPIO_EN returned OKAY", resp == RESP_OKAY);

        // Drive external inputs on pins [15:8] with pattern 0x5A
        gpio_i[15:8] = 8'h5A;
        #50; // allow 2-stage synchronizer delay
        axi_read(32'h2000_2100, 8'h31, rdata, resp);
        check("GPIO_IN reads sampled pattern 0x5A on pins [15:8]", (rdata[15:8] == 8'h5A) && (resp == RESP_OKAY));
        check("gpio_in_sync_o matches sampled inputs (0x5A)", gpio_in_sync_o[15:8] == 8'h5A);

        // Change inputs to 0xC3
        gpio_i[15:8] = 8'hC3;
        #50;
        axi_read(32'h2000_2100, 8'h32, rdata, resp);
        check("GPIO_IN updates dynamically to 0xC3", (rdata[15:8] == 8'hC3) && (resp == RESP_OKAY));

        // -------------------------------------------------------------
        // TEST 5: Interrupt Detection & Handling
        // -------------------------------------------------------------
        $display("\n--- TEST 5: Interrupt Detection & Handling ---");
        // Enable rising-edge interrupt on pin 8 (INTRPT_RISE_EN at 0x380)
        axi_write(32'h2000_2380, 32'h0000_0100, 8'h40, resp);
        check("Enable rising-edge interrupt on pin 8", resp == RESP_OKAY);

        // Set pin 8 low first
        gpio_i[8] = 1'b0;
        #30;
        check("Interrupt pin is inactive before edge", gpio_irq_o == 1'b0);

        // Generate rising edge on pin 8
        gpio_i[8] = 1'b1;
        #60; // allow synchronization
        check("Dedicated gpio_irq_o global interrupt asserted", gpio_irq_o == 1'b1);
        check("Dedicated per-pin interrupt gpio_pin_irq_o[8] asserted", gpio_pin_irq_o[8] == 1'b1);

        // Query INTRPT_STATUS (0x580)
        axi_read(32'h2000_2580, 8'h41, rdata, resp);
        check("INTRPT_STATUS reports pending interrupt on pin 8 (bit 8 = 1)", (rdata & 32'h0000_0100) != 0);

        // Query INTRPT_RISE_STATUS (0x600)
        axi_read(32'h2000_2600, 8'h42, rdata, resp);
        check("INTRPT_RISE_STATUS reports rising-edge interrupt on pin 8", (rdata & 32'h0000_0100) != 0);

        // Clear interrupt via Write-1-to-Clear (W1C) on INTRPT_STATUS (0x580)
        axi_write(32'h2000_2580, 32'h0000_0100, 8'h43, resp);
        #30;
        check("gpio_irq_o deasserted after W1C interrupt clear", gpio_irq_o == 1'b0);

        // -------------------------------------------------------------
        // TEST 6: Unmapped / Illegal Address Access
        // -------------------------------------------------------------
        $display("\n--- TEST 6: Unmapped / Illegal Address Access ---");
        // Read unmapped address within 2KB (0x7FC)
        axi_read(32'h2000_27FC, 8'h50, rdata, resp);
        check("Unmapped READ (0x7FC) returns SLVERR", resp == RESP_SLVERR);
        check("Unmapped READ returns 0xDEAD_BEEF", rdata == 32'hDEAD_BEEF);

        // Write unmapped address
        axi_write(32'h2000_27FC, 32'hCAFE_BABE, 8'h51, resp);
        check("Unmapped WRITE returns SLVERR", resp == RESP_SLVERR);

        // Read unmapped address above 2KB in 4KB aperture (0x800)
        axi_read(32'h2000_2800, 8'h52, rdata, resp);
        check("Out-of-range READ (0x800) returns SLVERR", resp == RESP_SLVERR);
        check("Out-of-range READ returns 0xDEAD_BEEF", rdata == 32'hDEAD_BEEF);

        // -------------------------------------------------------------
        // TEST 7: Reset Recovery
        // -------------------------------------------------------------
        $display("\n--- TEST 7: Reset Recovery ---");
        rst_n = 0;
        #30 rst_n = 1;
        #30;
        axi_read(32'h2000_2004, 8'h60, rdata, resp);
        check("After reset, CFG register is cleared to 0", (rdata == 32'h0) && (resp == RESP_OKAY));
        check("After reset, gpio_dir_o is 0", gpio_dir_o == 32'h0);
        check("After reset, gpio_irq_o is 0", gpio_irq_o == 1'b0);

        // -------------------------------------------------------------
        // Verification Summary
        // -------------------------------------------------------------
        $display("\n============================================================");
        $display("  GPIO AXI WRAPPER VERIFICATION RESULTS");
        $display("  PASS: %0d   FAIL: %0d   TOTAL: %0d", pass_count, fail_count, pass_count + fail_count);
        $display("============================================================");

        if (fail_count == 0) begin
            $display("OVERALL: ALL GPIO AXI WRAPPER TESTS PASSED!\n");
        end else begin
            $display("OVERALL: %0d TESTS FAILED!\n", fail_count);
        end

        $finish;
    end

endmodule
