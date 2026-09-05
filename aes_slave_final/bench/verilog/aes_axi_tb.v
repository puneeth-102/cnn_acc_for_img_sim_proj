// ============================================================
// aes_axi_tb.v
// VCS testbench — AXI4-Lite master driving aes_axi_top.
// Tests 5 encrypt + 5 decrypt vectors with PASS/FAIL.
// FSDB generated for Verdi.
// ============================================================
`include "timescale.v"

module aes_axi_tb;

// -----------------------------------------------------------
// Clock / reset
// -----------------------------------------------------------
reg clk, resetn;
initial clk = 0;
always #5 clk = ~clk;   // 100 MHz

// -----------------------------------------------------------
// AXI4-Lite signals
// -----------------------------------------------------------
reg  [5:0]  awaddr;  reg  awvalid;  wire awready;
reg  [31:0] wdata;   reg  [3:0] wstrb; reg wvalid; wire wready;
wire [1:0]  bresp;   wire bvalid;   reg  bready;
reg  [5:0]  araddr;  reg  arvalid;  wire arready;
wire [31:0] rdata;   wire [1:0] rresp; wire rvalid; reg rready;

// -----------------------------------------------------------
// DUT
// -----------------------------------------------------------
aes_axi_top dut (
    .s_axi_aclk    (clk),
    .s_axi_aresetn (resetn),
    .s_axi_awaddr  (awaddr),   .s_axi_awvalid (awvalid),
    .s_axi_awready (awready),
    .s_axi_wdata   (wdata),    .s_axi_wstrb   (wstrb),
    .s_axi_wvalid  (wvalid),   .s_axi_wready  (wready),
    .s_axi_bresp   (bresp),    .s_axi_bvalid  (bvalid),
    .s_axi_bready  (bready),
    .s_axi_araddr  (araddr),   .s_axi_arvalid (arvalid),
    .s_axi_arready (arready),
    .s_axi_rdata   (rdata),    .s_axi_rresp   (rresp),
    .s_axi_rvalid  (rvalid),   .s_axi_rready  (rready)
);

// -----------------------------------------------------------
// FSDB dump
// -----------------------------------------------------------
initial begin
    $fsdbDumpfile("waves/aes_axi_dump.fsdb");
    $fsdbDumpvars(0, aes_axi_tb);
end

// -----------------------------------------------------------
// Test vectors
// Format: {key[127:0], plaintext[127:0], expected_cipher[127:0]}
// -----------------------------------------------------------
reg [127:0] tv_key   [0:4];
reg [127:0] tv_plain [0:4];
reg [127:0] tv_ciph  [0:4];

initial begin
    // V0: KEY=DEADBEEF*4  PLAIN=CAFEBABE*4
    tv_key  [0] = 128'hDEADBEEFDEADBEEFDEADBEEFDEADBEEF;
    tv_plain[0] = 128'hCAFEBABECAFEBABECAFEBABECAFEBABE;
    tv_ciph [0] = 128'hB3B10B9D291BBE674EDA97ED9F9BC78A;

    // V1: KEY=ABCDEF01*4  PLAIN=12345678*4
    tv_key  [1] = 128'hABCDEF01ABCDEF01ABCDEF01ABCDEF01;
    tv_plain[1] = 128'h12345678123456781234567812345678;
    tv_ciph [1] = 128'hF7581D448A02E808F8FF8079FBB46964;

    // V2: KEY=AAAA*16  PLAIN=5555*16
    tv_key  [2] = 128'hAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA;
    tv_plain[2] = 128'h55555555555555555555555555555555;
    tv_ciph [2] = 128'h5A7EFE3965060F8F531935F9EFB7BFC5;

    // V3: KEY=00..0F  PLAIN="HelloWorld!12345"
    tv_key  [3] = 128'h000102030405060708090A0B0C0D0E0F;
    tv_plain[3] = 128'h48656C6C6F576F726C64213132333435;
    tv_ciph [3] = 128'h40A3D27C29B4BBBFC0C17DC2BC11C552;

    // V4: KEY=FEEDFACE*4  PLAIN=BADDCAFE*4
    tv_key  [4] = 128'hFEEDFACEFEEDFACEFEEDFACEFEEDFACE;
    tv_plain[4] = 128'hBADDCAFEBADDCAFEBADDCAFEBADDCAFE;
    tv_ciph [4] = 128'h728DA8CCD1F3ACBCC5171417FA23CB37;
end

// -----------------------------------------------------------
// Counters
// -----------------------------------------------------------
integer i;
integer pass_cnt, fail_cnt;
reg [127:0] got;

// -----------------------------------------------------------
// AXI helper tasks
// -----------------------------------------------------------

// AXI write: drive AW and W simultaneously
task axi_write;
    input [5:0]  addr;
    input [31:0] data;
    begin
        @(posedge clk); #1;
        awaddr  = addr;  awvalid = 1'b1;
        wdata   = data;  wstrb   = 4'hF; wvalid = 1'b1;
        // Wait for both handshakes
        fork
            begin @(posedge clk); while (!awready) @(posedge clk); #1; awvalid = 0; end
            begin @(posedge clk); while (!wready)  @(posedge clk); #1; wvalid  = 0; end
        join
        // Wait for B response
        bready = 1'b1;
        @(posedge clk); while (!bvalid) @(posedge clk);
        #1; bready = 0;
    end
endtask

// AXI read
task axi_read;
    input  [5:0]  addr;
    output [31:0] data;
    begin
        @(posedge clk); #1;
        araddr  = addr; arvalid = 1'b1;
        @(posedge clk); while (!arready) @(posedge clk);
        #1; arvalid = 0;
        // Wait for read data
        rready = 1'b1;
        @(posedge clk); while (!rvalid) @(posedge clk);
        data   = rdata;
        #1; rready = 0;
    end
endtask

// Poll CPSR until DONE (bit1) is set; timeout after 100 cycles
task wait_done;
    integer timeout;
    reg [31:0] cpsr_val;
    begin
        timeout = 0;
        cpsr_val = 0;
        while (!cpsr_val[1] && timeout < 100) begin
            axi_read(6'h00, cpsr_val);
            timeout = timeout + 1;
        end
        if (timeout >= 100)
            $display("  WARNING: DONE timeout!");
    end
endtask

// Poll CPSR until KDONE (bit3) is set; timeout after 100 cycles
task wait_kdone;
    integer timeout;
    reg [31:0] cpsr_val;
    begin
        timeout = 0;
        cpsr_val = 0;
        while (!cpsr_val[3] && timeout < 100) begin
            axi_read(6'h00, cpsr_val);
            timeout = timeout + 1;
        end
        if (timeout >= 100)
            $display("  WARNING: KDONE timeout!");
    end
endtask

// Write 128-bit key via KEY0-KEY3
task write_key;
    input [127:0] k;
    begin
        axi_write(6'h04, k[31:0]);    // KEY0
        axi_write(6'h08, k[63:32]);   // KEY1
        axi_write(6'h0C, k[95:64]);   // KEY2
        axi_write(6'h10, k[127:96]);  // KEY3
    end
endtask

// Write 128-bit text_in via TEXT_IN0-3
task write_text_in;
    input [127:0] t;
    begin
        axi_write(6'h14, t[31:0]);    // TEXT_IN0
        axi_write(6'h18, t[63:32]);   // TEXT_IN1
        axi_write(6'h1C, t[95:64]);   // TEXT_IN2
        axi_write(6'h20, t[127:96]);  // TEXT_IN3
    end
endtask

// Read 128-bit text_out from TEXT_OUT0-3
task read_text_out;
    output [127:0] t;
    reg [31:0] d0, d1, d2, d3;
    begin
        axi_read(6'h24, d0);  // TEXT_OUT0
        axi_read(6'h28, d1);  // TEXT_OUT1
        axi_read(6'h2C, d2);  // TEXT_OUT2
        axi_read(6'h30, d3);  // TEXT_OUT3
        t = {d3, d2, d1, d0};
    end
endtask

// -----------------------------------------------------------
// Main test sequence
// -----------------------------------------------------------
initial begin
    // Initialise AXI master signals
    awaddr = 0; awvalid = 0;
    wdata  = 0; wstrb   = 4'hF; wvalid = 0;
    bready = 0;
    araddr = 0; arvalid = 0;
    rready = 0;
    pass_cnt = 0; fail_cnt = 0;

    // Reset
    resetn = 0;
    repeat(10) @(posedge clk);
    resetn = 1;
    repeat(5)  @(posedge clk);

    // Release AES reset via CPSR[4]=1 (RST=1 -> active-low deasserted)
    axi_write(6'h00, 32'h00000010); // CPSR: RST=1

    $display("\n============================================");
    $display("  AES AXI4-Lite Wrapper Testbench");
    $display("============================================\n");

    // ==================================================
    // ENCRYPTION TESTS  (MODE=0)
    // ==================================================
    $display("--- ENCRYPTION TESTS ---");
    for (i = 0; i < 5; i = i + 1) begin
        $display("Vector %0d:", i);
        $display("  KEY   : %032h", tv_key[i]);
        $display("  PLAIN : %032h", tv_plain[i]);

        // Write key
        write_key(tv_key[i]);

        // Write plaintext
        write_text_in(tv_plain[i]);

        // Set MODE=0 (encrypt), RST=1
        axi_write(6'h00, 32'h00000010); // CPSR: RST=1, MODE=0

        // Trigger LD (bit0) – one pulse
        axi_write(6'h00, 32'h00000011); // CPSR: RST=1, LD=1

        // Wait for DONE
        wait_done;

        // Read result
        read_text_out(got);

        $display("  EXPECT: %032h", tv_ciph[i]);
        $display("  GOT   : %032h", got);
        if (got === tv_ciph[i]) begin
            $display("  RESULT: PASS\n");
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  RESULT: FAIL *** MISMATCH ***\n");
            fail_cnt = fail_cnt + 1;
        end
    end

    // ==================================================
    // DECRYPTION TESTS  (MODE=1)
    // For each vector: load key, do KLD, wait KDONE,
    // load ciphertext as text_in, assert LD, wait DONE,
    // compare output with original plaintext.
    // ==================================================
    $display("--- DECRYPTION TESTS ---");
    for (i = 0; i < 5; i = i + 1) begin
        $display("Vector %0d:", i);
        $display("  KEY   : %032h", tv_key[i]);
        $display("  CIPHER: %032h", tv_ciph[i]);

        // Write key
        write_key(tv_key[i]);

        // Set MODE=1 (decrypt), RST=1
        axi_write(6'h00, 32'h00000030); // CPSR: MODE=1, RST=1

        // Trigger KLD (bit2) – one pulse
        axi_write(6'h00, 32'h00000034); // CPSR: MODE=1, RST=1, KLD=1

        // Wait for KDONE
        wait_kdone;

        // Write ciphertext as input
        write_text_in(tv_ciph[i]);

        // Trigger LD (bit0)
        axi_write(6'h00, 32'h00000031); // CPSR: MODE=1, RST=1, LD=1

        // Wait for DONE
        wait_done;

        // Read result
        read_text_out(got);

        $display("  EXPECT: %032h", tv_plain[i]);
        $display("  GOT   : %032h", got);
        if (got === tv_plain[i]) begin
            $display("  RESULT: PASS\n");
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("  RESULT: FAIL *** MISMATCH ***\n");
            fail_cnt = fail_cnt + 1;
        end
    end

    // ==================================================
    // Summary
    // ==================================================
    $display("============================================");
    $display("  TOTAL PASS: %0d / 10", pass_cnt);
    $display("  TOTAL FAIL: %0d / 10", fail_cnt);
    if (fail_cnt == 0)
        $display("  OVERALL: ALL TESTS PASSED");
    else
        $display("  OVERALL: FAILURES DETECTED");
    $display("============================================\n");

    repeat(20) @(posedge clk);
    $finish;
end

// Timeout watchdog
initial begin
    #500000;
    $display("WATCHDOG TIMEOUT");
    $finish;
end

endmodule
