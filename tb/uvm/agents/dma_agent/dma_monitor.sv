// =============================================================================
// File   : dma_monitor.sv
// Class  : dma_monitor
// Purpose: UVM passive monitor tracking DMA transfers and interrupts
// =============================================================================

`ifndef DMA_MONITOR_SV
`define DMA_MONITOR_SV

class dma_monitor extends uvm_monitor;
    `uvm_component_utils(dma_monitor)

    virtual soc_if vif;
    uvm_analysis_port #(dma_seq_item) ap;

    bit [31:0] cur_src;
    bit [31:0] cur_dst;
    bit [31:0] cur_len;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
        cur_src = 32'h0;
        cur_dst = 32'h0;
        cur_len = 32'd0;
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual soc_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("DMA_MON", "Could not get virtual interface vif from config_db")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        bit [31:0] write_addr;
        bit prev_dma_irq = 1'b0;
        bit dma_done_emitted = 1'b0;
        dma_seq_item item;

        forever begin
            @(posedge vif.clk);
            if (vif.rst_l === 1'b1) begin
                // Snoop DMA CSR writes
                if (vif.dma_awvalid && vif.dma_awready) begin
                    write_addr = vif.dma_awaddr;
                end
                if (vif.dma_wvalid && vif.dma_wready) begin
                    case (write_addr)
                        32'h20005008: cur_src = vif.dma_wdata;
                        32'h2000500C: cur_dst = vif.dma_wdata;
                        32'h20005010: cur_len = vif.dma_wdata;
                        default: ;
                    endcase
                end

                // Detect DMA completion: status poll returning DONE or dma_irq_o rising edge
                if ((vif.dma_rvalid && vif.dma_rready && vif.dma_rdata[1]) || (vif.dma_irq_o && !prev_dma_irq)) begin
                    if (!dma_done_emitted && cur_len > 0) begin
                        item = dma_seq_item::type_id::create("dma_item");
                        item.src_addr      = cur_src;
                        item.dst_addr      = cur_dst;
                        item.length_bytes  = cur_len;
                        item.transfer_done = 1'b1;
                        item.timestamp     = $time;
                        ap.write(item);
                        `uvm_info("DMA_MON", item.convert2string(), UVM_MEDIUM)
                        dma_done_emitted = 1'b1;
                    end
                end

                prev_dma_irq = vif.dma_irq_o;
            end
        end
    endtask

endclass : dma_monitor

`endif // DMA_MONITOR_SV
