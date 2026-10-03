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

    // --------------------------------------------------
    // Write
    // --------------------------------------------------

    always_ff @(posedge clk) begin

        if (rst) begin

            for (int wr_i = 0; wr_i < DEPTH; wr_i = wr_i + 1)
                mem[wr_i] <= '0;

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

        for (int rd_i = 0; rd_i < DEPTH; rd_i = rd_i + 1)
            reference_embedding[rd_i] = mem[rd_i];

    end

endmodule