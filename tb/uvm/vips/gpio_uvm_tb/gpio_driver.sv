class gpio_driver extends uvm_driver #(gpio_item);
    virtual gpio_if vif;
    `uvm_component_utils(gpio_driver)

    function new(string n, uvm_component p);
        super.new(n, p);
    endfunction

    task run_phase(uvm_phase phase);
        // Wait for reset release
        wait(vif.rst_l === 1'b1);
        forever begin
            seq_item_port.get_next_item(req);
            @(posedge vif.clk);
            vif.gpio_i <= req.gpio_i;
            seq_item_port.item_done();
        end
    endtask
endclass
