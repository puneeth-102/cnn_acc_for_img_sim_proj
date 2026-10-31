class gpio_item extends uvm_sequence_item;

  rand bit rst_l;
  rand bit [31:0] gpio_i;
  bit [31:0] gpio_o;
  bit [31:0] gpio_dir_o;
  bit gpio_irq_o;

  `uvm_object_utils(gpio_item)

  function new(string name="gpio_item"); super.new(name); endfunction
endclass
