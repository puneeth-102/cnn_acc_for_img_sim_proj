`timescale 1ns/1ps

module tb_cnn_similarity_top;

    // ==================================================
    // PARAMETERS
    // ==================================================

    parameter IMAGE_SIZE  = 16;
    parameter NUM_FILTERS = 4;
    parameter DATA_WIDTH  = 32;
    parameter FEATURE_W   = 8;
    parameter EMBEDDING_W = 32;


    // ==================================================
    // CLOCK / RESET
    // ==================================================

    logic clk;
    logic rst;


    // ==================================================
    // CONTROL
    // ==================================================

    logic store_ref_start;
    logic query_start;


    // ==================================================
    // IMAGE INPUTS
    // ==================================================

    logic signed [7:0] image [0:255];


    // ==================================================
    // CNN WEIGHTS
    // ==================================================

    logic signed [7:0] conv_weights [0:35];

    logic signed [FEATURE_W-1:0]
        fc_weights [0:15][0:195];

    logic signed [EMBEDDING_W-1:0]
        fc_bias [0:15];


    // ==================================================
    // THRESHOLD
    // ==================================================

    logic [39:0] threshold;


    // ==================================================
    // OUTPUTS
    // ==================================================

    logic [39:0] distance;

    logic similar;

    logic busy;
    logic done;


    integer i;
    integer j;


    // ==================================================
    // DUT
    // ==================================================

    cnn_similarity_top #(
        .IMAGE_SIZE  (IMAGE_SIZE),
        .NUM_FILTERS (NUM_FILTERS),
        .DATA_WIDTH  (DATA_WIDTH),
        .FEATURE_W   (FEATURE_W),
        .EMBEDDING_W (EMBEDDING_W)
    ) dut (

        .clk              (clk),
        .rst              (rst),

        .store_ref_start  (store_ref_start),
        .query_start      (query_start),

        .image            (image),

        .conv_weights     (conv_weights),
        .fc_weights       (fc_weights),
        .fc_bias          (fc_bias),

        .threshold        (threshold),

        .distance         (distance),
        .similar          (similar),

        .busy             (busy),
        .done             (done)
    );


    // ==================================================
    // CLOCK
    // ==================================================

    initial begin

        clk = 1'b0;

        forever #5 clk = ~clk;

    end


    // ==================================================
    // INITIALIZE CNN WEIGHTS
    // ==================================================

    initial begin

        // ----------------------------------------------
        // Convolution weights
        // ----------------------------------------------

        for (i = 0; i < 36; i = i + 1)
            conv_weights[i] = 8'sd1;


        // ----------------------------------------------
        // FC weights
        // ----------------------------------------------

        for (j = 0; j < 16; j = j + 1) begin

            for (i = 0; i < 196; i = i + 1) begin

                fc_weights[j][i] = 8'sd1;

            end

        end


        // ----------------------------------------------
        // FC bias
        // ----------------------------------------------

        for (j = 0; j < 16; j = j + 1)
            fc_bias[j] = 32'sd0;

    end


    // ==================================================
    // MAIN TEST
    // ==================================================

    initial begin

        // ----------------------------------------------
        // Initial values
        // ----------------------------------------------

        rst             = 1'b1;

        store_ref_start = 1'b0;
        query_start     = 1'b0;

        threshold       = 40'd100;

        for (i = 0; i < 256; i = i + 1)
            image[i] = 8'sd1;


        // ----------------------------------------------
        // RESET
        // ----------------------------------------------

        #20;

        rst = 1'b0;

        #20;


        // =================================================
        // STEP 1
        // STORE REFERENCE IMAGE
        // =================================================

        $display("");
        $display("========================================");
        $display("STEP 1: STORE REFERENCE IMAGE");
        $display("========================================");

        $display("Starting reference image...");

@(negedge clk);
store_ref_start = 1'b1;

$display("store_ref_start = 1 at time %0t", $time);

@(negedge clk);
store_ref_start = 1'b0;

$display("store_ref_start = 0 at time %0t", $time);

wait(done == 1'b1);

$display("Reference processing DONE at time %0t", $time);

        $display("Reference embedding stored.");
        $display("CNN reference processing completed.");


        // ----------------------------------------------
        // Give one cycle
        // ----------------------------------------------

        @(negedge clk);


        // =================================================
        // STEP 2
        // QUERY IMAGE
        // =================================================

        $display("");
        $display("========================================");
        $display("STEP 2: PROCESS QUERY IMAGE");
        $display("========================================");

        // Same image for first test
        // Therefore expected distance should be 0

        for (i = 0; i < 256; i = i + 1)
            image[i] = 8'sd1;


        @(negedge clk);

        query_start = 1'b1;

        @(negedge clk);

        query_start = 1'b0;


        // ----------------------------------------------
        // Wait for similarity result
        // ----------------------------------------------

        wait(done == 1'b1);

        #1;

        $display("");
        $display("========================================");
        $display("SIMILARITY RESULT");
        $display("========================================");

        $display("Distance = %0d", distance);
        $display("Similar  = %0d", similar);

        $display("========================================");


        // =================================================
        // FINISH
        // =================================================

        #50;

        $display("");
        $display("CNN SIMILARITY TOP TEST COMPLETED");

        $finish;

    end

endmodule