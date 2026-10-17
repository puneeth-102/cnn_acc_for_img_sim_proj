// =============================================================================
// File   : gpio_monitor.sv
// Class  : gpio_monitor
// Purpose: UVM passive monitor tracking GPIO state transitions and IRQ assertions
// =============================================================================

`ifndef GPIO_MONITOR_SV
`define GPIO_MONITOR_SV

class gpio_monitor extends uvm_monitor;
    `uvm_component_utils(gpio_monitor)

    virtual soc_if vif;
    uvm_analysis_port #(gpio_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual soc_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("GPIO_MON", "Could not get virtual interface vif from config_db")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        logic [31:0] prev_gpio;
        logic [5:0]  prev_irqs;
        logic [5:0]  curr_irqs;
        gpio_seq_item item;

        // Wait for reset release
        wait(vif.rst_l === 1'b1);
        prev_gpio = vif.gpio_o;
        prev_irqs = {vif.dma_irq_o, vif.gpio_irq_o, vif.timer_irq_o, vif.dist_irq_o, vif.cnn_irq_o, vif.uart_irq_o};

        forever begin
            @(posedge vif.clk);

            curr_irqs = {vif.dma_irq_o, vif.gpio_irq_o, vif.timer_irq_o, vif.dist_irq_o, vif.cnn_irq_o, vif.uart_irq_o};

            if (vif.gpio_o !== prev_gpio || curr_irqs !== prev_irqs) begin
                item = gpio_seq_item::type_id::create("gpio_item");
                item.gpio_out   = vif.gpio_o;
                item.irq_vector = curr_irqs;
                item.timestamp  = $time;
                ap.write(item);

                `uvm_info("GPIO_MON", item.convert2string(), UVM_HIGH)
                prev_gpio = vif.gpio_o;
                prev_irqs = curr_irqs;
            end
        end
    endtask

endclass : gpio_monitor

`endif // GPIO_MONITOR_SV
