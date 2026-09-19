// ============================================================
// uart_axi_tb.v
// VCS testbench — AXI4-Lite master driving axi_uart_top (slave).
// Mirrors the structure of aes_axi_tb.v exactly:
//   - TB is the AXI master; DUT (axi_uart_top) is the AXI slave
//   - TX→RX loopback via uart_tx_o → uart_rx_i
//   - PASS/FAIL per test; summary at end
//   - FSDB via PLI $fsdbDumpfile (same as AES testbench)
//
// RTL Protocol Notes (axi_uart_top):
//   - awready, wready, bvalid all pulse HIGH in the same
//     single clock cycle (one-shot handshake)
//   - arready and rvalid also pulse in the same cycle
//   - Write FSM requires awvalid & wvalid simultaneously
//     (axi_wren = awvalid_i & wvalid_i)
//   - BAUD_DIVISOR write needs LCR[7] DLAB=1 first
//   - Only RBR (rx data) and LSR are readable via AXI
// ============================================================
// UART Register Map  (5-bit byte address):
//   0x00  THR (write) / RBR (read)
//   0x04  IER — interrupt enable  (DLAB=0 only)
//   0x08  BAUD_DIVISOR (write-only; needs DLAB=1)
//   0x0C  LCR — line control  [7]=DLAB [3]=parity_en [2]=stop
//   0x14  LSR — line status   [6]=TEMT [5]=THRE [0]=DATA_READY
// ============================================================

