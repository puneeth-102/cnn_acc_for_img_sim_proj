class uart_monitor extends uvm_monitor;
    virtual uart_if vif;
    uvm_analysis_port #(uart_item) ap;
    `uvm_component_utils(uart_monitor)

    function new(string n, uvm_component p);
        super.new(n, p);
        ap = new("ap", this);
    endfunction

    task run_phase(uvm_phase phase);
        byte rx_byte;
        real BIT_PERIOD_NS = 170.0; // Baud Divisor 16 at 100MHz = 170 ns per bit

        // Wait for reset deassertion
        wait(vif.rst_l === 1'b1);

        forever begin
            // Wait for start bit (falling edge on uart_tx_o)
            @(negedge vif.uart_tx_o);

            // Wait 1.5 bit periods to sample at center of data bit 0
            #(BIT_PERIOD_NS * 1.5);

            rx_byte = 8'h0;
            for (int b = 0; b < 8; b++) begin
                rx_byte[b] = vif.uart_tx_o;
                if (b < 7) #(BIT_PERIOD_NS);
            end

            // Wait 1 bit period to sample center of STOP bit
            #(BIT_PERIOD_NS);

            if (vif.uart_tx_o === 1'b1) begin
                uart_item item = uart_item::type_id::create("item");
                item.uart_tx_o = 1'b1;
                item.char_data = rx_byte;
                ap.write(item);
            end
        end
    endtask
endclass
