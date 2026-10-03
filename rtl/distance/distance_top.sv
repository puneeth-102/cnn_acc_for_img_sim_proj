`timescale 1ns/1ps

module distance_top #(
    parameter DATA_W = 32,
    parameter EMB_W  = 16,
    parameter DIST_W = 40
)(
    input  logic signed [DATA_W-1:0] embedding_a [0:EMB_W-1],
    input  logic signed [DATA_W-1:0] embedding_b [0:EMB_W-1],

    input  logic signed [DIST_W-1:0] threshold_value,

    output logic signed [DIST_W-1:0] distance,
    output logic                    similar
);

    // Distance calculation
    distance #(
        .DATA_W(DATA_W),
        .EMB_W(EMB_W),
        .DIST_W(DIST_W)
    ) u_distance (
        .embedding_a(embedding_a),
        .embedding_b(embedding_b),
        .distance(distance)
    );

    // Threshold comparison
    threshold #(
        .DIST_W(DIST_W)
    ) u_threshold (
        .distance(distance),
        .threshold_value(threshold_value),
        .similar(similar)
    );

endmodule