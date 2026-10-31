// =============================================================================
// File   : tb_cnn_soc_top.sv
// Module : tb_cnn_soc_top
// Purpose: Full SoC Testbench verifying autonomous VeeR-EL2 CPU execution.
//          Preloads C firmware (boot.hex) into IMEM, boots CPU from 0x0000_0000,
//          and monitors UART transmission from CPU over AXI to console.
// =============================================================================

`timescale 1ns/1ps

module tb_cnn_soc_top;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam real CLK_PERIOD_NS = 10.0;       // 100 MHz system clock
    localparam int  BAUD_DIV      = 16;         // Matches uart_init(16) in C code
    localparam real BIT_PERIOD_NS = (BAUD_DIV + 1) * CLK_PERIOD_NS; // Exactly 170.0 ns per bit (counter counts 0..DIV)

    // -------------------------------------------------------------------------
    // Signals
    // -------------------------------------------------------------------------
    logic        clk;
    logic        rst_l;
    logic        dbg_rst_l;

    logic        uart_rx_i;
    wire         uart_tx_o;
    wire         uart_irq_o;
    wire         cnn_irq_o;
    wire         dist_irq_o;
    wire         timer_irq_o;
    wire         gpio_irq_o;
    wire         dma_irq_o;

    logic [31:0] gpio_i;
    wire  [31:0] gpio_o;
    wire  [31:0] gpio_dir_o;

    logic        jtag_tck;
    logic        jtag_tms;
    logic        jtag_tdi;
    logic        jtag_trst_n;
    wire         jtag_tdo;
    wire         jtag_tdoEn;

    logic        timer_int;
    logic        soft_int;

    logic        i_cpu_halt_req;
    logic        i_cpu_run_req;
    wire         o_cpu_halt_ack;
    wire         o_cpu_halt_status;
    wire         o_cpu_run_ack;
    wire         o_debug_mode_status;

    // String buffer to collect UART output
    string received_banner = "";
    int    char_count = 0;

    // -------------------------------------------------------------------------
    // Clock Generation (100 MHz)
    // -------------------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD_NS / 2.0) clk = ~clk;
    end

    // -------------------------------------------------------------------------
    // DUT: Complete CNN Anomaly Detection SoC Top-Level
    // -------------------------------------------------------------------------
    cnn_soc_top u_soc (
        .clk                 (clk),
        .rst_l               (rst_l),
        .dbg_rst_l           (dbg_rst_l),

        .uart_rx_i           (uart_rx_i),
        .uart_tx_o           (uart_tx_o),
        .uart_irq_o          (uart_irq_o),
        .cnn_irq_o           (cnn_irq_o),
        .dist_irq_o          (dist_irq_o),
        .timer_irq_o         (timer_irq_o),
        .gpio_irq_o          (gpio_irq_o),
        .dma_irq_o           (dma_irq_o),
        .gpio_i              (gpio_i),
        .gpio_o              (gpio_o),
        .gpio_dir_o          (gpio_dir_o),

        .jtag_tck            (jtag_tck),
        .jtag_tms            (jtag_tms),
        .jtag_tdi            (jtag_tdi),
        .jtag_trst_n         (jtag_trst_n),
        .jtag_tdo            (jtag_tdo),
        .jtag_tdoEn          (jtag_tdoEn),

        .timer_int           (timer_int),
        .soft_int            (soft_int),

        .i_cpu_halt_req      (i_cpu_halt_req),
        .i_cpu_run_req       (i_cpu_run_req),
        .o_cpu_halt_ack      (o_cpu_halt_ack),
        .o_cpu_halt_status   (o_cpu_halt_status),
        .o_cpu_run_ack       (o_cpu_run_ack),
        .o_debug_mode_status (o_debug_mode_status)
    );

    // -------------------------------------------------------------------------
    // Testbench Stimulus & Control
    // -------------------------------------------------------------------------
    string hex_file;

    initial begin
        // Static tie-offs
        uart_rx_i      = 1'b1; // UART RX idle high
        gpio_i         = 32'h0;
        jtag_tck       = 1'b0;
        jtag_tms       = 1'b0;
        jtag_tdi       = 1'b0;
        jtag_trst_n    = 1'b1;
        timer_int      = 1'b0;
        soft_int       = 1'b0;
        i_cpu_halt_req = 1'b0;
        i_cpu_run_req  = 1'b0;

        // Reset asserted
        rst_l     = 1'b0;
        dbg_rst_l = 1'b0;

        $display("=================================================================");
        $display("  STARTING VEER-EL2 RISC-V CPU -> AXI UART EXECUTION SIMULATION");
        $display("=================================================================");

        // Get hex file from command line plusarg or use default
        if (!$value$plusargs("hex=%s", hex_file)) begin
            hex_file = "sw/hello_uart/boot.hex";
        end

        $display("[TB] Preloading Instruction Memory (IMEM) with: %s", hex_file);
        $readmemh(hex_file, u_soc.u_imem.mem);
        $display("[TB] Preload completed (IMEM size: 64 KB, entry PC: 0x0000_0000).");

        // Hold reset for 100 ns (10 clock cycles)
        #(CLK_PERIOD_NS * 10);

        // Deassert reset
        @(posedge clk);
        rst_l     = 1'b1;
        dbg_rst_l = 1'b1;
        $display("[TB] Reset deasserted! VeeR-EL2 CPU is now fetching from 0x0000_0000...\n");

        // Timeout Watchdog: 10 ms is plenty for full UART execution
        #10_000_000;
        $display("\n[TB ERROR] TIMEOUT: Simulation exceeded 10 ms without receiving expected completion.");
        $display("[TB] Received %0d characters so far:\n%s", char_count, received_banner);
        $finish(2);
    end

    // -------------------------------------------------------------------------
    // Verdi FSDB Waveform Dumping Support (+fsdb or +dump)
    // -------------------------------------------------------------------------
    initial begin
        if ($test$plusargs("fsdb") || $test$plusargs("dump")) begin
            $display("[TB] Verdi FSDB waveform dumping ENABLED -> build_soc/soc_sim.fsdb");
            $fsdbDumpfile("build_soc/soc_sim.fsdb");
            $fsdbDumpvars(0, tb_cnn_soc_top);
        end
    end

    // -------------------------------------------------------------------------
    // Autonomous UART Monitor: Deserializes serial stream from uart_tx_o
    // -------------------------------------------------------------------------
    initial begin
        byte rx_byte;
        logic pass_detected = 1'b0;
        string pass_str   = "CPU UART TEST PASSED SUCCESSFULLY!\r\n";
        string border_str = "==================================================\r\n";

        // Wait for reset release
        wait(rst_l == 1'b1);

        forever begin
            // Wait for START bit (falling edge on uart_tx_o)
            @(negedge uart_tx_o);

            // Wait 1.5 bit periods to sample at the center of Data Bit 0
            #(BIT_PERIOD_NS * 1.5);

            // Sample 8 data bits (LSB first)
            rx_byte = 8'h0;
            for (int b = 0; b < 8; b++) begin
                rx_byte[b] = uart_tx_o;
                if (b < 7) begin
                    #(BIT_PERIOD_NS);
                end
            end

            // Wait 1 bit period to sample center of STOP bit
            #(BIT_PERIOD_NS);

            if (uart_tx_o == 1'b1) begin // Stop bit should be high
                $write("%c", rx_byte);
                $fflush();
                received_banner = {received_banner, string'(rx_byte)};
                char_count++;

                // Successful completion trigger: after full test runs and final banner prints on newline
                if (char_count > 500 && rx_byte == 8'h0A && gpio_o == 32'h00000055) begin
                    #(BIT_PERIOD_NS * 10); // small padding
                    $display("\n=================================================================");
                    $display("  [TESTBENCH SUCCESS] ALL C CODE COMMANDS EXECUTED TO UART!");
                    $display("  Total characters received : %0d", char_count);
                    $display("  Final GPIO_OUT state      : 0x%08X (Expected: 0x00000055)", gpio_o);
                    $display("=================================================================");
                    $finish(0);
                end else if ((gpio_o == 32'h00000025 && rx_byte == 8'h0A) ||
                             (char_count >= 11 && rx_byte == 8'h0A &&
                              received_banner.substr(received_banner.len() >= 13 ? received_banner.len()-13 : 0, received_banner.len()-1) == "Result = 25\r\n")) begin
                    #(BIT_PERIOD_NS * 10); // small padding
                    $display("\n=================================================================");
                    $display("  [TESTBENCH SUCCESS] RISC-V CPU TO UART ARITHMETIC TEST PASSED!");
                    $display("  Total characters received : %0d", char_count);
                    $display("  Final GPIO_OUT state      : 0x%08X (Expected: 0x00000025)", gpio_o);
                    $display("=================================================================");
                    $finish(0);
                end
            end else begin
                $display("\n[TB WARNING] UART Framing Error detected (stop bit was low, byte=0x%02X) at %0t!", rx_byte, $time);
                // Recover framing: wait until line returns to idle high
                wait(uart_tx_o == 1'b1);
            end

            // Complete the remaining 0.5 bit period of the stop bit
            #(BIT_PERIOD_NS * 0.5);
        end
    end

endmodule
