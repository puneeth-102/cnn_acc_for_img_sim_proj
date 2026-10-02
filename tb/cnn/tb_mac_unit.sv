`timescale 1ns/1ps

module tb_mac_unit;

    logic clk;
    logic rst;

    logic clear_acc;
    logic en;

    logic signed [7:0] pixel;
    logic signed [7:0] weight;

    logic signed [31:0] acc_out;


    // --------------------------------------------------
    // DUT
    // --------------------------------------------------

    mac_unit dut (
        .clk       (clk),
        .rst       (rst),
        .clear_acc (clear_acc),
        .en        (en),
        .pixel     (pixel),
        .weight    (weight),
        .acc_out   (acc_out)
    );


    // --------------------------------------------------
    // Clock generation
    // 10 ns clock period
    // --------------------------------------------------

    initial begin
        clk = 1'b0;

        forever #5 clk = ~clk;
    end


    // --------------------------------------------------
    // Test
    // --------------------------------------------------

    initial begin

        // Initial values
        rst       = 1'b1;
        clear_acc = 1'b0;
        en        = 1'b0;
        pixel     = 8'sd0;
        weight    = 8'sd0;


        // Reset
        #20;

        rst = 1'b0;


        // ------------------------------------------------
        // Clear accumulator
        // ------------------------------------------------

        @(negedge clk);

        clear_acc = 1'b1;

        @(negedge clk);

        clear_acc = 1'b0;


        // ------------------------------------------------
        // Product 1
        // 1 × 1 = 1
        // ------------------------------------------------

        pixel  = 8'sd1;
        weight = 8'sd1;
        en     = 1'b1;

        @(negedge clk);


        // ------------------------------------------------
        // Product 2
        // 2 × 2 = 4
        // Accumulator = 1 + 4 = 5
        // ------------------------------------------------

        pixel  = 8'sd2;
        weight = 8'sd2;

        @(negedge clk);


        // ------------------------------------------------
        // Product 3
        // 3 × 3 = 9
        // Accumulator = 5 + 9 = 14
        // ------------------------------------------------

        pixel  = 8'sd3;
        weight = 8'sd3;

        @(negedge clk);


        // ------------------------------------------------
        // Product 4
        // 4 × 4 = 16
        // Accumulator = 14 + 16 = 30
        // ------------------------------------------------

        pixel  = 8'sd4;
        weight = 8'sd4;

        @(negedge clk);


        // Stop MAC
        en = 1'b0;

        @(posedge clk);

        #1;

        $display("---------------------------------------");
        $display("MAC TEST RESULT");
        $display("---------------------------------------");
        $display("Expected = 30");
        $display("Actual   = %0d", acc_out);
        $display("---------------------------------------");


        if (acc_out == 32'sd30) begin
            $display("TEST PASSED");
        end
        else begin
            $display("TEST FAILED");
        end


        #20;

        $finish;

    end

endmodule