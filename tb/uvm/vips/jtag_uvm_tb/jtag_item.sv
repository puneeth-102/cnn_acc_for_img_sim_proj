class jtag_item extends uvm_sequence_item;

  rand bit jtag_tck;
  rand bit jtag_trst_n;
  rand bit jtag_tms;
  rand bit jtag_tdi;
  bit jtag_tdo;
  bit jtag_tdoEn;

  `uvm_object_utils(jtag_item)

  function new(string name="jtag_item"); super.new(name); endfunction
endclass
