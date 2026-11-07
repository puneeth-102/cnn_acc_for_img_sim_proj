// =============================================================================
// File   : tc_dma_01.sv
// Test   : TC_DMA_01 - DMA Register R/W & Reset Verification
// Testplan: Checkpoint: CTRL and STATUS read 0x0 on reset. Writes to SRC, DST,
//           and LEN retain values under standard AXI-Lite access without bus traps.
// =============================================================================

`ifndef TC_DMA_01_SV
`define TC_DMA_01_SV

class tc_dma_01 extends soc_base_test;
    `uvm_component_utils(tc_dma_01)

    function new(string name = "tc_dma_01", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void post_run_check();
        if (env.sb.pass_detected) begin
            `uvm_info("TC_DMA_01", "[CHECK PASSED] TC_DMA_01 DMA Register R/W & Reset verified successfully!", UVM_LOW)
        end else begin
            `uvm_error("TC_DMA_01", "[CHECK FAILED] TC_DMA_01 did not pass scoreboard verification!")
        end
    endfunction

endclass : tc_dma_01

`endif // TC_DMA_01_SV
