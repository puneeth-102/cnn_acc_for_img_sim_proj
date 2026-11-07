// =============================================================================
// File   : soc_base_test.sv
// Purpose: Standard UVM Base Test for VeeR-EL2 CNN Accelerator SoC.
//          Provides the standard execution framework for all test plan cases:
//          - Instantiates top-level environment (soc_env)
//          - Configurable watchdog timer (default: 500us)
//          - Dynamic wait for Scoreboard PASS detection
//          - Extensible pre_run() and post_run_check() hooks
// =============================================================================

`ifndef SOC_BASE_TEST_SV
`define SOC_BASE_TEST_SV

class soc_base_test extends uvm_test;
    `uvm_component_utils(soc_base_test)

    soc_env env;
    time    test_timeout = 500us;

    function new(string name = "soc_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_env::type_id::create("env", this);
        // Allow command-line timeout configuration: +timeout_us=<val>
        void'(uvm_config_db#(time)::get(this, "", "test_timeout", test_timeout));
    endfunction

    // Optional pre-run hook for test-specific setup (e.g. driving VIP sequences)
    virtual task pre_run();
    endtask

    // Optional post-run check hook for test-specific assertions
    virtual function void post_run_check();
    endfunction

    // Standard UVM Run Phase
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info(get_name(), "==================================================", UVM_LOW)
        `uvm_info(get_name(), $sformatf("=== STARTING TEST: %s ===", get_name()), UVM_LOW)
        `uvm_info(get_name(), "==================================================", UVM_LOW)

        // Launch any test-specific VIP sequences
        pre_run();

        // Dynamically wait for Scoreboard pass confirmation or watchdog
        fork
            begin
                wait(env.sb.pass_detected == 1'b1);
                #10us; // Allow any trailing UART stop bits or newline to flush
                `uvm_info(get_name(), $sformatf("=== [PASS] Scoreboard Confirmed PASS for %s! ===", get_name()), UVM_LOW)
            end
            begin
                #(test_timeout);
                `uvm_error(get_name(), $sformatf("=== [TIMEOUT] Watchdog timeout (%0t) reached before test completion! ===", test_timeout))
            end
        join_any
        disable fork;

        // Perform any post-run assertions
        post_run_check();

        `uvm_info(get_name(), "==================================================", UVM_LOW)
        `uvm_info(get_name(), $sformatf("=== COMPLETED TEST: %s ===", get_name()), UVM_LOW)
        `uvm_info(get_name(), "==================================================", UVM_LOW)
        phase.drop_objection(this);
    endtask

endclass : soc_base_test

`endif // SOC_BASE_TEST_SV
