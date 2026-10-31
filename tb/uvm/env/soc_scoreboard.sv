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

    function new(string name, uvm_component parent);
        super.new(name, parent);
        uart_char_count = 0;
        boot_detected   = 0;
        pass_detected   = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uart_export = new("uart_export", this);
        gpio_export = new("gpio_export", this);
        irq_export  = new("irq_export", this);
    endfunction

    virtual function void write_uart(uart_item item);
        uart_char_count++;
        `uvm_info("SOC_SB", $sformatf("UART Transaction #%0d observed", uart_char_count), UVM_HIGH)
    endfunction

    virtual function void write_gpio(gpio_item item);
        if (item.gpio_o == 32'h00000001 && !boot_detected) begin
            boot_detected = 1;
            `uvm_info("SOC_SB", "BOOT START detected on GPIO output [0x00000001]", UVM_MEDIUM)
        end
        if (item.gpio_o == 32'h00000025 && !pass_detected) begin
            pass_detected = 1;
            `uvm_info("SOC_SB", "*** TEST PASS: Arithmetic Result = 25 verified on GPIO! ***", UVM_NONE)
        end
    endfunction

    virtual function void write_irq(irq_item item);
        if (item.uart_irq_o || item.dma_irq_o || item.cnn_irq_o || item.dist_irq_o) begin
            `uvm_info("SOC_SB", $sformatf("Interrupt pulse observed: UART=%b DMA=%b CNN=%b DIST=%b",
                      item.uart_irq_o, item.dma_irq_o, item.cnn_irq_o, item.dist_irq_o), UVM_HIGH)
        end
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        `uvm_info("SOC_SB", $sformatf("--- Scoreboard Final Check: %0d UART transactions processed ---", uart_char_count), UVM_LOW)
    endfunction
endclass

`endif // SOC_SCOREBOARD_SV
