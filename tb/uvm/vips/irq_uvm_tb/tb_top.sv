module tb_top;
import uvm_pkg::*; import irq_pkg::*;
irq_if vif();
initial run_test("irq_test");
endmodule
