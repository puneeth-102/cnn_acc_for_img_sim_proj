// =============================================================================
// File   : dist_monitor.sv
// Class  : dist_monitor
// Purpose: UVM passive monitor snooping AXI transactions to Distance Engine (M06)
// =============================================================================

`ifndef DIST_MONITOR_SV
`define DIST_MONITOR_SV

class dist_monitor extends uvm_monitor;
    `uvm_component_utils(dist_monitor)

    virtual soc_if vif;
    uvm_analysis_port #(dist_seq_item) ap;

    bit [31:0] current_threshold;
    bit [31:0] captured_dist;
    bit        captured_result;
    bit        dist_valid;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
        current_threshold = 50;
        dist_valid = 1'b0;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual soc_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("DIST_MON", "Could not get virtual interface vif from config_db")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        fork
            snoop_writes();
            snoop_reads();
        join
    endtask

    virtual task snoop_writes();
        bit [31:0] write_addr;
        dist_seq_item item;

        forever begin
            @(posedge vif.clk);
            if (vif.rst_l === 1'b1) begin
                if (vif.dist_awvalid && vif.dist_awready) begin
                    write_addr = vif.dist_awaddr;
                end
                if (vif.dist_wvalid && vif.dist_wready) begin
                    item = dist_seq_item::type_id::create("dist_write_item");
                    item.event_type = dist_seq_item::DIST_REG_WRITE;
                    item.addr       = write_addr;
                    item.data       = vif.dist_wdata;
                    item.timestamp  = $time;
                    ap.write(item);

                    if (write_addr == 32'h20004018) begin
                        current_threshold = vif.dist_wdata;
                    end
                end
            end
        end
    endtask

    virtual task snoop_reads();
        bit [31:0]    read_addr;
        dist_seq_item item;
        dist_seq_item calc_item;

        forever begin
            @(posedge vif.clk);
            if (vif.rst_l === 1'b1) begin
                if (vif.dist_arvalid && vif.dist_arready) begin
                    read_addr = vif.dist_araddr;
                end
                if (vif.dist_rvalid && vif.dist_rready) begin
                    item = dist_seq_item::type_id::create("dist_read_item");
                    item.event_type = dist_seq_item::DIST_REG_READ;
                    item.addr       = read_addr;
                    item.data       = vif.dist_rdata;
                    item.timestamp  = $time;
                    ap.write(item);

                    // Track MIN_DISTANCE (0x20004020) and RESULT (0x2000401C)
                    if (read_addr == 32'h20004020) begin
                        captured_dist = vif.dist_rdata;
                        dist_valid = 1'b1;
                    end else if (read_addr == 32'h2000401C && dist_valid) begin
                        captured_result = vif.dist_rdata[0];
                        dist_valid = 1'b0;

                        // Emit calculation complete item
                        calc_item = dist_seq_item::type_id::create("dist_calc_item");
                        calc_item.event_type   = dist_seq_item::DIST_CALC_DONE;
                        calc_item.threshold    = current_threshold;
                        calc_item.min_distance = captured_dist;
                        calc_item.result_match = captured_result;
                        calc_item.timestamp    = $time;
                        ap.write(calc_item);
                        `uvm_info("DIST_MON", calc_item.convert2string(), UVM_MEDIUM)
                    end
                end
            end
        end
    endtask

endclass : dist_monitor

`endif // DIST_MONITOR_SV
