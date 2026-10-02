`timescale 1ns/1ps

module tb_distance;

    parameter DATA_W = 32;
    parameter EMB_W  = 16;
    parameter DIST_W = 40;

    logic signed [DATA_W-1:0] embedding_a [0:EMB_W-1];
    logic signed [DATA_W-1:0] embedding_b [0:EMB_W-1];

    logic signed [DIST_W-1:0] distance;

    integer i;

    distance #(
        .DATA_W(DATA_W),
        .EMB_W(EMB_W),
        .DIST_W(DIST_W)
    ) dut (
        .embedding_a(embedding_a),
        .embedding_b(embedding_b),
        .distance(distance)
    );

    initial begin

        // ------------------------------------------------
        // TEST 1
        // A = 10, B = 5 for all 16 elements
        // |10-5| = 5
        // Total = 16 × 5 = 80
        // ------------------------------------------------

        for (i = 0; i < EMB_W; i = i + 1) begin
            embedding_a[i] = 10;
            embedding_b[i] = 5;
        end

        #10;

        $display("--------------------------------");
        $display("TEST 1");
        $display("Expected Distance = 80");
        $display("Actual Distance   = %0d", distance);

        if (distance == 80)
            $display("TEST 1 : PASS");
        else
            $display("TEST 1 : FAIL");


        // ------------------------------------------------
        // TEST 2
        // Reverse order
        // A = 5, B = 10
        // |5-10| = 5
        // Total = 80
        // ------------------------------------------------

        for (i = 0; i < EMB_W; i = i + 1) begin
            embedding_a[i] = 5;
            embedding_b[i] = 10;
        end

        #10;

        $display("--------------------------------");
        $display("TEST 2");
        $display("Expected Distance = 80");
        $display("Actual Distance   = %0d", distance);

        if (distance == 80)
            $display("TEST 2 : PASS");
        else
            $display("TEST 2 : FAIL");


        // ------------------------------------------------
        // TEST 3
        // Same embeddings
        // Distance should be 0
        // ------------------------------------------------

        for (i = 0; i < EMB_W; i = i + 1) begin
            embedding_a[i] = 25;
            embedding_b[i] = 25;
        end

        #10;

        $display("--------------------------------");
        $display("TEST 3");
        $display("Expected Distance = 0");
        $display("Actual Distance   = %0d", distance);

        if (distance == 0)
            $display("TEST 3 : PASS");
        else
            $display("TEST 3 : FAIL");


        // ------------------------------------------------
        // TEST 4
        // Different values for every element
        // ------------------------------------------------

        for (i = 0; i < EMB_W; i = i + 1) begin
            embedding_a[i] = i;
            embedding_b[i] = 0;
        end

        #10;

        // 0+1+2+...+15 = 120

        $display("--------------------------------");
        $display("TEST 4");
        $display("Expected Distance = 120");
        $display("Actual Distance   = %0d", distance);

        if (distance == 120)
            $display("TEST 4 : PASS");
        else
            $display("TEST 4 : FAIL");

        $display("--------------------------------");

        #10;
        $finish;

    end

endmodule