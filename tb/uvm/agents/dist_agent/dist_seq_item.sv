// =============================================================================
// File   : dist_seq_item.sv
// Class  : dist_seq_item
// Purpose: UVM sequence item for Distance Engine transactions and anomaly checks
// =============================================================================

`ifndef DIST_SEQ_ITEM_SV
`define DIST_SEQ_ITEM_SV

class dist_seq_item extends uvm_sequence_item;
    `uvm_object_utils(dist_seq_item)

    typedef enum { DIST_REG_WRITE, DIST_REG_READ, DIST_CALC_DONE } dist_event_e;

    dist_event_e event_type;
    bit [31:0]   addr;
    bit [31:0]   data;
    bit [31:0]   threshold;
    bit [31:0]   min_distance;
    bit          result_match; // 1 = Match/Normal, 0 = Anomaly
    time         timestamp;

    function new(string name = "dist_seq_item");
        super.new(name);
    endfunction

    virtual function string convert2string();
        case (event_type)
            DIST_CALC_DONE:
                return $sformatf("[DIST CALC @ %0t] Dist=%0d, Thresh=%0d, Result=%s",
                    timestamp, min_distance, threshold, (result_match ? "NORMAL (MATCH)" : "ANOMALY DETECTED"));
            default:
                return $sformatf("[DIST %s @ %0t] Addr=0x%08X Data=0x%08X",
                    event_type.name(), timestamp, addr, data);
        endcase
    endfunction

endclass : dist_seq_item

`endif // DIST_SEQ_ITEM_SV