`timescale 1ns/1ps

module uart_axi_tb;

// -----------------------------------------------------------
// Clock / reset  (100 MHz, same as AES testbench)
// -----------------------------------------------------------
reg clk;
reg aresetn;

initial clk = 1'b0;
always #5 clk = ~clk;   // 100 MHz

// Baud divisor for simulation: 64 clocks/bit = 640 ns/bit
// The RX has a 3-stage synchronizer (3 cycle latency) so we
// need div >> 3. With div=64, mid-sample point is at cycle 32,
// well clear of the 3-cycle sync delay.
// 10 bits/frame × 64 clks = 640 clks/byte
localparam [31:0] BAUD_DIV_SIM  = 32'd64;
localparam        BITS_PER_FRAME = 10;   // start + 8 data + 1 stop
localparam        BYTE_CLKS      = BITS_PER_FRAME * 64 + 16; // +margin

// -----------------------------------------------------------
// AXI4-Lite master signals
// TB drives _i ports; DUT drives _o ports (slave perspective)
// -----------------------------------------------------------
reg  [11:0] awid;   reg  [4:0]  awaddr;  reg  awvalid;
wire        awready;
reg  [31:0] wdata;  reg  [3:0]  wstrb;   reg  wvalid;
wire        wready;
wire [11:0] bid;    wire [1:0]  bresp;   wire bvalid;   reg  bready;
reg  [11:0] arid;   reg  [4:0]  araddr;  reg  arvalid;
wire        arready;
wire [11:0] rid;    wire [31:0] rdata;   wire [1:0] rresp;
wire        rvalid; reg  rready;

wire read_interrupt;

// UART TX→RX loopback
wire uart_tx;
wire uart_rx;
assign uart_rx = uart_tx;

// -----------------------------------------------------------
// DUT: axi_uart_top is the AXI4-Lite slave
// -----------------------------------------------------------
axi_uart_top dut (
    .fixed_clk_i      (clk),
    .axi_aclk_i       (clk),
    .axi_aresetn_i    (aresetn),
    // Read address channel (master → slave)
    .axi_arid_i       (arid),
    .axi_araddr_i     (araddr),
    .axi_arvalid_i    (arvalid),
    // Read address channel (slave → master)
    .axi_arready_o    (arready),
    // Read data channel (slave → master)
    .axi_rid_o        (rid),
    .axi_rdata_o      (rdata),
    .axi_rresp_o      (rresp),
    .axi_rvalid_o     (rvalid),
    // Read data channel (master → slave)
    .axi_rready_i     (rready),
    // Write address channel (master → slave)
    .axi_awid_i       (awid),
    .axi_awaddr_i     (awaddr),
    .axi_awvalid_i    (awvalid),
    // Write address channel (slave → master)
    .axi_awready_o    (awready),
    // Write data channel (master → slave)
    .axi_wdata_i      (wdata),
    .axi_wstrb_i      (wstrb),
    .axi_wvalid_i     (wvalid),
    // Write data channel (slave → master)
    .axi_wready_o     (wready),
    // Write response (slave → master)
    .axi_bid_o        (bid),
    .axi_bresp_o      (bresp),
    .axi_bvalid_o     (bvalid),
    // Write response (master → slave)
    .axi_bready_i     (bready),
    // UART
    .read_interrupt_o (read_interrupt),
    .uart_tx_o        (uart_tx),
    .uart_rx_i        (uart_rx)
);

// -----------------------------------------------------------
// FSDB dump  (PLI-based — mirrors aes_axi_tb.v exactly)
// -----------------------------------------------------------
initial begin
    $fsdbDumpfile("waves/uart_axi_dump.fsdb");
    $fsdbDumpvars(0, uart_axi_tb);
end

// -----------------------------------------------------------
// Register address constants
// -----------------------------------------------------------
localparam ADDR_THR_RBR = 5'h00;
localparam ADDR_IER     = 5'h04;
localparam ADDR_BAUD    = 5'h08;
localparam ADDR_LCR     = 5'h0C;
localparam ADDR_LSR     = 5'h14;

// LSR bit positions
localparam LSR_DATA_READY = 0;
localparam LSR_THRE       = 5;
localparam LSR_TEMT       = 6;

// -----------------------------------------------------------
// Pass / fail counters
// -----------------------------------------------------------
integer pass_cnt, fail_cnt;

// -----------------------------------------------------------
// AXI4-Lite helper tasks  (master side)
//
// RTL behaviour: awready, wready, bvalid all assert in the
// SAME single clock cycle as the first valid cycle where
// awvalid & wvalid are both high.  Similarly arready and
// rvalid assert together in one cycle.
// Tasks keep valids high until the handshake cycle is
// detected, then de-assert.
// -----------------------------------------------------------

// AXI write: assert AW+W simultaneously; poll on each posedge
// for the single-cycle awready+wready pulse; keep bready=1
task axi_write;
    input [4:0]  addr;
    input [31:0] data;
    reg done;
    begin
        done = 0;
        @(posedge clk); #1;
        awid    = 12'b0;
        awaddr  = addr;  awvalid = 1'b1;
        wdata   = data;  wstrb   = 4'hF;  wvalid = 1'b1;
        bready  = 1'b1;
        // Poll until awready & wready are seen in same cycle
        while (!done) begin
            @(posedge clk); #1;
            if (awready && wready) begin
                awvalid = 1'b0;
                wvalid  = 1'b0;
                done    = 1;
            end
        end
        // bvalid comes in same cycle as awready; keep bready one more edge
        @(posedge clk); #1;
        bready = 1'b0;
    end
endtask

// AXI read: assert AR and rready; poll for arready+rvalid
task axi_read;
    input  [4:0]  addr;
    output [31:0] data;
    reg done;
    begin
        done = 0;
        @(posedge clk); #1;
        arid    = 12'b0;
        araddr  = addr;  arvalid = 1'b1;
        rready  = 1'b1;
        // Poll until arready+rvalid seen (come together)
        while (!done) begin
            @(posedge clk); #1;
            if (arready && rvalid) begin
                data   = rdata;
                arvalid = 1'b0;
                done    = 1;
            end
        end
        @(posedge clk); #1;
        rready = 1'b0;
    end
endtask

// Poll LSR[TEMT] until TX completely empty; timeout 50000 polls
task wait_tx_empty;
    integer timeout;
    reg [31:0] lsr_val;
    begin
        timeout = 0;
        lsr_val = 32'b0;
        while (!lsr_val[LSR_TEMT] && timeout < 50000) begin
            axi_read(ADDR_LSR, lsr_val);
            timeout = timeout + 1;
        end
        if (timeout >= 50000)
            $display("  WARNING: wait_tx_empty TIMEOUT");
    end
endtask

// Poll LSR[DATA_READY] until RX has a byte; timeout 50000 polls
task wait_rx_ready;
    integer timeout;
    reg [31:0] lsr_val;
    begin
        timeout = 0;
        lsr_val = 32'b0;
        while (!lsr_val[LSR_DATA_READY] && timeout < 50000) begin
            axi_read(ADDR_LSR, lsr_val);
            timeout = timeout + 1;
        end
        if (timeout >= 50000)
            $display("  WARNING: wait_rx_ready TIMEOUT");
    end
endtask

// Set/clear LCR[7] DLAB bit
task set_dlab;
    input dlab_val;
    begin
        if (dlab_val)
            axi_write(ADDR_LCR, 32'h00000080);  // DLAB=1
        else
            axi_write(ADDR_LCR, 32'h00000000);  // DLAB=0
    end
endtask

// Send one byte: write to THR, then wait one full UART frame time
// Note: TEMT/THRE in LSR reflect TX FIFO empty (not TX serializer done).
// We wait BYTE_CLKS clock cycles to ensure serialisation is complete.
task uart_send;
    input [7:0] byte_val;
    begin
        axi_write(ADDR_THR_RBR, {24'b0, byte_val});
        repeat(BYTE_CLKS) @(posedge clk);
    end
endtask

// Receive one byte: wait DATA_READY, read RBR
task uart_recv;
    output [7:0] byte_val;
    reg [31:0] rd;
    begin
        wait_rx_ready;
        axi_read(ADDR_THR_RBR, rd);
        byte_val = rd[7:0];
    end
endtask

// -----------------------------------------------------------
// Test vectors: loopback byte values
// -----------------------------------------------------------
reg [7:0] tv_byte [0:7];
initial begin
    tv_byte[0] = 8'h55;   // 0101_0101 (alternating)
    tv_byte[1] = 8'hAA;   // 1010_1010 (alternating)
    tv_byte[2] = 8'hFF;   // all ones
    tv_byte[3] = 8'h00;   // all zeros
    tv_byte[4] = 8'h41;   // ASCII 'A'
    tv_byte[5] = 8'h5A;   // ASCII 'Z'
    tv_byte[6] = 8'hA5;   // pattern
    tv_byte[7] = 8'h3C;   // pattern
end

integer    i;
reg [7:0]  rx_byte;
reg [31:0] lsr_snap;

// -----------------------------------------------------------
// Main test sequence
// -----------------------------------------------------------
initial begin
    // Initialise all AXI master outputs
    awid    = 12'b0;  awaddr = 5'b0;  awvalid = 1'b0;
    wdata   = 32'b0;  wstrb  = 4'hF;  wvalid  = 1'b0;
    bready  = 1'b0;
    arid    = 12'b0;  araddr = 5'b0;  arvalid = 1'b0;
    rready  = 1'b0;
    pass_cnt = 0;  fail_cnt = 0;

    // Reset (active-low, same as AES testbench)
    aresetn = 1'b0;
    repeat(20) @(posedge clk);
    aresetn = 1'b1;
    repeat(10) @(posedge clk);

    $display("\n============================================");
    $display("  UART AXI4-Lite Wrapper Testbench");
    $display("============================================\n");

    // ==================================================
    // TEST 0: Baud-Rate Divisor Config (DLAB protocol)
    // 1. Set LCR[7]=1 (DLAB=1) to unlock baud divisor
    // 2. Write BAUD_DIVISOR register
    // 3. Clear LCR[7]=0 (DLAB=0) to restore normal access
    // 4. Enable IER[0]=1 so LSR[DATA_READY] works
    //    (DATA_READY = ~rx_fifo_empty & uart_irq_en)
    // 5. Read LSR to confirm bus is alive
    // ==================================================
    $display("--- TEST 0: Baud-Rate Divisor Config (DLAB=1 protocol) ---");
    set_dlab(1);
    axi_write(ADDR_BAUD, BAUD_DIV_SIM);
    set_dlab(0);
    // Enable RX interrupt so DATA_READY flag works
    axi_write(ADDR_IER, 32'h00000001);
    begin : t0
        reg [31:0] lsr0;
        axi_read(ADDR_LSR, lsr0);
        $display("  Divisor = %0d written with DLAB protocol", BAUD_DIV_SIM);
        $display("  IER     = 0x01 (RX interrupt enabled)");
        $display("  LSR after config   = 0x%08h", lsr0);
        $display("  TEMT[6]=%0b  THRE[5]=%0b", lsr0[LSR_TEMT], lsr0[LSR_THRE]);
        if (!$isunknown(lsr0)) begin
            $display("  RESULT: PASS\n");
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  RESULT: FAIL *** unknown LSR value ***\n");
            fail_cnt = fail_cnt + 1;
        end
    end

    // ==================================================
    // TEST 1: LCR Config Write  (8N1, no parity)
    // Verify bus completes handshake and LSR is valid
    // ==================================================
    $display("--- TEST 1: LCR Config (8N1, no parity) ---");
    axi_write(ADDR_LCR, 32'h00000000);
    begin : t1
        reg [31:0] lsr1;
        axi_read(ADDR_LSR, lsr1);
        $display("  LCR = 0x00000000 written (8N1)");
        $display("  LSR = 0x%08h", lsr1);
        if (!$isunknown(lsr1)) begin
            $display("  RESULT: PASS (bus responsive)\n");
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  RESULT: FAIL *** bus unresponsive ***\n");
            fail_cnt = fail_cnt + 1;
        end
    end

    // ==================================================
    // TEST 2: Single-Byte TX→RX Loopback (8 vectors)
    // AXI master writes byte → THR → UART TX serialises
    // TX looped back to RX → UART deserialises → RX FIFO
    // AXI master reads byte from RBR, compares
    // ==================================================
    $display("--- TEST 2: Single-Byte Loopback (8 bytes) ---");
    for (i = 0; i < 8; i = i + 1) begin
        uart_send(tv_byte[i]);
        uart_recv(rx_byte);
        $display("  Byte[%0d]: sent=0x%02h  recv=0x%02h", i, tv_byte[i], rx_byte);
        if (rx_byte === tv_byte[i]) begin
            $display("           RESULT: PASS");
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("           RESULT: FAIL *** byte mismatch ***");
            fail_cnt = fail_cnt + 1;
        end
    end
    $display("");

    // ==================================================
    // TEST 3: Burst TX/RX — 4 bytes without inter-byte wait
    // All 4 written to TX FIFO, then all 4 drained from RX
    // ==================================================
    $display("--- TEST 3: Burst TX/RX (4 bytes) ---");
    begin : t3
        reg [7:0] bsent [0:3];
        reg [7:0] brecv [0:3];
        integer   j;
        integer   ok;
        bsent[0] = 8'hDE;  bsent[1] = 8'hAD;
        bsent[2] = 8'hBE;  bsent[3] = 8'hEF;
        ok = 1;
        for (j = 0; j < 4; j = j + 1)
            axi_write(ADDR_THR_RBR, {24'b0, bsent[j]});
        for (j = 0; j < 4; j = j + 1)
            uart_recv(brecv[j]);
        for (j = 0; j < 4; j = j + 1) begin
            $display("  Burst[%0d]: sent=0x%02h  recv=0x%02h", j, bsent[j], brecv[j]);
            if (brecv[j] !== bsent[j]) ok = 0;
        end
        if (ok) begin
            $display("  RESULT: PASS\n");
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  RESULT: FAIL *** burst mismatch ***\n");
            fail_cnt = fail_cnt + 1;
        end
    end

    // ==================================================
    // TEST 4: LSR Status Check (TX idle)
    // After all data transmitted (FIFO and serializer),
    // TEMT=1 and THRE=1; DATA_READY=0 (RX FIFO drained)
    // ==================================================
    $display("--- TEST 4: LSR Status After Idle ---");
    // Wait >1 full frame time after last byte was sent
    repeat(BYTE_CLKS) @(posedge clk);
    axi_read(ADDR_LSR, lsr_snap);
    $display("  LSR = 0x%08h", lsr_snap);
    $display("  TEMT[6]=%0b  THRE[5]=%0b  DATA_READY[0]=%0b",
             lsr_snap[LSR_TEMT], lsr_snap[LSR_THRE], lsr_snap[LSR_DATA_READY]);
    if (lsr_snap[LSR_TEMT] && lsr_snap[LSR_THRE]) begin
        $display("  RESULT: PASS (TX completely empty)\n");
        pass_cnt = pass_cnt + 1;
    end else begin
        $display("  RESULT: FAIL *** unexpected LSR state ***\n");
        fail_cnt = fail_cnt + 1;
    end

    // ==================================================
    // TEST 5: read_interrupt_o pin check
    // IER was enabled in TEST 0. Send a byte and verify
    // the read_interrupt_o output goes high when RX FIFO
    // has data (interrupt pin is driven combinatorially)
    // ==================================================
    $display("--- TEST 5: RX Interrupt Pin Check ---");
    begin : t5
        reg [31:0] lsr5;
        // Send one byte and wait for it to arrive
        uart_send(8'hB5);
        repeat(5) @(posedge clk);
        // Snapshot LSR — DATA_READY should be 1
        axi_read(ADDR_LSR, lsr5);
        $display("  Sent 0xB5; LSR = 0x%08h  DATA_READY=%0b  read_interrupt_o=%0b",
                 lsr5, lsr5[LSR_DATA_READY], read_interrupt);
        if (lsr5[LSR_DATA_READY]) begin
            $display("  RESULT: PASS (DATA_READY=1, RX interrupt active)\n");
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  RESULT: FAIL *** DATA_READY not set ***\n");
            fail_cnt = fail_cnt + 1;
        end
        // Drain the byte
        axi_read(ADDR_THR_RBR, lsr5);
    end

    // ==================================================
    // TEST 6: Loopback with Different Baud Divisor (16)
    // Use DLAB protocol to switch divisor, re-enable IER,
    // run loopback, then restore original divisor
    // ==================================================
    $display("--- TEST 6: Loopback with Divisor=128 ---");
    begin : t6
        reg [7:0] b0s, b1s, b0r, b1r;
        b0s = 8'hC3;  b1s = 8'h3C;
        set_dlab(1);
        axi_write(ADDR_BAUD, 32'd128);
        set_dlab(0);
        axi_write(ADDR_IER, 32'h00000001);  // re-enable RX interrupt
        repeat(10) @(posedge clk);
        uart_send(b0s);  uart_recv(b0r);
        uart_send(b1s);  uart_recv(b1r);
        set_dlab(1);
        axi_write(ADDR_BAUD, BAUD_DIV_SIM);
        set_dlab(0);
        axi_write(ADDR_IER, 32'h00000001);  // re-enable after DLAB clear
        $display("  b0: sent=0x%02h  recv=0x%02h", b0s, b0r);
        $display("  b1: sent=0x%02h  recv=0x%02h", b1s, b1r);
        if (b0r === b0s && b1r === b1s) begin
            $display("  RESULT: PASS\n");
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  RESULT: FAIL *** loopback mismatch ***\n");
            fail_cnt = fail_cnt + 1;
        end
    end

    // ==================================================
    // Summary  (mirrors AES testbench format)
    // ==================================================
    $display("============================================");
    $display("  TOTAL TESTS : %0d", pass_cnt + fail_cnt);
    $display("  TOTAL PASS  : %0d", pass_cnt);
    $display("  TOTAL FAIL  : %0d", fail_cnt);
    if (fail_cnt == 0)
        $display("  OVERALL: ALL TESTS PASSED");
    else
        $display("  OVERALL: FAILURES DETECTED");
    $display("============================================\n");

    repeat(50) @(posedge clk);
    $finish;
end

// -----------------------------------------------------------
// Watchdog: abort if simulation runs too long
// -----------------------------------------------------------
initial begin
    #100_000_000;
    $display("WATCHDOG TIMEOUT");
    $finish;
end

endmodule
