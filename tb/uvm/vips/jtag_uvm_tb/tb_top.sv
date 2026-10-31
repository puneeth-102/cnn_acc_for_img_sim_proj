module tb_top;
import uvm_pkg::*; import jtag_pkg::*;
jtag_if vif();
initial run_test("jtag_test");
endmodule
