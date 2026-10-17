// =============================================================================
// File   : soc_scoreboard.sv
// Class  : soc_scoreboard
// Purpose: Multi-agent UVM Scoreboard with golden checking across all 5 IP domains
// =============================================================================

`ifndef SOC_SCOREBOARD_SV
`define SOC_SCOREBOARD_SV

`uvm_analysis_imp_decl(_uart)
`uvm_analysis_imp_decl(_gpio)
`uvm_analysis_imp_decl(_cnn)
`uvm_analysis_imp_decl(_dist)
`uvm_analysis_imp_decl(_dma)

class soc_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(soc_scoreboard)

    // Dedicated analysis imps for each agent
    uvm_analysis_imp_uart #(uart_seq_item, soc_scoreboard) uart_export;
    uvm_analysis_imp_gpio #(gpio_seq_item, soc_scoreboard) gpio_export;
    uvm_analysis_imp_cnn  #(cnn_seq_item,  soc_scoreboard) cnn_export;
    uvm_analysis_imp_dist #(dist_seq_item, soc_scoreboard) dist_export;
    uvm_analysis_imp_dma  #(dma_seq_item,  soc_scoreboard) dma_export;

    // Verification Tracking Flags
    bit uart_pass_detected;
    bit gpio_pass_detected;
    bit cnn_embedding_verified;
    bit dist_normal_verified;
    bit dist_anomaly_verified;
    bit dma_transfer_verified;

    int uart_line_count;
    int dist_calc_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        uart_export = new("uart_export", this);
        gpio_export = new("gpio_export", this);
        cnn_export  = new("cnn_export",  this);
        dist_export = new("dist_export", this);
        dma_export  = new("dma_export",  this);

        uart_pass_detected     = 1'b0;
        gpio_pass_detected     = 1'b0;
        cnn_embedding_verified = 1'b0;
        dist_normal_verified   = 1'b0;
        dist_anomaly_verified  = 1'b0;
        dma_transfer_verified  = 1'b0;
        uart_line_count        = 0;
        dist_calc_count        = 0;
    endfunction

    // -------------------------------------------------------------------------
    // 1. UART Stream Checker
    // -------------------------------------------------------------------------
    virtual function void write_uart(uart_seq_item item);
        if (item.is_full_line) begin
            uart_line_count++;
            if (str_contains(item.line_string, "ALL ANOMALY DETECTION TESTS PASSED SUCCESSFULLY!")) begin
                uart_pass_detected = 1'b1;
                `uvm_info("SCB_UART", "Detected official firmware PASS banner in UART log!", UVM_LOW)
            end
        end
    endfunction

    // -------------------------------------------------------------------------
    // 2. GPIO & Pin Checker
    // -------------------------------------------------------------------------
    virtual function void write_gpio(gpio_seq_item item);
        if (item.gpio_out == 32'h00000055) begin
            gpio_pass_detected = 1'b1;
            `uvm_info("SCB_GPIO", "Detected final GPIO_OUT pass state 0x00000055!", UVM_LOW)
        end
    endfunction

    // -------------------------------------------------------------------------
    // 3. CNN Feature Vector Checker
    // -------------------------------------------------------------------------
    virtual function void write_cnn(cnn_seq_item item);
        if (item.event_type == cnn_seq_item::CNN_EMBEDDING_READY) begin
            // Verify that CNN produced valid non-zero embeddings
            if (item.embedding[0] != 0 && item.embedding[1] != 0) begin
                cnn_embedding_verified = 1'b1;
                `uvm_info("SCB_CNN", $sformatf("CNN Embedding Vector Verified: Emb[0]=0x%08X", item.embedding[0]), UVM_LOW)
            end else begin
                `uvm_error("SCB_CNN", "CNN produced all-zero embedding vector!")
            end
        end
    endfunction

    // -------------------------------------------------------------------------
    // 4. Distance & Anomaly Classification Checker
    // -------------------------------------------------------------------------
    virtual function void write_dist(dist_seq_item item);
        if (item.event_type == dist_seq_item::DIST_CALC_DONE) begin
            dist_calc_count++;
            if (item.result_match == 1'b1 && item.min_distance <= item.threshold) begin
                dist_normal_verified = 1'b1;
                `uvm_info("SCB_DIST", $sformatf("Test 1 Passed: Normal Match Verified (Dist=%0d <= Thresh=%0d)",
                    item.min_distance, item.threshold), UVM_LOW)
            end else if (item.result_match == 1'b0 && item.min_distance > item.threshold) begin
                dist_anomaly_verified = 1'b1;
                `uvm_info("SCB_DIST", $sformatf("Test 2 Passed: Anomaly Detection Verified (Dist=%0d > Thresh=%0d)",
                    item.min_distance, item.threshold), UVM_LOW)
            end else begin
                `uvm_error("SCB_DIST", $sformatf("Distance classification mismatch: Dist=%0d Thresh=%0d Result=%0d",
                    item.min_distance, item.threshold, item.result_match))
            end
        end
    endfunction

    // -------------------------------------------------------------------------
    // 5. DMA Block Transfer Checker
    // -------------------------------------------------------------------------
    virtual function void write_dma(dma_seq_item item);
        if (item.length_bytes == 256 && item.dst_addr == 32'h20003100) begin
            dma_transfer_verified = 1'b1;
            `uvm_info("SCB_DMA", "DMA transfer verified: 256 bytes transferred to CNN buffer 0x20003100", UVM_LOW)
        end
    endfunction

    // -------------------------------------------------------------------------
    // Helper: String Substring Search
    // -------------------------------------------------------------------------
    function bit str_contains(string haystack, string needle);
        int h_len, n_len;
        h_len = haystack.len();
        n_len = needle.len();
        if (n_len > h_len) return 1'b0;
        for (int i = 0; i <= h_len - n_len; i++) begin
            if (haystack.substr(i, i + n_len - 1) == needle) return 1'b1;
        end
        return 1'b0;
    endfunction

    // -------------------------------------------------------------------------
    // Final Report Phase: Scorecard Printout
    // -------------------------------------------------------------------------
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCB_REPORT", "=================================================================", UVM_NONE)
        `uvm_info("SCB_REPORT", "             UVM SOC SCOREBOARD VERIFICATION REPORT              ", UVM_NONE)
        `uvm_info("SCB_REPORT", "=================================================================", UVM_NONE)
        `uvm_info("SCB_REPORT", $sformatf("  1. DMA Image Transfer (256B)  : %s", dma_transfer_verified  ? "PASSED" : "FAILED"), UVM_NONE)
        `uvm_info("SCB_REPORT", $sformatf("  2. CNN 16-D Feature Embedding : %s", cnn_embedding_verified ? "PASSED" : "FAILED"), UVM_NONE)
        `uvm_info("SCB_REPORT", $sformatf("  3. Distance Test 1 (Normal)   : %s", dist_normal_verified   ? "PASSED" : "FAILED"), UVM_NONE)
        `uvm_info("SCB_REPORT", $sformatf("  4. Distance Test 2 (Anomaly)  : %s", dist_anomaly_verified  ? "PASSED" : "FAILED"), UVM_NONE)
        `uvm_info("SCB_REPORT", $sformatf("  5. GPIO Handshake Status (0x55): %s", gpio_pass_detected    ? "PASSED" : "FAILED"), UVM_NONE)
        `uvm_info("SCB_REPORT", $sformatf("  6. UART Firmware Console Log  : %s (%0d lines)", uart_pass_detected ? "PASSED" : "FAILED", uart_line_count), UVM_NONE)
        `uvm_info("SCB_REPORT", "=================================================================", UVM_NONE)

        if (dma_transfer_verified && cnn_embedding_verified && dist_normal_verified &&
            dist_anomaly_verified && gpio_pass_detected && uart_pass_detected) begin
            `uvm_info("SCB_REPORT", "  [FINAL RESULT] >>> ALL 6 SOC DOMAINS VERIFIED SUCCESSFULLY! <<<", UVM_NONE)
        end else begin
            `uvm_error("SCB_REPORT", "  [FINAL RESULT] >>> SOME SOC DOMAINS FAILED VERIFICATION! <<<")
        end
        `uvm_info("SCB_REPORT", "=================================================================", UVM_NONE)
    endfunction

endclass : soc_scoreboard

`endif // SOC_SCOREBOARD_SV
