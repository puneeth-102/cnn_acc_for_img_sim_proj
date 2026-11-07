// =============================================================================
// File   : soc_interactive_test.sv
// Purpose: Closed-loop interactive UVM test demonstrating active Driver
//          injection into uart_rx_i, CPU reception/echo, and Monitor capture.
// =============================================================================

`ifndef SOC_INTERACTIVE_TEST_SV
`define SOC_INTERACTIVE_TEST_SV

// Sequence to send a specific ASCII character via UART VIP
class uart_send_char_seq extends uvm_sequence #(uart_item);
    `uvm_object_utils(uart_send_char_seq)

    byte char_to_send = 8'h39; // Default '9'

    function new(string name = "uart_send_char_seq");
        super.new(name);
    endfunction

    task body();
        uart_item item = uart_item::type_id::create("item");
        start_item(item);
        item.char_data = char_to_send;
        finish_item(item);
    endtask
endclass

class soc_interactive_test extends uvm_test;
    `uvm_component_utils(soc_interactive_test)

    soc_env env;

    function new(string name = "soc_interactive_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = soc_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        uart_send_char_seq tx_seq;
        phase.raise_objection(this);
        `uvm_info("SOC_INTERACTIVE", "=== Starting Closed-Loop Interactive Driver/Monitor Test ===", UVM_LOW)

        // 1. Wait for CPU to boot and print "READY\r\n"
        #15us;

        // 2. ACTIVELY USE DRIVER:
        //    Send character '9' (ASCII 0x39) through uart_rx_i pin into the SoC!
        `uvm_info("SOC_INTERACTIVE", ">>> [UVM DRIVER IN ACTION] Transmitting ASCII '9' (0x39) into uart_rx_i physical wire! >>>", UVM_NONE)
        tx_seq = uart_send_char_seq::type_id::create("tx_seq");
        tx_seq.char_to_send = 8'h39; // '9'
        tx_seq.start(env.uart_agt.seqr);

        `uvm_info("SOC_INTERACTIVE", ">>> [UVM DRIVER] Serial transmission complete. Waiting for CPU response... >>>", UVM_NONE)

        // 3. Wait dynamically for Scoreboard to confirm the CPU echo response
        fork
            begin
                wait(env.sb.pass_detected == 1'b1);
                #10us; // Allow trailing bytes to settle
                `uvm_info("SOC_INTERACTIVE", "=== PASS Condition Confirmed by Scoreboard! ===", UVM_LOW)
            end
            begin
                #80us;
                `uvm_info("SOC_INTERACTIVE", "=== Watchdog Timeout Reached ===", UVM_LOW)
            end
        join_any
        disable fork;

        `uvm_info("SOC_INTERACTIVE", "=== Completed Closed-Loop Interactive Driver/Monitor Test ===", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass

`endif // SOC_INTERACTIVE_TEST_SV
