class uart_driver extends uvm_driver #(uart_item);
    virtual uart_if vif;
    real BIT_PERIOD_NS = 160.0; // Divisor 16 at 100 MHz (16 clocks * 10ns = 160ns)

    `uvm_component_utils(uart_driver)

    function new(string n, uvm_component p);
        super.new(n, p);
    endfunction

    task run_phase(uvm_phase phase);
        vif.uart_rx_i <= 1'b1; // Idle high
        wait(vif.rst_l === 1'b1);

        forever begin
            seq_item_port.get_next_item(req);

            // Transmit start bit (LOW)
            vif.uart_rx_i <= 1'b0;
            #(BIT_PERIOD_NS);

            // Transmit 8 data bits (LSB first)
            for (int b = 0; b < 8; b++) begin
                vif.uart_rx_i <= req.char_data[b];
                #(BIT_PERIOD_NS);
            end

            // Transmit stop bit (HIGH)
            vif.uart_rx_i <= 1'b1;
            #(BIT_PERIOD_NS);

            seq_item_port.item_done();
        end
    endtask
endclass
