`timescale 1ns/1ps

module embedding_memory #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 16
)(
    input logic clk,
    input logic rst,

    input logic                     write_en,
    input logic [$clog2(DEPTH)-1:0] write_addr,

    input logic signed [DATA_WIDTH-1:0] write_data,

    output wire signed [DATA_WIDTH-1:0]
        reference_embedding [0:DEPTH-1]
);

    // --------------------------------------------------
    // Embedding memory
    // --------------------------------------------------

    logic signed [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    integer i;

    // --------------------------------------------------
    // Write reference embedding
    // --------------------------------------------------

    always_ff @(posedge clk) begin

        if (rst) begin

            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= '0;

        end

        else if (write_en) begin

            mem[write_addr] <= write_data;

        end

    end

    // --------------------------------------------------
    // Read entire stored embedding
    // --------------------------------------------------

    genvar g;

    generate

        for (g = 0; g < DEPTH; g = g + 1) begin

            assign reference_embedding[g] = mem[g];

        end

    endgenerate

endmodule