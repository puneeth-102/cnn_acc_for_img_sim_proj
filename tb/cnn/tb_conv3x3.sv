`timescale 1ns/1ps

module tb_conv3x3;

    logic clk;
    logic rst;
    logic start;

    logic signed [7:0] image [0:255];

    logic signed [7:0] weights [0:35];

    logic signed [31:0] conv_out [0:783];

    logic busy;
    logic done;


    // --------------------------------------------------
    // DUT
    // --------------------------------------------------

    conv3x3 dut (
        .clk       (clk),
        .rst       (rst),
        .start     (start),
        .image     (image),
        .weights   (weights),
        .conv_out  (conv_out),
        .busy      (busy),
        .done      (done)
    );


    // --------------------------------------------------
    // Clock
    // --------------------------------------------------

    initial begin

        clk = 1'b0;

        forever #5 clk = ~clk;

    end


    // --------------------------------------------------
    // Test
    // --------------------------------------------------

    integer i;

    initial begin

        // Initial values

        rst   = 1'b1;
        start = 1'b0;


        // Initialize image

        for (i = 0; i < 256; i = i + 1) begin

            image[i] = 8'sd1;

        end


        // Initialize all weights to zero

        for (i = 0; i < 36; i = i + 1) begin

            weights[i] = 8'sd0;

        end


        // ------------------------------------------------
        // Filter 0
        //
        // 1 1 1
        // 1 1 1
        // 1 1 1
        //
        // Every image pixel = 1
        //
        // Therefore:
        //
        // output = 1+1+1+1+1+1+1+1+1
        //        = 9
        // ------------------------------------------------

        for (i = 0; i < 9; i = i + 1) begin

            weights[i] = 8'sd1;

        end


        // Other filters remain zero


        // Hold reset for 20 ns

        #20;

        rst = 1'b0;


        // Start convolution

        @(negedge clk);

        start = 1'b1;

        @(negedge clk);

        start = 1'b0;


        // Wait until complete

        wait(done == 1'b1);

        #1;


        $display("-----------------------------------------");
        $display("CONVOLUTION TEST");
        $display("-----------------------------------------");

        $display("Expected Filter 0 Output = 9");
        $display("Actual   Filter 0 Output = %0d",
                 conv_out[0]);

        $display("-----------------------------------------");


        if (conv_out[0] == 32'sd9) begin

            $display("FIRST OUTPUT TEST PASSED");

        end

        else begin

            $display("FIRST OUTPUT TEST FAILED");

        end


        // Check another Filter 0 output

        $display("conv_out[1] = %0d", conv_out[1]);
        $display("conv_out[2] = %0d", conv_out[2]);
        $display("conv_out[195] = %0d", conv_out[195]);


        // Check Filter 1

        $display("Filter 1 first output = %0d",
                 conv_out[196]);


        #20;

        $finish;

    end

endmodule