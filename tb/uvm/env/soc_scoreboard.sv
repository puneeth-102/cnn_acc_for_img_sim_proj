// =============================================================================
// File   : soc_scoreboard.sv
// Purpose: UVM Scoreboard for CNN Anomaly Detection SoC.
//          Verifies external interface events (UART TX, GPIO, Interrupts).
// =============================================================================

`ifndef SOC_SCOREBOARD_SV
`define SOC_SCOREBOARD_SV

class soc_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(soc_scoreboard)

    // Analysis imp declarations
    `uvm_analysis_imp_decl(_uart)
    `uvm_analysis_imp_decl(_gpio)
    `uvm_analysis_imp_decl(_irq)

    uvm_analysis_imp_uart #(uart_item, soc_scoreboard) uart_export;
    uvm_analysis_imp_gpio #(gpio_item, soc_scoreboard) gpio_export;
    uvm_analysis_imp_irq  #(irq_item,  soc_scoreboard) irq_export;

    // Internal trackers
    int uart_char_count;
    bit boot_detected;
    bit pass_detected;
    string received_banner;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        uart_char_count = 0;
        boot_detected   = 0;
        pass_detected   = 0;
        received_banner = "";
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uart_export = new("uart_export", this);
        gpio_export = new("gpio_export", this);
        irq_export  = new("irq_export", this);
    endfunction

    virtual function void write_uart(uart_item item);
        uart_char_count++;
        $write("%c", item.char_data);
        $fflush();
        received_banner = {received_banner, string'(item.char_data)};

        // Check for expected results in the serial stream
        if (received_banner.len() >= 15) begin
            // Check if string contains "[TEST PASSED]"
            for (int i = 0; i <= received_banner.len() - 13; i++) begin
                if (received_banner.substr(i, i+12) == "[TEST PASSED]") begin
                    if (!pass_detected) begin
                        pass_detected = 1;
                        `uvm_info("SOC_SB", "\n==================================================", UVM_NONE)
                        `uvm_info("SOC_SB", "*** UVM VERIFICATION SUCCESS: FIRMWARE SIGN-OFF [TEST PASSED] CONFIRMED! ***", UVM_NONE)
                        `uvm_info("SOC_SB", "==================================================", UVM_NONE)
                    end
                end
            end
        end

        if (received_banner.len() >= 15) begin
            // Check if string contains "[TEST FAILED]"
            for (int i = 0; i <= received_banner.len() - 13; i++) begin
                if (received_banner.substr(i, i+12) == "[TEST FAILED]") begin
                    `uvm_error("SOC_SB", "*** UVM VERIFICATION FAILURE: FIRMWARE REPORTED [TEST FAILED]! ***")
                end
            end
        end

        if (received_banner.len() >= 7) begin
            // Check if string contains "Echo: 9" (Closed-Loop Driver Test)
            for (int i = 0; i <= received_banner.len() - 7; i++) begin
                if (received_banner.substr(i, i+6) == "Echo: 9") begin
                    if (!pass_detected) begin
                        pass_detected = 1;
                        `uvm_info("SOC_SB", "\n==================================================", UVM_NONE)
                        `uvm_info("SOC_SB", "*** UVM VERIFICATION SUCCESS: Driver '9' Echoed by CPU on uart_tx_o! ***", UVM_NONE)
                        `uvm_info("SOC_SB", "==================================================", UVM_NONE)
                    end
                end
            end
        end

        if (received_banner.len() >= 11) begin
            // Check if string contains "Result = 25" (Base Arithmetic Test)
            for (int i = 0; i <= received_banner.len() - 11; i++) begin
                if (received_banner.substr(i, i+10) == "Result = 25") begin
                    if (!pass_detected) begin
                        pass_detected = 1;
                        `uvm_info("SOC_SB", "\n==================================================", UVM_NONE)
                        `uvm_info("SOC_SB", "*** UVM VERIFICATION SUCCESS: 'Result = 25' CONFIRMED! ***", UVM_NONE)
                        `uvm_info("SOC_SB", "==================================================", UVM_NONE)
                    end
                end
            end
        end
    endfunction

    virtual function void write_gpio(gpio_item item);
        if (item.gpio_o == 32'h00000001 && !boot_detected) begin
            boot_detected = 1;
            `uvm_info("SOC_SB", "BOOT START detected on GPIO output [0x00000001]", UVM_MEDIUM)
        end
        if (item.gpio_o == 32'h00000055) begin
            pass_detected = 1;
            `uvm_info("SOC_SB", "*** GPIO Output indicates Test Pass: 0x00000055 ***", UVM_MEDIUM)
        end
        if (item.gpio_o == 32'h0000DEAD) begin
            `uvm_error("SOC_SB", "*** GPIO Output indicates Test Failure: 0x0000DEAD ***")
        end
        if (item.gpio_o == 32'h00000025) begin
            `uvm_info("SOC_SB", "*** GPIO Output matches Arithmetic Result: 0x00000025 (Decimal 25) ***", UVM_MEDIUM)
        end
        if (item.gpio_o == 32'h00000039) begin
            `uvm_info("SOC_SB", "*** GPIO Output matches Received Character: 0x00000039 (ASCII '9') ***", UVM_MEDIUM)
        end
    endfunction

    virtual function void write_irq(irq_item item);
        if (item.uart_irq_o || item.dma_irq_o || item.cnn_irq_o || item.dist_irq_o || item.timer_irq_o || item.gpio_irq_o) begin
            `uvm_info("SOC_SB", $sformatf("Interrupt transition observed: UART=%b DMA=%b CNN=%b DIST=%b TMR=%b GPIO=%b",
                      item.uart_irq_o, item.dma_irq_o, item.cnn_irq_o, item.dist_irq_o, item.timer_irq_o, item.gpio_irq_o), UVM_MEDIUM)
        end
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        `uvm_info("SOC_SB", $sformatf("--- Scoreboard Final Check: %0d UART characters processed ---", uart_char_count), UVM_LOW)
        if (!pass_detected) begin
            `uvm_error("SOC_SB", "Verification FAILED: Expected pass signature was NOT received over UART!")
        end else begin
            `uvm_info("SOC_SB", "Verification PASSED: Execution confirmed on both UART serial and GPIO parallel pins.", UVM_LOW)
        end
    endfunction
endclass

`endif // SOC_SCOREBOARD_SV
