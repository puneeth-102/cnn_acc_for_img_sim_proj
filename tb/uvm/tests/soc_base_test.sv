// =============================================================================
// File   : soc_base_test.sv
// Purpose: Base UVM test for VeeR-EL2 CNN Accelerator SoC.
// =============================================================================

`ifndef SOC_BASE_TEST_SV
`define SOC_BASE_TEST_SV

class soc_base_test extends uvm_test;
    `uvm_component_utils(soc_base_test)

    soc_env env;

    function new(string name = "soc_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("SOC_TEST", "=== Starting VeeR-EL2 SoC UVM Base Test ===", UVM_LOW)

        // Wait for execution or timeout
        #50us;

        `uvm_info("SOC_TEST", "=== Completed VeeR-EL2 SoC UVM Base Test ===", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass

`endif // SOC_BASE_TEST_SV
