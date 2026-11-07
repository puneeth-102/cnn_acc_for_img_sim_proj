// =============================================================================
// File   : soc_scoreboard.sv
// Purpose: Standard UVM Scoreboard for VeeR-EL2 CNN Accelerator SoC.
//          Unifies external analysis exports for all 5 VIP interfaces:
//          - UART (serial bitstream deserialization & banner parsing)
//          - GPIO (parallel output monitoring & handshake decoding)
//          - IRQ (tracks DMA, CNN, DIST, TIMER, GPIO, UART interrupt lines)
//          - CLK_RST (reset transition tracking)
//          - JTAG (activity observation)
// =============================================================================

`ifndef SOC_SCOREBOARD_SV
`define SOC_SCOREBOARD_SV

class soc_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(soc_scoreboard)

    // Analysis imp declarations for all 5 VIPs
    `uvm_analysis_imp_decl(_clk_rst)
    `uvm_analysis_imp_decl(_uart)
    `uvm_analysis_imp_decl(_gpio)
    `uvm_analysis_imp_decl(_irq)
    `uvm_analysis_imp_decl(_jtag)

    uvm_analysis_imp_clk_rst #(clk_rst_item, soc_scoreboard) clk_rst_export;
    uvm_analysis_imp_uart    #(uart_item,    soc_scoreboard) uart_export;
    uvm_analysis_imp_gpio    #(gpio_item,    soc_scoreboard) gpio_export;
    uvm_analysis_imp_irq     #(irq_item,     soc_scoreboard) irq_export;
    uvm_analysis_imp_jtag    #(jtag_item,    soc_scoreboard) jtag_export;

    // Trackers - General Status
    bit pass_detected;
    bit fail_detected;
    bit boot_detected;
    bit rst_deasserted;

    // Trackers - UART
    int    uart_char_count;
    string received_banner;

    // Trackers - GPIO
    logic [31:0] last_gpio_o;
    logic [31:0] last_gpio_dir_o;
    int          gpio_trans_count;

    // Trackers - Interrupts
    int  dma_irq_count;
    int  cnn_irq_count;
    int  dist_irq_count;
    int  timer_irq_count;
    int  gpio_irq_count;
    int  uart_irq_count;

    bit  last_dma_irq;
    bit  last_cnn_irq;
    bit  last_dist_irq;
    bit  last_timer_irq;
    bit  last_gpio_irq;
    bit  last_uart_irq;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        pass_detected    = 0;
        fail_detected    = 0;
        boot_detected    = 0;
        rst_deasserted   = 0;
        uart_char_count  = 0;
        received_banner  = "";
        last_gpio_o      = 32'h0;
        last_gpio_dir_o  = 32'h0;
        gpio_trans_count = 0;
        dma_irq_count    = 0;
        cnn_irq_count    = 0;
        dist_irq_count   = 0;
        timer_irq_count  = 0;
        gpio_irq_count   = 0;
        uart_irq_count   = 0;
        last_dma_irq     = 0;
        last_cnn_irq     = 0;
        last_dist_irq    = 0;
        last_timer_irq   = 0;
        last_gpio_irq    = 0;
        last_uart_irq    = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        clk_rst_export = new("clk_rst_export", this);
        uart_export    = new("uart_export",    this);
        gpio_export    = new("gpio_export",    this);
        irq_export     = new("irq_export",     this);
        jtag_export    = new("jtag_export",    this);
    endfunction

    // -------------------------------------------------------------------------
    // 1. UART Monitor Analysis Hook
    // -------------------------------------------------------------------------
    virtual function void write_uart(uart_item item);
        uart_char_count++;
        $write("%c", item.char_data);
        $fflush();
        received_banner = {received_banner, string'(item.char_data)};

        // Universal Pass signature check: "[TEST PASSED]"
        if (received_banner.len() >= 15) begin
            for (int i = 0; i <= received_banner.len() - 13; i++) begin
                if (received_banner.substr(i, i+12) == "[TEST PASSED]") begin
                    if (!pass_detected) begin
                        pass_detected = 1;
                        `uvm_info("SOC_SB", "\n==================================================", UVM_NONE)
                        `uvm_info("SOC_SB", "*** UVM VERIFICATION SUCCESS: FIRMWARE [TEST PASSED] CONFIRMED! ***", UVM_NONE)
                        `uvm_info("SOC_SB", "==================================================", UVM_NONE)
                    end
                end
            end
        end

        // Universal Failure signature check: "[TEST FAILED]"
        if (received_banner.len() >= 15) begin
            for (int i = 0; i <= received_banner.len() - 13; i++) begin
                if (received_banner.substr(i, i+12) == "[TEST FAILED]") begin
                    fail_detected = 1;
                    `uvm_error("SOC_SB", "*** UVM VERIFICATION FAILURE: FIRMWARE REPORTED [TEST FAILED]! ***")
                end
            end
        end

        // Support for interactive echo test
        if (received_banner.len() >= 7) begin
            for (int i = 0; i <= received_banner.len() - 7; i++) begin
                if (received_banner.substr(i, i+6) == "Echo: 9") begin
                    pass_detected = 1;
                end
            end
        end

        // Support for base arithmetic test
        if (received_banner.len() >= 11) begin
            for (int i = 0; i <= received_banner.len() - 11; i++) begin
                if (received_banner.substr(i, i+10) == "Result = 25") begin
                    pass_detected = 1;
                end
            end
        end
    endfunction

    // -------------------------------------------------------------------------
    // 2. GPIO Monitor Analysis Hook
    // -------------------------------------------------------------------------
    virtual function void write_gpio(gpio_item item);
        gpio_trans_count++;
        last_gpio_o     = item.gpio_o;
        last_gpio_dir_o = item.gpio_dir_o;

        if (item.gpio_o == 32'h00000001 && !boot_detected) begin
            boot_detected = 1;
            `uvm_info("SOC_SB", "BOOT START detected on GPIO output [0x00000001]", UVM_MEDIUM)
        end
        if (item.gpio_o == 32'h00000055) begin
            pass_detected = 1;
            `uvm_info("SOC_SB", "*** GPIO Output indicates Test Pass: 0x00000055 ***", UVM_MEDIUM)
        end
        if (item.gpio_o == 32'h0000DEAD) begin
            fail_detected = 1;
            `uvm_error("SOC_SB", "*** GPIO Output indicates Test Failure: 0x0000DEAD ***")
        end
        if (item.gpio_o == 32'h00000025) begin
            pass_detected = 1;
        end
        if (item.gpio_o == 32'h00000039) begin
            pass_detected = 1;
        end
    endfunction

    // -------------------------------------------------------------------------
    // 3. IRQ Monitor Analysis Hook
    // -------------------------------------------------------------------------
    virtual function void write_irq(irq_item item);
        if (item.dma_irq_o   && !last_dma_irq)   dma_irq_count++;
        if (item.cnn_irq_o   && !last_cnn_irq)   cnn_irq_count++;
        if (item.dist_irq_o  && !last_dist_irq)  dist_irq_count++;
        if (item.timer_irq_o && !last_timer_irq) timer_irq_count++;
        if (item.gpio_irq_o  && !last_gpio_irq)  gpio_irq_count++;
        if (item.uart_irq_o  && !last_uart_irq)  uart_irq_count++;

        last_dma_irq   = item.dma_irq_o;
        last_cnn_irq   = item.cnn_irq_o;
        last_dist_irq  = item.dist_irq_o;
        last_timer_irq = item.timer_irq_o;
        last_gpio_irq  = item.gpio_irq_o;
        last_uart_irq  = item.uart_irq_o;

        if (item.uart_irq_o || item.dma_irq_o || item.cnn_irq_o || item.dist_irq_o || item.timer_irq_o || item.gpio_irq_o) begin
            `uvm_info("SOC_SB", $sformatf("Interrupt transition observed: UART=%b DMA=%b CNN=%b DIST=%b TMR=%b GPIO=%b",
                      item.uart_irq_o, item.dma_irq_o, item.cnn_irq_o, item.dist_irq_o, item.timer_irq_o, item.gpio_irq_o), UVM_HIGH)
        end
    endfunction

    // -------------------------------------------------------------------------
    // 4. CLK/RST Monitor Analysis Hook
    // -------------------------------------------------------------------------
    virtual function void write_clk_rst(clk_rst_item item);
        if (item.rst_l && !rst_deasserted) begin
            rst_deasserted = 1;
            `uvm_info("SOC_SB", "Reset deassertion captured by clk_rst monitor", UVM_HIGH)
        end
    endfunction

    // -------------------------------------------------------------------------
    // 5. JTAG Monitor Analysis Hook
    // -------------------------------------------------------------------------
    virtual function void write_jtag(jtag_item item);
        // Passive observation
    endfunction

    // -------------------------------------------------------------------------
    // Final Check Phase
    // -------------------------------------------------------------------------
    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        `uvm_info("SOC_SB", "--------------------------------------------------", UVM_LOW)
        `uvm_info("SOC_SB", "--- SCOREBOARD FINAL VERIFICATION REPORT ---", UVM_LOW)
        `uvm_info("SOC_SB", $sformatf("  UART characters processed : %0d", uart_char_count), UVM_LOW)
        `uvm_info("SOC_SB", $sformatf("  GPIO transitions captured : %0d (last=0x%08x, dir=0x%08x)",
                  gpio_trans_count, last_gpio_o, last_gpio_dir_o), UVM_LOW)
        `uvm_info("SOC_SB", $sformatf("  Interrupt counts observed : DMA=%0d CNN=%0d DIST=%0d TMR=%0d GPIO=%0d UART=%0d",
                  dma_irq_count, cnn_irq_count, dist_irq_count, timer_irq_count, gpio_irq_count, uart_irq_count), UVM_LOW)
        `uvm_info("SOC_SB", "--------------------------------------------------", UVM_LOW)

        if (fail_detected) begin
            `uvm_error("SOC_SB", "Verification FAILED: Explicit failure condition detected!")
        end else if (!pass_detected) begin
            `uvm_error("SOC_SB", "Verification FAILED: Test completed without confirming expected PASS signature!")
        end else begin
            `uvm_info("SOC_SB", "*** SCOREBOARD SIGN-OFF: Test criteria successfully PASSED! ***", UVM_LOW)
        end
    endfunction
endclass

`endif // SOC_SCOREBOARD_SV
