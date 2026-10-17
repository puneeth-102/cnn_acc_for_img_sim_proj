// =============================================================================
// File   : gpio_seq_item.sv
// Class  : gpio_seq_item
// Purpose: UVM sequence item capturing GPIO pin states and interrupt flags
// =============================================================================

`ifndef GPIO_SEQ_ITEM_SV
`define GPIO_SEQ_ITEM_SV

class gpio_seq_item extends uvm_sequence_item;
    `uvm_object_utils(gpio_seq_item)

    bit [31:0] gpio_out;
    bit [5:0]  irq_vector; // {dma, gpio, timer, dist, cnn, uart}
    time       timestamp;

    function new(string name = "gpio_seq_item");
        super.new(name);
    endfunction

    virtual function string convert2string();
        return $sformatf("[GPIO @ %0t] Out=0x%08X, IRQs=0b%06b (dma=%0d, dist=%0d, cnn=%0d)",
            timestamp, gpio_out, irq_vector, irq_vector[5], irq_vector[2], irq_vector[1]);
    endfunction

endclass : gpio_seq_item

`endif // GPIO_SEQ_ITEM_SV
