`timescale 1ns/1ps

module tb_distance_top;

    parameter DATA_W = 32;
    parameter EMB_W  = 16;
    parameter DIST_W = 40;

    logic signed [DATA_W-1:0] embedding_a [0:EMB_W-1];
    logic signed [DATA_W-1:0] embedding_b [0:EMB_W-1];

    logic signed [DIST_W-1:0] threshold_value;

    logic signed [DIST_W-1:0] distance;
    logic similar;

    integer i;

    distance_top #(
        .DATA_W(DATA_W),
        .EMB_W(EMB_W),
        .DIST_W(DIST_W)
    ) dut (
        .embedding_a(embedding_a),
        .embedding_b(embedding_b),
        .threshold_value(threshold_value),
        .distance(distance),
        .similar(similar)
    );

    initial begin

        threshold_value = 100;

        // ==========================================
        // TEST 1
        // A = 10, B = 5
        // Distance = 16 * |10-5| = 80
        // 80 <= 100 ? SIMILAR
        // ==========================================

        for (i = 0; i < EMB_W; i = i + 1) begin
            embedding_a[i] = 10;
            embedding_b[i] = 5;
        end

        #10;

        $display("--------------------------------");
        $display("TEST 1");
        $display("Distance  = %0d", distance);
        $display("Threshold = %0d", threshold_value);
        $display("Similar   = %0d", similar);

        if ((distance == 80) && (similar == 1'b1))
            $display("TEST 1 : PASS");
        else
            $display("TEST 1 : FAIL");


        // ==========================================
        // TEST 2
        // A = 20, B = 5
        // Distance = 16 * 15 = 240
        // 240 > 100 ? DIFFERENT
        // ==========================================

        for (i = 0; i < EMB_W; i = i + 1) begin
            embedding_a[i] = 20;
            embedding_b[i] = 5;
        end

        #10;

        $display("--------------------------------");
        $display("TEST 2");
        $display("Distance  = %0d", distance);
        $display("Threshold = %0d", threshold_value);
        $display("Similar   = %0d", similar);

        if ((distance == 240) && (similar == 1'b0))
            $display("TEST 2 : PASS");
        else
            $display("TEST 2 : FAIL");


        // ==========================================
        // TEST 3
        // Same embeddings
        // Distance = 0
        // 0 <= 100 ? SIMILAR
        // ==========================================

        for (i = 0; i < EMB_W; i = i + 1) begin
            embedding_a[i] = 50;
            embedding_b[i] = 50;
        end

        #10;

        $display("--------------------------------");
        $display("TEST 3");
        $display("Distance  = %0d", distance);
        $display("Threshold = %0d", threshold_value);
        $display("Similar   = %0d", similar);

        if ((distance == 0) && (similar == 1'b1))
            $display("TEST 3 : PASS");
        else
            $display("TEST 3 : FAIL");


        $display("--------------------------------");
        $display("Distance/Anomaly Engine test complete.");
        $display("--------------------------------");

        #10;
        $finish;

    end

endmodule