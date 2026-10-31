class clk_rst_item extends uvm_sequence_item;

  rand bit rst_l;
  rand bit dbg_rst_l;

  `uvm_object_utils(clk_rst_item)

  function new(string name="clk_rst_item"); super.new(name); endfunction
endclass
