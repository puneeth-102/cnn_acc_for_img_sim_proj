`timescale 1ns/1ps

module tb_threshold;

    parameter DIST_W = 40;

    logic signed [DIST_W-1:0] distance;
    logic signed [DIST_W-1:0] threshold_value;

    logic similar;

    threshold #(
        .DIST_W(DIST_W)
    ) dut (
        .distance(distance),
        .threshold_value(threshold_value),
        .similar(similar)
    );

    initial begin

        // ----------------------------------------
        // TEST 1
        // Distance < Threshold
        // Expected: SIMILAR
        // ----------------------------------------

        distance = 80;
        threshold_value = 100;

        #10;

        $display("--------------------------------");
        $display("TEST 1");
        $display("Distance  = %0d", distance);
        $display("Threshold = %0d", threshold_value);
        $display("Similar   = %0d", similar);

        if (similar == 1'b1)
            $display("TEST 1 : PASS");
        else
            $display("TEST 1 : FAIL");


        // ----------------------------------------
        // TEST 2
        // Distance > Threshold
        // Expected: DIFFERENT
        // ----------------------------------------

        distance = 150;
        threshold_value = 100;

        #10;

        $display("--------------------------------");
        $display("TEST 2");
        $display("Distance  = %0d", distance);
        $display("Threshold = %0d", threshold_value);
        $display("Similar   = %0d", similar);

        if (similar == 1'b0)
            $display("TEST 2 : PASS");
        else
            $display("TEST 2 : FAIL");


        // ----------------------------------------
        // TEST 3
        // Distance == Threshold
        // Our rule: <= means SIMILAR
        // Expected: SIMILAR
        // ----------------------------------------

        distance = 100;
        threshold_value = 100;

        #10;

        $display("--------------------------------");
        $display("TEST 3");
        $display("Distance  = %0d", distance);
        $display("Threshold = %0d", threshold_value);
        $display("Similar   = %0d", similar);

        if (similar == 1'b1)
            $display("TEST 3 : PASS");
        else
            $display("TEST 3 : FAIL");

        $display("--------------------------------");

        #10;
        $finish;

    end

endmodule