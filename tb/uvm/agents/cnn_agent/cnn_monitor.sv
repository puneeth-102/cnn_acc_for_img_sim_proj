// =============================================================================
// File   : cnn_monitor.sv
// Class  : cnn_monitor
// Purpose: UVM passive monitor snooping AXI transactions to CNN Accelerator (M05)
// =============================================================================

`ifndef CNN_MONITOR_SV
`define CNN_MONITOR_SV

class cnn_monitor extends uvm_monitor;
    `uvm_component_utils(cnn_monitor)

    virtual soc_if vif;
    uvm_analysis_port #(cnn_seq_item) ap;

    bit signed [31:0] captured_embedding[16];
    bit [15:0]        embed_captured_mask;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
        embed_captured_mask = 16'h0;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual soc_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("CNN_MON", "Could not get virtual interface vif from config_db")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        // Fork separate processes for write channel and read channel snooping
        fork
            snoop_writes();
            snoop_reads();
        join
    endtask

    virtual task snoop_writes();
        bit [31:0] write_addr;
        cnn_seq_item item;

        forever begin
            @(posedge vif.clk);
            if (vif.rst_l === 1'b1) begin
                if (vif.cnn_awvalid && vif.cnn_awready) begin
                    write_addr = vif.cnn_awaddr;
                end
                if (vif.cnn_wvalid && vif.cnn_wready) begin
                    item = cnn_seq_item::type_id::create("cnn_write_item");
                    item.event_type = cnn_seq_item::CNN_REG_WRITE;
                    item.addr       = write_addr;
                    item.data       = vif.cnn_wdata;
                    item.timestamp  = $time;
                    ap.write(item);
                    `uvm_info("CNN_MON", item.convert2string(), UVM_HIGH)
                end
            end
        end
    endtask

    virtual task snoop_reads();
        bit [31:0]   read_addr;
        cnn_seq_item item;
        cnn_seq_item emb_item;
        int          idx;

        forever begin
            @(posedge vif.clk);
            if (vif.rst_l === 1'b1) begin
                if (vif.cnn_arvalid && vif.cnn_arready) begin
                    read_addr = vif.cnn_araddr;
                end
                if (vif.cnn_rvalid && vif.cnn_rready) begin
                    item = cnn_seq_item::type_id::create("cnn_read_item");
                    item.event_type = cnn_seq_item::CNN_REG_READ;
                    item.addr       = read_addr;
                    item.data       = vif.cnn_rdata;
                    item.timestamp  = $time;
                    ap.write(item);

                    // Check if reading embedding registers: 0x20003020 .. 0x2000305C
                    if (read_addr >= 32'h20003020 && read_addr <= 32'h2000305C) begin
                        idx = (read_addr - 32'h20003020) >> 2;
                        if (idx >= 0 && idx < 16) begin
                            captured_embedding[idx] = vif.cnn_rdata;
                            embed_captured_mask[idx] = 1'b1;

                            // When first 4 elements captured, emit an embedding event
                            if (embed_captured_mask[3:0] == 4'b1111) begin
                                emb_item = cnn_seq_item::type_id::create("cnn_emb_item");
                                emb_item.event_type = cnn_seq_item::CNN_EMBEDDING_READY;
                                emb_item.embedding  = captured_embedding;
                                emb_item.timestamp  = $time;
                                ap.write(emb_item);
                                `uvm_info("CNN_MON", emb_item.convert2string(), UVM_MEDIUM)
                                embed_captured_mask = 16'h0;
                            end
                        end
                    end
                end
            end
        end
    endtask

endclass : cnn_monitor

`endif // CNN_MONITOR_SV
