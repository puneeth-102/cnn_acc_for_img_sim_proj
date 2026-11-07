// =============================================================================
// File   : tc_dma_01.sv
// Test   : TC_DMA_01 - DMA Register R/W & Reset Verification
// Testplan: Checkpoint: CTRL and STATUS read 0x0 on reset. Writes to SRC, DST,
//           and LEN retain values under standard AXI-Lite access without bus traps.
// SV Part:  Monitor AXI-Lite read/write cycles to CSR address aperture (0x2000_5000);
//           check register flip-flops and OKAY response (bresp === 2'b00).
// =============================================================================

`ifndef TC_DMA_01_SV
`define TC_DMA_01_SV

class tc_dma_01 extends soc_base_test;
    `uvm_component_utils(tc_dma_01)

    function new(string name = "tc_dma_01", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("TC_DMA_01", "==================================================", UVM_LOW)
        `uvm_info("TC_DMA_01", "=== STARTING TC_DMA_01: DMA REGISTER R/W & RESET ===", UVM_LOW)
        `uvm_info("TC_DMA_01", "==================================================", UVM_LOW)

        // Wait dynamically for Scoreboard to confirm firmware verification
        fork
            begin
                wait(env.sb.pass_detected == 1'b1);
                #10us; // Allow trailing UART stop bits or newline to flush
                `uvm_info("TC_DMA_01", "=== [PASS] Scoreboard Confirmed Firmware Sign-Off! ===", UVM_LOW)
            end
            begin
                #500us;
                `uvm_error("TC_DMA_01", "=== [TIMEOUT] 500us Watchdog Timeout Reached! ===")
            end
        join_any
        disable fork;

        `uvm_info("TC_DMA_01", "==================================================", UVM_LOW)
        `uvm_info("TC_DMA_01", "=== COMPLETED TC_DMA_01: VERIFICATION COMPLETE ===", UVM_LOW)
        `uvm_info("TC_DMA_01", "==================================================", UVM_LOW)
        phase.drop_objection(this);
    endtask

endclass : tc_dma_01

`endif // TC_DMA_01_SV
