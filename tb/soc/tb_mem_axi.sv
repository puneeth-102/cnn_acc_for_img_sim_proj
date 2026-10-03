// =============================================================================
// File   : tb_mem_axi.sv
// Module : tb_mem_axi
// Purpose: Comprehensive Testbench for IMEM and DMEM AXI4 Memory Modules.
//          Tests:
//            1. DMEM 32-bit word write and readback
//            2. DMEM byte-lane strobes (INT8 byte, INT16 halfword, INT32 word)
//            3. DMEM multi-beat burst writes and reads (INCR burst)
//            4. IMEM Port B write (firmware loader / LSU / DMA)
//            5. IMEM Port A read (CPU IFU instruction fetch)
//            6. IMEM true dual-port simultaneous concurrent operations
//            7. IMEM / DMEM firmware preloading verification via INIT_FILE
// =============================================================================

`timescale 1ns/1ps

module tb_mem_axi;

    localparam int DATA_WIDTH = 32;
    localparam int ADDR_WIDTH = 32;
    localparam int STRB_WIDTH = DATA_WIDTH / 8;
    localparam int ID_WIDTH   = 8;

    logic clk;
    logic rst_n;

    // Clock generation (100 MHz, 10ns period)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    int test_pass_count = 0;
    int test_fail_count = 0;

    // =========================================================================
    // Signals for DMEM Instance
    // =========================================================================
    logic [ID_WIDTH-1:0]    dmem_awid;
    logic [ADDR_WIDTH-1:0]  dmem_awaddr;
    logic [7:0]             dmem_awlen;
    logic [2:0]             dmem_awsize;
    logic [1:0]             dmem_awburst;
    logic                   dmem_awvalid;
    wire                    dmem_awready;

    logic [DATA_WIDTH-1:0]  dmem_wdata;
    logic [STRB_WIDTH-1:0]  dmem_wstrb;
    logic                   dmem_wlast;
    logic                   dmem_wvalid;
    wire                    dmem_wready;

    wire [ID_WIDTH-1:0]     dmem_bid;
    wire [1:0]              dmem_bresp;
    wire                    dmem_bvalid;
    logic                   dmem_bready;

    logic [ID_WIDTH-1:0]    dmem_arid;
    logic [ADDR_WIDTH-1:0]  dmem_araddr;
    logic [7:0]             dmem_arlen;
    logic [2:0]             dmem_arsize;
    logic [1:0]             dmem_arburst;
    logic                   dmem_arvalid;
    wire                    dmem_arready;

    wire [ID_WIDTH-1:0]     dmem_rid;
    wire [DATA_WIDTH-1:0]   dmem_rdata;
    wire [1:0]              dmem_rresp;
    wire                    dmem_rlast;
    wire                    dmem_rvalid;
    logic                   dmem_rready;

    // Instantiate DMEM
    dmem_axi #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .ID_WIDTH   (ID_WIDTH),
        .MEM_SIZE   (65536)
    ) u_dmem (
        .clk          (clk),
        .rst_n        (rst_n),
        .s_axi_awid   (dmem_awid),
        .s_axi_awaddr (dmem_awaddr),
        .s_axi_awlen  (dmem_awlen),
        .s_axi_awsize (dmem_awsize),
        .s_axi_awburst(dmem_awburst),
        .s_axi_awvalid(dmem_awvalid),
        .s_axi_awready(dmem_awready),
        .s_axi_wdata  (dmem_wdata),
        .s_axi_wstrb  (dmem_wstrb),
        .s_axi_wlast  (dmem_wlast),
        .s_axi_wvalid (dmem_wvalid),
        .s_axi_wready (dmem_wready),
        .s_axi_bid    (dmem_bid),
        .s_axi_bresp  (dmem_bresp),
        .s_axi_bvalid (dmem_bvalid),
        .s_axi_bready (dmem_bready),
        .s_axi_arid   (dmem_arid),
        .s_axi_araddr (dmem_araddr),
        .s_axi_arlen  (dmem_arlen),
        .s_axi_arsize (dmem_arsize),
        .s_axi_arburst(dmem_arburst),
        .s_axi_arvalid(dmem_arvalid),
        .s_axi_arready(dmem_arready),
        .s_axi_rid    (dmem_rid),
        .s_axi_rdata  (dmem_rdata),
        .s_axi_rresp  (dmem_rresp),
        .s_axi_rlast  (dmem_rlast),
        .s_axi_rvalid (dmem_rvalid),
        .s_axi_rready (dmem_rready)
    );

    // =========================================================================
    // Signals for IMEM Instance (Dual-Port)
    // =========================================================================
    // Port A (IFU)
    logic [ID_WIDTH-1:0]    imem_a_awid;
    logic [ADDR_WIDTH-1:0]  imem_a_awaddr;
    logic [7:0]             imem_a_awlen;
    logic [2:0]             imem_a_awsize;
    logic [1:0]             imem_a_awburst;
    logic                   imem_a_awvalid;
    wire                    imem_a_awready;
    logic [DATA_WIDTH-1:0]  imem_a_wdata;
    logic [STRB_WIDTH-1:0]  imem_a_wstrb;
    logic                   imem_a_wlast;
    logic                   imem_a_wvalid;
    wire                    imem_a_wready;
    wire [ID_WIDTH-1:0]     imem_a_bid;
    wire [1:0]              imem_a_bresp;
    wire                    imem_a_bvalid;
    logic                   imem_a_bready;
    logic [ID_WIDTH-1:0]    imem_a_arid;
    logic [ADDR_WIDTH-1:0]  imem_a_araddr;
    logic [7:0]             imem_a_arlen;
    logic [2:0]             imem_a_arsize;
    logic [1:0]             imem_a_arburst;
    logic                   imem_a_arvalid;
    wire                    imem_a_arready;
    wire [ID_WIDTH-1:0]     imem_a_rid;
    wire [DATA_WIDTH-1:0]   imem_a_rdata;
    wire [1:0]              imem_a_rresp;
    wire                    imem_a_rlast;
    wire                    imem_a_rvalid;
    logic                   imem_a_rready;

    // Port B (LSU / System / DMA)
    logic [ID_WIDTH-1:0]    imem_b_awid;
    logic [ADDR_WIDTH-1:0]  imem_b_awaddr;
    logic [7:0]             imem_b_awlen;
    logic [2:0]             imem_b_awsize;
    logic [1:0]             imem_b_awburst;
    logic                   imem_b_awvalid;
    wire                    imem_b_awready;
    logic [DATA_WIDTH-1:0]  imem_b_wdata;
    logic [STRB_WIDTH-1:0]  imem_b_wstrb;
    logic                   imem_b_wlast;
    logic                   imem_b_wvalid;
    wire                    imem_b_wready;
    wire [ID_WIDTH-1:0]     imem_b_bid;
    wire [1:0]              imem_b_bresp;
    wire                    imem_b_bvalid;
    logic                   imem_b_bready;
    logic [ID_WIDTH-1:0]    imem_b_arid;
    logic [ADDR_WIDTH-1:0]  imem_b_araddr;
    logic [7:0]             imem_b_arlen;
    logic [2:0]             imem_b_arsize;
    logic [1:0]             imem_b_arburst;
    logic                   imem_b_arvalid;
    wire                    imem_b_arready;
    wire [ID_WIDTH-1:0]     imem_b_rid;
    wire [DATA_WIDTH-1:0]   imem_b_rdata;
    wire [1:0]              imem_b_rresp;
    wire                    imem_b_rlast;
    wire                    imem_b_rvalid;
    logic                   imem_b_rready;

    // Instantiate Dual-Port IMEM
    imem_axi #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .ID_WIDTH_A (ID_WIDTH),
        .ID_WIDTH_B (ID_WIDTH),
        .MEM_SIZE   (65536)
    ) u_imem (
        .clk            (clk),
        .rst_n          (rst_n),
        // Port A
        .s_axi_a_awid   (imem_a_awid),
        .s_axi_a_awaddr (imem_a_awaddr),
        .s_axi_a_awlen  (imem_a_awlen),
        .s_axi_a_awsize (imem_a_awsize),
        .s_axi_a_awburst(imem_a_awburst),
        .s_axi_a_awvalid(imem_a_awvalid),
        .s_axi_a_awready(imem_a_awready),
        .s_axi_a_wdata  (imem_a_wdata),
        .s_axi_a_wstrb  (imem_a_wstrb),
        .s_axi_a_wlast  (imem_a_wlast),
        .s_axi_a_wvalid (imem_a_wvalid),
        .s_axi_a_wready (imem_a_wready),
        .s_axi_a_bid    (imem_a_bid),
        .s_axi_a_bresp  (imem_a_bresp),
        .s_axi_a_bvalid (imem_a_bvalid),
        .s_axi_a_bready (imem_a_bready),
        .s_axi_a_arid   (imem_a_arid),
        .s_axi_a_araddr (imem_a_araddr),
        .s_axi_a_arlen  (imem_a_arlen),
        .s_axi_a_arsize (imem_a_arsize),
        .s_axi_a_arburst(imem_a_arburst),
        .s_axi_a_arvalid(imem_a_arvalid),
        .s_axi_a_arready(imem_a_arready),
        .s_axi_a_rid    (imem_a_rid),
        .s_axi_a_rdata  (imem_a_rdata),
        .s_axi_a_rresp  (imem_a_rresp),
        .s_axi_a_rlast  (imem_a_rlast),
        .s_axi_a_rvalid (imem_a_rvalid),
        .s_axi_a_rready (imem_a_rready),
        // Port B
        .s_axi_b_awid   (imem_b_awid),
        .s_axi_b_awaddr (imem_b_awaddr),
        .s_axi_b_awlen  (imem_b_awlen),
        .s_axi_b_awsize (imem_b_awsize),
        .s_axi_b_awburst(imem_b_awburst),
        .s_axi_b_awvalid(imem_b_awvalid),
        .s_axi_b_awready(imem_b_awready),
        .s_axi_b_wdata  (imem_b_wdata),
        .s_axi_b_wstrb  (imem_b_wstrb),
        .s_axi_b_wlast  (imem_b_wlast),
        .s_axi_b_wvalid (imem_b_wvalid),
        .s_axi_b_wready (imem_b_wready),
        .s_axi_b_bid    (imem_b_bid),
        .s_axi_b_bresp  (imem_b_bresp),
        .s_axi_b_bvalid (imem_b_bvalid),
        .s_axi_b_bready (imem_b_bready),
        .s_axi_b_arid   (imem_b_arid),
        .s_axi_b_araddr (imem_b_araddr),
        .s_axi_b_arlen  (imem_b_arlen),
        .s_axi_b_arsize (imem_b_arsize),
        .s_axi_b_arburst(imem_b_arburst),
        .s_axi_b_arvalid(imem_b_arvalid),
        .s_axi_b_arready(imem_b_arready),
        .s_axi_b_rid    (imem_b_rid),
        .s_axi_b_rdata  (imem_b_rdata),
        .s_axi_b_rresp  (imem_b_rresp),
        .s_axi_b_rlast  (imem_b_rlast),
        .s_axi_b_rvalid (imem_b_rvalid),
        .s_axi_b_rready (imem_b_rready)
    );

    // =========================================================================
    // Preloaded IMEM Instance for INIT_FILE ($readmemh) Verification
    // =========================================================================
    logic [ID_WIDTH-1:0]    pre_a_arid;
    logic [ADDR_WIDTH-1:0]  pre_a_araddr;
    logic [7:0]             pre_a_arlen;
    logic [2:0]             pre_a_arsize;
    logic [1:0]             pre_a_arburst;
    logic                   pre_a_arvalid;
    wire                    pre_a_arready;
    wire [ID_WIDTH-1:0]     pre_a_rid;
    wire [DATA_WIDTH-1:0]   pre_a_rdata;
    wire [1:0]              pre_a_rresp;
    wire                    pre_a_rlast;
    wire                    pre_a_rvalid;
    logic                   pre_a_rready;

    imem_axi #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .ID_WIDTH_A (ID_WIDTH),
        .ID_WIDTH_B (ID_WIDTH),
        .MEM_SIZE   (65536),
        .INIT_FILE  ("tb/soc/boot_test.hex")
    ) u_imem_preload (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axi_a_awid   ('0),
        .s_axi_a_awaddr ('0),
        .s_axi_a_awlen  ('0),
        .s_axi_a_awsize ('0),
        .s_axi_a_awburst('0),
        .s_axi_a_awvalid(1'b0),
        .s_axi_a_awready(),
        .s_axi_a_wdata  ('0),
        .s_axi_a_wstrb  ('0),
        .s_axi_a_wlast  (1'b0),
        .s_axi_a_wvalid (1'b0),
        .s_axi_a_wready (),
        .s_axi_a_bid    (),
        .s_axi_a_bresp  (),
        .s_axi_a_bvalid (),
        .s_axi_a_bready (1'b1),
        .s_axi_a_arid   (pre_a_arid),
        .s_axi_a_araddr (pre_a_araddr),
        .s_axi_a_arlen  (pre_a_arlen),
        .s_axi_a_arsize (pre_a_arsize),
        .s_axi_a_arburst(pre_a_arburst),
        .s_axi_a_arvalid(pre_a_arvalid),
        .s_axi_a_arready(pre_a_arready),
        .s_axi_a_rid    (pre_a_rid),
        .s_axi_a_rdata  (pre_a_rdata),
        .s_axi_a_rresp  (pre_a_rresp),
        .s_axi_a_rlast  (pre_a_rlast),
        .s_axi_a_rvalid (pre_a_rvalid),
        .s_axi_a_rready (pre_a_rready),
        .s_axi_b_awid   ('0),
        .s_axi_b_awaddr ('0),
        .s_axi_b_awlen  ('0),
        .s_axi_b_awsize ('0),
        .s_axi_b_awburst('0),
        .s_axi_b_awvalid(1'b0),
        .s_axi_b_awready(),
        .s_axi_b_wdata  ('0),
        .s_axi_b_wstrb  ('0),
        .s_axi_b_wlast  (1'b0),
        .s_axi_b_wvalid (1'b0),
        .s_axi_b_wready (),
        .s_axi_b_bid    (),
        .s_axi_b_bresp  (),
        .s_axi_b_bvalid (),
        .s_axi_b_bready (1'b1),
        .s_axi_b_arid   ('0),
        .s_axi_b_araddr ('0),
        .s_axi_b_arlen  ('0),
        .s_axi_b_arsize ('0),
        .s_axi_b_arburst('0),
        .s_axi_b_arvalid(1'b0),
        .s_axi_b_arready(),
        .s_axi_b_rid    (),
        .s_axi_b_rdata  (),
        .s_axi_b_rresp  (),
        .s_axi_b_rlast  (),
        .s_axi_b_rvalid (),
        .s_axi_b_rready (1'b1)
    );

    // =========================================================================
    // Check Task
    // =========================================================================
    task check(input string desc, input logic condition);
        if (condition) begin
            $display("[PASS] %s", desc);
            test_pass_count++;
        end else begin
            $display("[FAIL] %s", desc);
            test_fail_count++;
        end
    endtask

    // =========================================================================
    // DMEM Write & Read Tasks
    // =========================================================================
    task automatic dmem_write(
        input logic [31:0] addr,
        input logic [31:0] data,
        input logic [3:0]  strb
    );
        @(negedge clk);
        dmem_awid    <= 8'h01;
        dmem_awaddr  <= addr;
        dmem_awlen   <= 8'd0;
        dmem_awsize  <= 3'b010;
        dmem_awburst <= 2'b01;
        dmem_awvalid <= 1'b1;

        dmem_wdata   <= data;
        dmem_wstrb   <= strb;
        dmem_wlast   <= 1'b1;
        dmem_wvalid  <= 1'b1;
        dmem_bready  <= 1'b1;

        fork
            begin
                while (!(dmem_awvalid && dmem_awready)) @(posedge clk);
                @(negedge clk); dmem_awvalid <= 1'b0;
            end
            begin
                while (!(dmem_wvalid && dmem_wready)) @(posedge clk);
                @(negedge clk); dmem_wvalid <= 1'b0;
            end
        join

        while (!(dmem_bvalid && dmem_bready)) @(posedge clk);
        @(negedge clk);
        dmem_bready <= 1'b0;
    endtask

    task automatic dmem_read(
        input  logic [31:0] addr,
        output logic [31:0] data
    );
        @(negedge clk);
        dmem_arid    <= 8'h02;
        dmem_araddr  <= addr;
        dmem_arlen   <= 8'd0;
        dmem_arsize  <= 3'b010;
        dmem_arburst <= 2'b01;
        dmem_arvalid <= 1'b1;
        dmem_rready  <= 1'b1;

        while (!(dmem_arvalid && dmem_arready)) @(posedge clk);
        @(negedge clk);
        dmem_arvalid <= 1'b0;

        while (!(dmem_rvalid && dmem_rready)) @(posedge clk);
        data = dmem_rdata;
        @(negedge clk);
        dmem_rready <= 1'b0;
    endtask

    // =========================================================================
    // IMEM Port A Read Task (Instruction Fetch)
    // =========================================================================
    task automatic imem_a_read(
        input  logic [31:0] addr,
        output logic [31:0] data
    );
        @(negedge clk);
        imem_a_arid    <= 8'h03;
        imem_a_araddr  <= addr;
        imem_a_arlen   <= 8'd0;
        imem_a_arsize  <= 3'b010;
        imem_a_arburst <= 2'b01;
        imem_a_arvalid <= 1'b1;
        imem_a_rready  <= 1'b1;

        while (!(imem_a_arvalid && imem_a_arready)) @(posedge clk);
        @(negedge clk);
        imem_a_arvalid <= 1'b0;

        while (!(imem_a_rvalid && imem_a_rready)) @(posedge clk);
        data = imem_a_rdata;
        @(negedge clk);
        imem_a_rready <= 1'b0;
    endtask

    // =========================================================================
    // IMEM Port B Write Task (LSU / DMA Firmware Loader)
    // =========================================================================
    task automatic imem_b_write(
        input logic [31:0] addr,
        input logic [31:0] data,
        input logic [3:0]  strb
    );
        @(negedge clk);
        imem_b_awid    <= 8'h04;
        imem_b_awaddr  <= addr;
        imem_b_awlen   <= 8'd0;
        imem_b_awsize  <= 3'b010;
        imem_b_awburst <= 2'b01;
        imem_b_awvalid <= 1'b1;

        imem_b_wdata   <= data;
        imem_b_wstrb   <= strb;
        imem_b_wlast   <= 1'b1;
        imem_b_wvalid  <= 1'b1;
        imem_b_bready  <= 1'b1;

        fork
            begin
                while (!(imem_b_awvalid && imem_b_awready)) @(posedge clk);
                @(negedge clk); imem_b_awvalid <= 1'b0;
            end
            begin
                while (!(imem_b_wvalid && imem_b_wready)) @(posedge clk);
                @(negedge clk); imem_b_wvalid <= 1'b0;
            end
        join

        while (!(imem_b_bvalid && imem_b_bready)) @(posedge clk);
        @(negedge clk);
        imem_b_bready <= 1'b0;
    endtask

    task automatic imem_b_read(
        input  logic [31:0] addr,
        output logic [31:0] data
    );
        @(negedge clk);
        imem_b_arid    <= 8'h05;
        imem_b_araddr  <= addr;
        imem_b_arlen   <= 8'd0;
        imem_b_arsize  <= 3'b010;
        imem_b_arburst <= 2'b01;
        imem_b_arvalid <= 1'b1;
        imem_b_rready  <= 1'b1;

        while (!(imem_b_arvalid && imem_b_arready)) @(posedge clk);
        @(negedge clk);
        imem_b_arvalid <= 1'b0;

        while (!(imem_b_rvalid && imem_b_rready)) @(posedge clk);
        data = imem_b_rdata;
        @(negedge clk);
        imem_b_rready <= 1'b0;
    endtask

    // =========================================================================
    // Main Test Sequence
    // =========================================================================
    logic [31:0] rdata;

    initial begin
        $display("==================================================================");
        $display("Starting IMEM and DMEM AXI4 Verification");
        $display("==================================================================");

        // Initialize signals
        rst_n          = 1'b0;
        dmem_awvalid   = 1'b0;
        dmem_wvalid    = 1'b0;
        dmem_bready    = 1'b0;
        dmem_arvalid   = 1'b0;
        dmem_rready    = 1'b0;
        dmem_awid      = '0;
        dmem_awaddr    = '0;
        dmem_awlen     = '0;
        dmem_awsize    = '0;
        dmem_awburst   = '0;
        dmem_wdata     = '0;
        dmem_wstrb     = '0;
        dmem_wlast     = '0;
        dmem_arid      = '0;
        dmem_araddr    = '0;
        dmem_arlen     = '0;
        dmem_arsize    = '0;
        dmem_arburst   = '0;

        imem_a_awvalid = 1'b0;
        imem_a_wvalid  = 1'b0;
        imem_a_bready  = 1'b0;
        imem_a_arvalid = 1'b0;
        imem_a_rready  = 1'b0;
        imem_a_awid    = '0;
        imem_a_awaddr  = '0;
        imem_a_awlen   = '0;
        imem_a_awsize  = '0;
        imem_a_awburst = '0;
        imem_a_wdata   = '0;
        imem_a_wstrb   = '0;
        imem_a_wlast   = '0;
        imem_a_arid    = '0;
        imem_a_araddr  = '0;
        imem_a_arlen   = '0;
        imem_a_arsize  = '0;
        imem_a_arburst = '0;

        imem_b_awvalid = 1'b0;
        imem_b_wvalid  = 1'b0;
        imem_b_bready  = 1'b0;
        imem_b_arvalid = 1'b0;
        imem_b_rready  = 1'b0;
        imem_b_awid    = '0;
        imem_b_awaddr  = '0;
        imem_b_awlen   = '0;
        imem_b_awsize  = '0;
        imem_b_awburst = '0;
        imem_b_wdata   = '0;
        imem_b_wstrb   = '0;
        imem_b_wlast   = '0;
        imem_b_arid    = '0;
        imem_b_araddr  = '0;
        imem_b_arlen   = '0;
        imem_b_arsize  = '0;
        imem_b_arburst = '0;

        // Reset sequence
        #20;
        rst_n = 1'b1;
        #20;

        // ---------------------------------------------------------------------
        // TEST 1: DMEM 32-bit Word Access
        // ---------------------------------------------------------------------
        $display("\n--- TEST 1: DMEM 32-bit Word Writes and Reads ---");
        dmem_write(32'h1000_0000, 32'hDEAD_BEEF, 4'b1111);
        dmem_read (32'h1000_0000, rdata);
        check("DMEM Word Read @ 0x1000_0000 == 0xDEADBEEF", rdata == 32'hDEAD_BEEF);

        dmem_write(32'h1000_0004, 32'h1234_5678, 4'b1111);
        dmem_read (32'h1000_0004, rdata);
        check("DMEM Word Read @ 0x1000_0004 == 0x12345678", rdata == 32'h1234_5678);

        dmem_write(32'h1000_FFFC, 32'hCAFE_BABE, 4'b1111);
        dmem_read (32'h1000_FFFC, rdata);
        check("DMEM Word Read @ Top 0x1000_FFFC == 0xCAFEBABE", rdata == 32'hCAFE_BABE);

        // ---------------------------------------------------------------------
        // TEST 2: DMEM Byte-Lane Write Strobes (INT8 / INT16 / INT32)
        // ---------------------------------------------------------------------
        $display("\n--- TEST 2: DMEM Byte-Lane Strobes (wstrb) ---");
        // Initialize word to 0x0000_0000
        dmem_write(32'h1000_0010, 32'h0000_0000, 4'b1111);

        // Write Byte 0
        dmem_write(32'h1000_0010, 32'h0000_00AA, 4'b0001);
        dmem_read (32'h1000_0010, rdata);
        check("DMEM Byte 0 write -> 0x0000_00AA", rdata == 32'h0000_00AA);

        // Write Byte 1
        dmem_write(32'h1000_0010, 32'h0000_BB00, 4'b0010);
        dmem_read (32'h1000_0010, rdata);
        check("DMEM Byte 1 write -> 0x0000_BBAA", rdata == 32'h0000_BBAA);

        // Write Byte 2
        dmem_write(32'h1000_0010, 32'h00CC_0000, 4'b0100);
        dmem_read (32'h1000_0010, rdata);
        check("DMEM Byte 2 write -> 0x00CC_BBAA", rdata == 32'h00CC_BBAA);

        // Write Byte 3
        dmem_write(32'h1000_0010, 32'hDD00_0000, 4'b1000);
        dmem_read (32'h1000_0010, rdata);
        check("DMEM Byte 3 write -> 0xDDCC_BBAA", rdata == 32'hDDCC_BBAA);

        // Halfword write (lower 16 bits)
        dmem_write(32'h1000_0010, 32'h0000_1122, 4'b0011);
        dmem_read (32'h1000_0010, rdata);
        check("DMEM Halfword write -> 0xDDCC_1122", rdata == 32'hDDCC_1122);

        // ---------------------------------------------------------------------
        // TEST 3: DMEM Burst Mode (4-beat write and read)
        // ---------------------------------------------------------------------
        $display("\n--- TEST 3: DMEM Burst Access (INCR) ---");
        @(negedge clk);
        dmem_awid    <= 8'h05;
        dmem_awaddr  <= 32'h1000_0100;
        dmem_awlen   <= 8'd3; // 4 beats
        dmem_awsize  <= 3'b010;
        dmem_awburst <= 2'b01;
        dmem_awvalid <= 1'b1;

        dmem_wdata   <= 32'hA000_0001;
        dmem_wstrb   <= 4'b1111;
        dmem_wlast   <= 1'b0;
        dmem_wvalid  <= 1'b1;
        dmem_bready  <= 1'b1;

        while (!(dmem_awvalid && dmem_awready)) @(posedge clk);
        @(negedge clk);
        dmem_awvalid <= 1'b0;

        // Beat 1
        dmem_wdata <= 32'hA000_0002;
        dmem_wlast <= 1'b0;
        @(posedge clk);
        @(negedge clk);

        // Beat 2
        dmem_wdata <= 32'hA000_0003;
        dmem_wlast <= 1'b0;
        @(posedge clk);
        @(negedge clk);

        // Beat 3 (last)
        dmem_wdata <= 32'hA000_0004;
        dmem_wlast <= 1'b1;
        @(posedge clk);
        @(negedge clk);
        dmem_wvalid <= 1'b0;

        while (!(dmem_bvalid && dmem_bready)) @(posedge clk);
        @(negedge clk);
        dmem_bready <= 1'b0;

        // Read back all 4 beats
        dmem_read(32'h1000_0100, rdata);
        check("DMEM Burst Beat 0 Read == 0xA0000001", rdata == 32'hA000_0001);
        dmem_read(32'h1000_0104, rdata);
        check("DMEM Burst Beat 1 Read == 0xA0000002", rdata == 32'hA000_0002);
        dmem_read(32'h1000_0108, rdata);
        check("DMEM Burst Beat 2 Read == 0xA0000003", rdata == 32'hA000_0003);
        dmem_read(32'h1000_010C, rdata);
        check("DMEM Burst Beat 3 Read == 0xA0000004", rdata == 32'hA000_0004);

        // ---------------------------------------------------------------------
        // TEST 4: IMEM Port B Write & Port A Read (Firmware loading & CPU IFU fetch)
        // ---------------------------------------------------------------------
        $display("\n--- TEST 4: IMEM Port B Write (Firmware loader) & Port A Read (IFU fetch) ---");
        // Load instructions via Port B (m00)
        imem_b_write(32'h0000_0000, 32'h0000_0013, 4'b1111); // nop (addi x0, x0, 0)
        imem_b_write(32'h0000_0004, 32'h0010_0093, 4'b1111); // addi x1, x0, 1
        imem_b_write(32'h0000_0008, 32'h0020_8133, 4'b1111); // add x2, x1, x2

        // Fetch instructions via Port A (IFU)
        imem_a_read(32'h0000_0000, rdata);
        check("IMEM Port A Fetch @ 0x0000_0000 == 0x00000013 (NOP)", rdata == 32'h0000_0013);

        imem_a_read(32'h0000_0004, rdata);
        check("IMEM Port A Fetch @ 0x0000_0004 == 0x00100093", rdata == 32'h0010_0093);

        imem_a_read(32'h0000_0008, rdata);
        check("IMEM Port A Fetch @ 0x0000_0008 == 0x00208133", rdata == 32'h0020_8133);

        // Also verify Port B can read back what it wrote
        imem_b_read(32'h0000_0004, rdata);
        check("IMEM Port B Readback @ 0x0000_0004 == 0x00100093", rdata == 32'h0010_0093);

        // ---------------------------------------------------------------------
        // TEST 5: IMEM True Dual-Port Concurrency
        //         Port A and Port B execute simultaneously in same clock cycle
        // ---------------------------------------------------------------------
        $display("\n--- TEST 5: IMEM True Dual-Port Concurrency ---");
        // Write two test locations first
        imem_b_write(32'h0000_0200, 32'h5555_AAAA, 4'b1111);
        imem_b_write(32'h0000_0204, 32'h7777_8888, 4'b1111);

        // Simultaneous Read: Port A reads 0x200 while Port B reads 0x204
        @(negedge clk);
        imem_a_arid    <= 8'h0A;
        imem_a_araddr  <= 32'h0000_0200;
        imem_a_arlen   <= 8'd0;
        imem_a_arsize  <= 3'b010;
        imem_a_arburst <= 2'b01;
        imem_a_arvalid <= 1'b1;
        imem_a_rready  <= 1'b1;

        imem_b_arid    <= 8'h0B;
        imem_b_araddr  <= 32'h0000_0204;
        imem_b_arlen   <= 8'd0;
        imem_b_arsize  <= 3'b010;
        imem_b_arburst <= 2'b01;
        imem_b_arvalid <= 1'b1;
        imem_b_rready  <= 1'b1;

        fork
            begin
                while (!(imem_a_arvalid && imem_a_arready)) @(posedge clk);
                @(negedge clk); imem_a_arvalid <= 1'b0;
            end
            begin
                while (!(imem_b_arvalid && imem_b_arready)) @(posedge clk);
                @(negedge clk); imem_b_arvalid <= 1'b0;
            end
        join

        fork
            begin
                while (!(imem_a_rvalid && imem_a_rready)) @(posedge clk);
                check("Concurrent Port A read @ 0x200 == 0x5555AAAA", imem_a_rdata == 32'h5555_AAAA);
                @(negedge clk); imem_a_rready <= 1'b0;
            end
            begin
                while (!(imem_b_rvalid && imem_b_rready)) @(posedge clk);
                check("Concurrent Port B read @ 0x204 == 0x77778888", imem_b_rdata == 32'h7777_8888);
                @(negedge clk); imem_b_rready <= 1'b0;
            end
        join

        // Simultaneous Write on Port B + Read on Port A (Different Addresses)
        @(negedge clk);
        imem_b_awid    <= 8'h0C;
        imem_b_awaddr  <= 32'h0000_0300;
        imem_b_awlen   <= 8'd0;
        imem_b_awsize  <= 3'b010;
        imem_b_awburst <= 2'b01;
        imem_b_awvalid <= 1'b1;
        imem_b_wdata   <= 32'hBEEF_CAFE;
        imem_b_wstrb   <= 4'b1111;
        imem_b_wlast   <= 1'b1;
        imem_b_wvalid  <= 1'b1;
        imem_b_bready  <= 1'b1;

        imem_a_arid    <= 8'h0D;
        imem_a_araddr  <= 32'h0000_0200;
        imem_a_arlen   <= 8'd0;
        imem_a_arsize  <= 3'b010;
        imem_a_arburst <= 2'b01;
        imem_a_arvalid <= 1'b1;
        imem_a_rready  <= 1'b1;

        fork
            begin
                while (!(imem_b_awvalid && imem_b_awready)) @(posedge clk);
                @(negedge clk); imem_b_awvalid <= 1'b0;
            end
            begin
                while (!(imem_b_wvalid && imem_b_wready)) @(posedge clk);
                @(negedge clk); imem_b_wvalid <= 1'b0;
            end
            begin
                while (!(imem_a_arvalid && imem_a_arready)) @(posedge clk);
                @(negedge clk); imem_a_arvalid <= 1'b0;
            end
        join

        fork
            begin
                while (!(imem_b_bvalid && imem_b_bready)) @(posedge clk);
                @(negedge clk); imem_b_bready <= 1'b0;
            end
            begin
                while (!(imem_a_rvalid && imem_a_rready)) @(posedge clk);
                check("Simultaneous Port A read during Port B write == 0x5555AAAA", imem_a_rdata == 32'h5555_AAAA);
                @(negedge clk); imem_a_rready <= 1'b0;
            end
        join

        // Verify the newly written data at 0x300
        imem_a_read(32'h0000_0300, rdata);
        check("Port A reads newly committed Port B data @ 0x300 == 0xBEEFCAFE", rdata == 32'hBEEF_CAFE);

        // ---------------------------------------------------------------------
        // TEST 6: Firmware Hex Preload Verification via INIT_FILE ($readmemh)
        // ---------------------------------------------------------------------
        $display("\n--- TEST 6: Firmware Hex Preload Verification via INIT_FILE ---");
        // Read from u_imem_preload Port A
        @(negedge clk);
        pre_a_arid    <= 8'h11;
        pre_a_araddr  <= 32'h0000_0000; // Reset vector instruction 0
        pre_a_arlen   <= 8'd0;
        pre_a_arsize  <= 3'b010;
        pre_a_arburst <= 2'b01;
        pre_a_arvalid <= 1'b1;
        pre_a_rready  <= 1'b1;

        while (!(pre_a_arvalid && pre_a_arready)) @(posedge clk);
        @(negedge clk);
        pre_a_arvalid <= 1'b0;

        while (!(pre_a_rvalid && pre_a_rready)) @(posedge clk);
        check("Preload IMEM @ 0x0000_0000 == 0x00000013 (NOP)", pre_a_rdata == 32'h0000_0013);
        @(negedge clk);
        pre_a_rready <= 1'b0;

        // Instruction 1
        @(negedge clk);
        pre_a_arid    <= 8'h12;
        pre_a_araddr  <= 32'h0000_0004; // Reset vector instruction 1
        pre_a_arlen   <= 8'd0;
        pre_a_arsize  <= 3'b010;
        pre_a_arburst <= 2'b01;
        pre_a_arvalid <= 1'b1;
        pre_a_rready  <= 1'b1;

        while (!(pre_a_arvalid && pre_a_arready)) @(posedge clk);
        @(negedge clk);
        pre_a_arvalid <= 1'b0;

        while (!(pre_a_rvalid && pre_a_rready)) @(posedge clk);
        check("Preload IMEM @ 0x0000_0004 == 0x00100093 (addi x1, x0, 1)", pre_a_rdata == 32'h0010_0093);
        @(negedge clk);
        pre_a_rready <= 1'b0;

        // Instruction 3
        @(negedge clk);
        pre_a_arid    <= 8'h13;
        pre_a_araddr  <= 32'h0000_000C; // Instruction 3
        pre_a_arlen   <= 8'd0;
        pre_a_arsize  <= 3'b010;
        pre_a_arburst <= 2'b01;
        pre_a_arvalid <= 1'b1;
        pre_a_rready  <= 1'b1;

        while (!(pre_a_arvalid && pre_a_arready)) @(posedge clk);
        @(negedge clk);
        pre_a_arvalid <= 1'b0;

        while (!(pre_a_rvalid && pre_a_rready)) @(posedge clk);
        check("Preload IMEM @ 0x0000_000C == 0x00008067 (ret)", pre_a_rdata == 32'h0000_8067);
        @(negedge clk);
        pre_a_rready <= 1'b0;

        // ---------------------------------------------------------------------
        // TEST SUMMARY
        // ---------------------------------------------------------------------
        $display("\n==================================================================");
        $display("IMEM & DMEM AXI4 VERIFICATION RESULTS:");
        $display("  PASSED: %0d", test_pass_count);
        $display("  FAILED: %0d", test_fail_count);
        $display("==================================================================");

        if (test_fail_count == 0) begin
            $display("[TESTBENCH PASSED] ALL MEMORY TESTS COMPLETED SUCCESSFULLY!\n");
        end else begin
            $display("[TESTBENCH FAILED] ERRORS DETECTED!\n");
        end

        #50;
        $finish;
    end

endmodule
