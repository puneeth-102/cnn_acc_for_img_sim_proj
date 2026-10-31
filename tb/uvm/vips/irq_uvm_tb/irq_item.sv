class irq_item extends uvm_sequence_item;

  rand bit rst_l;
  bit uart_irq_o;
  bit dma_irq_o;
  bit cnn_irq_o;
  bit dist_irq_o;
  bit timer_irq_o;
  bit gpio_irq_o;
  rand bit timer_int;
  rand bit soft_int;

  `uvm_object_utils(irq_item)

  function new(string name="irq_item"); super.new(name); endfunction
endclass
