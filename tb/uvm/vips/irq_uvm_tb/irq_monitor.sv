class irq_monitor extends uvm_monitor;
    virtual irq_if vif;
    uvm_analysis_port #(irq_item) ap;
    `uvm_component_utils(irq_monitor)

    function new(string n, uvm_component p);
        super.new(n, p);
        ap = new("ap", this);
    endfunction

    task run_phase(uvm_phase phase);
        logic prev_uart  = 1'b0;
        logic prev_dma   = 1'b0;
        logic prev_cnn   = 1'b0;
        logic prev_dist  = 1'b0;
        logic prev_timer = 1'b0;
        logic prev_gpio  = 1'b0;

        wait(vif.rst_l === 1'b1);

        forever begin
            @(posedge vif.clk);
            if (vif.uart_irq_o  !== prev_uart  ||
                vif.dma_irq_o   !== prev_dma   ||
                vif.cnn_irq_o   !== prev_cnn   ||
                vif.dist_irq_o  !== prev_dist  ||
                vif.timer_irq_o !== prev_timer ||
                vif.gpio_irq_o  !== prev_gpio) begin

                irq_item item = irq_item::type_id::create("item");
                item.uart_irq_o  = vif.uart_irq_o;
                item.dma_irq_o   = vif.dma_irq_o;
                item.cnn_irq_o   = vif.cnn_irq_o;
                item.dist_irq_o  = vif.dist_irq_o;
                item.timer_irq_o = vif.timer_irq_o;
                item.gpio_irq_o  = vif.gpio_irq_o;

                prev_uart  = vif.uart_irq_o;
                prev_dma   = vif.dma_irq_o;
                prev_cnn   = vif.cnn_irq_o;
                prev_dist  = vif.dist_irq_o;
                prev_timer = vif.timer_irq_o;
                prev_gpio  = vif.gpio_irq_o;

                ap.write(item);
            end
        end
    endtask
endclass
