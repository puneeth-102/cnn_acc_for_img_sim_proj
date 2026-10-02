`timescale 1ns/1ps

module embedding_memory #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 16
)(
    input  logic clk,
    input  logic rst,

    // Store one embedding value at a time
    input  logic                        write_en,
    input  logic [$clog2(DEPTH)-1:0]    write_addr,
    input  logic signed [DATA_WIDTH-1:0] write_data,

    // Complete stored reference embedding
    output logic signed [DATA_WIDTH-1:0]
        reference_embedding [0:DEPTH-1]
);

    // --------------------------------------------------
    // Memory
    // --------------------------------------------------

    logic signed [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    integer i;

    // --------------------------------------------------
    // Write
    // --------------------------------------------------

    always_ff @(posedge clk) begin

        if (rst) begin

            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= '0;

        end

        else begin

            if (write_en)
                mem[write_addr] <= write_data;

        end

    end

    // --------------------------------------------------
    // Make complete embedding available
    // --------------------------------------------------

    always_comb begin

        for (i = 0; i < DEPTH; i = i + 1)
            reference_embedding[i] = mem[i];

    end

endmodule