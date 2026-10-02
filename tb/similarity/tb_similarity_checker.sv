`timescale 1ns/1ps

module tb_similarity_checker;

    parameter EMBEDDING_SIZE = 16;
    parameter DATA_WIDTH     = 32;
    parameter DIST_WIDTH     = 40;

    logic clk;
    logic rst;
    logic start;

    logic signed [DATA_WIDTH-1:0]
        query_embedding [0:EMBEDDING_SIZE-1];

    logic signed [DATA_WIDTH-1:0]
        reference_embedding [0:EMBEDDING_SIZE-1];

    logic [DIST_WIDTH-1:0] threshold;

    logic [DIST_WIDTH-1:0] distance;

    logic similar;
    logic done;

    integer i;


    // ==================================================
    // DUT
    // ==================================================

    similarity_checker #(
        .EMBEDDING_SIZE (EMBEDDING_SIZE),
        .DATA_WIDTH     (DATA_WIDTH),
        .DIST_WIDTH     (DIST_WIDTH)
    ) dut (

        .clk                 (clk),
        .rst                 (rst),
        .start               (start),

        .query_embedding     (query_embedding),
        .reference_embedding (reference_embedding),

        .threshold           (threshold),

        .distance            (distance),
        .similar             (similar),
        .done                (done)
    );


    // ==================================================
    // CLOCK
    // ==================================================

    initial begin

        clk = 1'b0;

        forever #5 clk = ~clk;

    end


    // ==================================================
    // TEST
    // ==================================================

    initial begin

        rst       = 1'b1;
        start     = 1'b0;
        threshold = 40'd100;

        for (i = 0; i < EMBEDDING_SIZE; i = i + 1) begin

            query_embedding[i]     = '0;
            reference_embedding[i] = '0;

        end


        // ------------------------------------------------
        // RESET
        // ------------------------------------------------

        #20;

        rst = 1'b0;

        #10;


        // =================================================
        // TEST 1
        // IDENTICAL EMBEDDINGS
        // Expected distance = 0
        // Expected similar = 1
        // =================================================

        $display("----------------------------------------");
        $display("TEST 1: IDENTICAL EMBEDDINGS");
        $display("----------------------------------------");

        for (i = 0; i < EMBEDDING_SIZE; i = i + 1) begin

            query_embedding[i]     = i;
            reference_embedding[i] = i;

        end

        @(negedge clk);

        start = 1'b1;

        @(negedge clk);

        start = 1'b0;

        wait(done == 1'b1);

        #1;

        $display("Distance = %0d", distance);
        $display("Similar  = %0d", similar);


        // =================================================
        // TEST 2
        // SMALL DIFFERENCE
        // =================================================

        $display("----------------------------------------");
        $display("TEST 2: SMALL DIFFERENCE");
        $display("----------------------------------------");

        for (i = 0; i < EMBEDDING_SIZE; i = i + 1) begin

            reference_embedding[i] = i;
            query_embedding[i]     = i + 2;

        end

        @(negedge clk);

        start = 1'b1;

        @(negedge clk);

        start = 1'b0;

        wait(done == 1'b1);

        #1;

        $display("Distance = %0d", distance);
        $display("Similar  = %0d", similar);


        // =================================================
        // TEST 3
        // LARGE DIFFERENCE
        // =================================================

        $display("----------------------------------------");
        $display("TEST 3: LARGE DIFFERENCE");
        $display("----------------------------------------");

        for (i = 0; i < EMBEDDING_SIZE; i = i + 1) begin

            reference_embedding[i] = 0;
            query_embedding[i]     = 50;

        end

        @(negedge clk);

        start = 1'b1;

        @(negedge clk);

        start = 1'b0;

        wait(done == 1'b1);

        #1;

        $display("Distance = %0d", distance);
        $display("Similar  = %0d", similar);


        // =================================================
        // FINISH
        // =================================================

        $display("----------------------------------------");
        $display("SIMILARITY CHECKER TEST COMPLETED");
        $display("----------------------------------------");

        #20;

        $finish;

    end

endmodule