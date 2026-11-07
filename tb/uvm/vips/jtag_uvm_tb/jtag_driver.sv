class jtag_driver extends uvm_driver #(jtag_item);
    virtual jtag_if vif;
    `uvm_component_utils(jtag_driver)

    function new(string n, uvm_component p);
        super.new(n, p);
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            vif.jtag_trst_n <= req.jtag_trst_n;
            vif.jtag_tms    <= req.jtag_tms;
            vif.jtag_tdi    <= req.jtag_tdi;
            vif.jtag_tck    <= req.jtag_tck;
            @(posedge vif.clk);
            seq_item_port.item_done();
        end
    endtask
endclass
