// =============================================================================
// File   : dma_seq_item.sv
// Class  : dma_seq_item
// Purpose: UVM sequence item for DMA block transfer transactions
// =============================================================================

`ifndef DMA_SEQ_ITEM_SV
`define DMA_SEQ_ITEM_SV

class dma_seq_item extends uvm_sequence_item;
    `uvm_object_utils(dma_seq_item)

    bit [31:0] src_addr;
    bit [31:0] dst_addr;
    bit [31:0] length_bytes;
    bit        transfer_done;
    time       timestamp;

    function new(string name = "dma_seq_item");
        super.new(name);
    endfunction

    virtual function string convert2string();
        return $sformatf("[DMA TRANSFER @ %0t] Src=0x%08X -> Dst=0x%08X (Len=%0d bytes) Done=%0d",
            timestamp, src_addr, dst_addr, length_bytes, transfer_done);
    endfunction

endclass : dma_seq_item

`endif // DMA_SEQ_ITEM_SV
