// =============================================================================
// File   : uart_seq_item.sv
// Class  : uart_seq_item
// Purpose: UVM sequence item for UART serial transactions
// =============================================================================

`ifndef UART_SEQ_ITEM_SV
`define UART_SEQ_ITEM_SV

class uart_seq_item extends uvm_sequence_item;
    `uvm_object_utils(uart_seq_item)

    byte         char_byte;
    string       line_string;
    bit          is_full_line;
    time         timestamp;

    function new(string name = "uart_seq_item");
        super.new(name);
    endfunction

    virtual function string convert2string();
        if (is_full_line) begin
            return $sformatf("[UART LINE @ %0t] %s", timestamp, line_string);
        end else begin
            return $sformatf("[UART CHAR @ %0t] '%c' (0x%02X)", timestamp, char_byte, char_byte);
        end
    endfunction

endclass : uart_seq_item

`endif // UART_SEQ_ITEM_SV
