`timescale 1ns/1ps

module similarity_checker #(
    parameter EMBEDDING_SIZE = 16,
    parameter DATA_WIDTH     = 32,
    parameter DIST_WIDTH     = 40
)(
    input  logic clk,
    input  logic rst,
    input  logic start,

    input  logic signed [DATA_WIDTH-1:0] query_embedding [0:EMBEDDING_SIZE-1],
    input  logic signed [DATA_WIDTH-1:0] reference_embedding [0:EMBEDDING_SIZE-1],

    input  logic [DIST_WIDTH-1:0]        threshold,

    output logic [DIST_WIDTH-1:0]        distance,
    output logic                         similar,
    output logic                         done
);

    logic signed [DIST_WIDTH-1:0] calc_distance;
    logic                         calc_similar;

    distance #(
        .DATA_W(DATA_WIDTH),
        .EMB_W(EMBEDDING_SIZE),
        .DIST_W(DIST_WIDTH)
    ) u_dist (
        .embedding_a(query_embedding),
        .embedding_b(reference_embedding),
        .distance(calc_distance)
    );

    threshold #(
        .DIST_W(DIST_WIDTH)
    ) u_thresh (
        .distance(calc_distance),
        .threshold_value(threshold),
        .similar(calc_similar)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            distance <= '0;
            similar  <= 1'b0;
            done     <= 1'b0;
        end else begin
            done <= 1'b0;
            if (start) begin
                distance <= calc_distance;
                similar  <= calc_similar;
                done     <= 1'b1;
            end
        end
    end

endmodule