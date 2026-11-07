class jtag_monitor extends uvm_monitor;
    virtual jtag_if vif;
    uvm_analysis_port #(jtag_item) ap;
    `uvm_component_utils(jtag_monitor)

    function new(string n, uvm_component p);
        super.new(n, p);
        ap = new("ap", this);
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.clk);
            if (vif.jtag_tdoEn) begin
                jtag_item item = jtag_item::type_id::create("item");
                item.jtag_trst_n = vif.jtag_trst_n;
                item.jtag_tms    = vif.jtag_tms;
                item.jtag_tdi    = vif.jtag_tdi;
                item.jtag_tdo    = vif.jtag_tdo;
                item.jtag_tdoEn  = vif.jtag_tdoEn;
                ap.write(item);
            end
        end
    endtask
endclass
