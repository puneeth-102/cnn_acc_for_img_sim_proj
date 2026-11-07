class clk_rst_monitor extends uvm_monitor;
    virtual clk_rst_if vif;
    uvm_analysis_port #(clk_rst_item) ap;
    `uvm_component_utils(clk_rst_monitor)

    function new(string n, uvm_component p);
        super.new(n, p);
        ap = new("ap", this);
    endfunction

    task run_phase(uvm_phase phase);
        logic prev_rst_l     = 1'b0;
        logic prev_dbg_rst_l = 1'b0;

        forever begin
            @(posedge vif.clk);
            if (vif.rst_l !== prev_rst_l || vif.dbg_rst_l !== prev_dbg_rst_l) begin
                clk_rst_item item = clk_rst_item::type_id::create("item");
                item.rst_l     = vif.rst_l;
                item.dbg_rst_l = vif.dbg_rst_l;
                prev_rst_l     = vif.rst_l;
                prev_dbg_rst_l = vif.dbg_rst_l;
                ap.write(item);
            end
        end
    endtask
endclass
