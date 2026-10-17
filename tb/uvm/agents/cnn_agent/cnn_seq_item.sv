// =============================================================================
// File   : cnn_seq_item.sv
// Class  : cnn_seq_item
// Purpose: UVM sequence item for CNN Accelerator transactions and feature vectors
// =============================================================================

`ifndef CNN_SEQ_ITEM_SV
`define CNN_SEQ_ITEM_SV

class cnn_seq_item extends uvm_sequence_item;
    `uvm_object_utils(cnn_seq_item)

    typedef enum { CNN_REG_WRITE, CNN_REG_READ, CNN_EMBEDDING_READY } cnn_event_e;

    cnn_event_e  event_type;
    bit [31:0]   addr;
    bit [31:0]   data;
    bit signed [31:0] embedding[16];
    time         timestamp;

    function new(string name = "cnn_seq_item");
        super.new(name);
    endfunction

    virtual function string convert2string();
        case (event_type)
            CNN_REG_WRITE:
                return $sformatf("[CNN WRITE @ %0t] Addr=0x%08X Data=0x%08X", timestamp, addr, data);
            CNN_REG_READ:
                return $sformatf("[CNN READ  @ %0t] Addr=0x%08X Data=0x%08X", timestamp, addr, data);
            CNN_EMBEDDING_READY:
                return $sformatf("[CNN EMBEDDING @ %0t] Emb[0..3]={0x%08X, 0x%08X, 0x%08X, 0x%08X}",
                    timestamp, embedding[0], embedding[1], embedding[2], embedding[3]);
            default:
                return $sformatf("[CNN @ %0t] Event=%s", timestamp, event_type.name());
        endcase
    endfunction

endclass : cnn_seq_item

`endif // CNN_SEQ_ITEM_SV
