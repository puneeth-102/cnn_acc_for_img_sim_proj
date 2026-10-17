// =============================================================================
// File   : uart_monitor.sv
// Class  : uart_monitor
// Purpose: UVM passive monitor deserializing serial bits on uart_tx_o
// =============================================================================

`ifndef UART_MONITOR_SV
`define UART_MONITOR_SV

class uart_monitor extends uvm_monitor;
    `uvm_component_utils(uart_monitor)

    virtual soc_if vif;
    uvm_analysis_port #(uart_seq_item) ap;

    // Default: 170 ns per bit (BAUD_DIV = 16 at 100 MHz clock)
    real bit_period_ns = 170.0;
    string line_buffer = "";

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual soc_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("UART_MON", "Could not get virtual interface vif from config_db")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        byte rx_byte;
        uart_seq_item item;

        // Wait for reset release
        wait(vif.rst_l === 1'b1);

        forever begin
            // Wait for start bit (falling edge on uart_tx_o)
            @(negedge vif.uart_tx_o);

            // Sample center of Data Bit 0 (1.5 bit periods later)
            #(bit_period_ns * 1.5);

            // Sample 8 data bits (LSB first)
            rx_byte = 8'h0;
            for (int b = 0; b < 8; b++) begin
                rx_byte[b] = vif.uart_tx_o;
                if (b < 7) begin
                    #(bit_period_ns);
                end
            end

            // Wait for center of stop bit
            #(bit_period_ns);

            if (vif.uart_tx_o === 1'b1) begin
                // Build character item
                item = uart_seq_item::type_id::create("uart_item");
                item.char_byte    = rx_byte;
                item.timestamp    = $time;
                item.is_full_line = 1'b0;
                ap.write(item);

                // Accumulate line
                if (rx_byte == 8'h0A) begin // '\n'
                    item = uart_seq_item::type_id::create("uart_line_item");
                    item.line_string  = line_buffer;
                    item.is_full_line = 1'b1;
                    item.timestamp    = $time;
                    ap.write(item);
                    `uvm_info("UART_LOG", $sformatf("%s", line_buffer), UVM_LOW)
                    line_buffer = "";
                end else if (rx_byte != 8'h0D) begin // Ignore '\r'
                    line_buffer = {line_buffer, string'(rx_byte)};
                end
            end else begin
                `uvm_warning("UART_MON", $sformatf("Framing error at %0t (stop bit was 0)", $time))
                wait(vif.uart_tx_o === 1'b1);
            end

            // Complete stop bit
            #(bit_period_ns * 0.5);
        end
    endtask

endclass : uart_monitor

`endif // UART_MONITOR_SV
