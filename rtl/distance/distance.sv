`timescale 1ns/1ps

module distance #(
    parameter DATA_W = 32,
    parameter EMB_W  = 16,
    parameter DIST_W = 40
)(
    input  logic signed [DATA_W-1:0] embedding_a [0:EMB_W-1],
    input  logic signed [DATA_W-1:0] embedding_b [0:EMB_W-1],

    output logic signed [DIST_W-1:0] distance
);

    integer i;
    logic signed [DATA_W:0] diff;

    always_comb begin

        distance = '0;

        for (i = 0; i < EMB_W; i = i + 1) begin

            diff = embedding_a[i] - embedding_b[i];

            if (diff < 0)
                distance = distance + (-diff);
            else
                distance = distance + diff;

        end

    end

endmodule
