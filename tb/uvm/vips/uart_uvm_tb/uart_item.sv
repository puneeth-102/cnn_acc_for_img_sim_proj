class uart_item extends uvm_sequence_item;

  rand bit rst_l;
  rand bit uart_rx_i;
  bit uart_tx_o;
  bit uart_irq_o;

  `uvm_object_utils(uart_item)

  function new(string name="uart_item"); super.new(name); endfunction
endclass
