// =============================================================================
// File   : soc_anomaly_test.sv
// Class  : soc_anomaly_test
// Purpose: End-to-end SoC Image Anomaly Detection UVM Test
// =============================================================================

`ifndef SOC_ANOMALY_TEST_SV
`define SOC_ANOMALY_TEST_SV

class soc_anomaly_test extends soc_base_test;
    `uvm_component_utils(soc_anomaly_test)

    function new(string name = "soc_anomaly_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this, "Starting Anomaly Detection SoC Verification");

        `uvm_info("ANOMALY_TEST", "Waiting for autonomous CPU execution and accelerator verification...", UVM_LOW)

        // Wait for Scoreboard to confirm completion from all domains
        fork
            begin
                wait(env.m_scoreboard.uart_pass_detected && env.m_scoreboard.gpio_pass_detected);
                `uvm_info("ANOMALY_TEST", "Scoreboard confirmed completion! Finalizing test...", UVM_LOW)
                #1000ns; // Drain time
            end
            begin
                #10_000_000ns; // 10 ms Watchdog Timeout
                `uvm_fatal("ANOMALY_TEST", "Watchdog timeout: Simulation exceeded 10 ms without receiving pass condition!")
            end
        join_any
        disable fork;

        phase.drop_objection(this, "Completed Anomaly Detection SoC Verification");
    endtask

endclass : soc_anomaly_test

`endif // SOC_ANOMALY_TEST_SV
