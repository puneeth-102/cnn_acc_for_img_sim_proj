class gpio_monitor extends uvm_monitor;
    virtual gpio_if vif;
    uvm_analysis_port #(gpio_item) ap;
    `uvm_component_utils(gpio_monitor)

    function new(string n, uvm_component p);
        super.new(n, p);
        ap = new("ap", this);
    endfunction

    task run_phase(uvm_phase phase);
        logic [31:0] prev_gpio = 32'h0;
        wait(vif.rst_l === 1'b1);

        forever begin
            @(posedge vif.clk);
            if (vif.gpio_o !== prev_gpio) begin
                gpio_item item = gpio_item::type_id::create("item");
                item.gpio_o     = vif.gpio_o;
                item.gpio_dir_o = vif.gpio_dir_o;
                item.gpio_irq_o = vif.gpio_irq_o;
                prev_gpio = vif.gpio_o;
                ap.write(item);
            end
        end
    endtask
endclass
