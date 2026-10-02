`timescale 1ns/1ps

module tb_fc_196_16;

    parameter DATA_W = 8;
    parameter ACC_W  = 32;

    reg clk;
    reg rst;
    reg start;

    reg signed [DATA_W-1:0] feature [0:195];
    reg signed [DATA_W-1:0] weight  [0:15][0:195];
    reg signed [ACC_W-1:0]  bias    [0:15];

    wire signed [ACC_W-1:0] embedding [0:15];
    wire done;

    integer i, j;

    // DUT
    fc_196_16 #(
        .DATA_W(DATA_W),
        .ACC_W(ACC_W)
    ) dut (
        .clk       (clk),
        .rst       (rst),
        .start     (start),
        .feature   (feature),
        .weight    (weight),
        .bias      (bias),
        .embedding (embedding),
        .done      (done)
    );

    // Clock: 10 ns period
    always #5 clk = ~clk;

    initial begin

        // Initial values
        clk   = 0;
        rst   = 1;
        start = 0;

        // Initialize features, weights and biases
        for (i = 0; i < 196; i = i + 1)
            feature[i] = 1;

        for (j = 0; j < 16; j = j + 1) begin

            bias[j] = 0;

            for (i = 0; i < 196; i = i + 1)
                weight[j][i] = 1;

        end

        // Reset
        #20;
        rst = 0;

        // Start FC
        #10;
        start = 1;

        #10;
        start = 0;

        // Wait for completion
        wait(done == 1);

        #10;

        // Display results
        $display("====================================");
        $display("       FC 196 -> 16 TEST");
        $display("====================================");

        for (j = 0; j < 16; j = j + 1) begin
            $display("Embedding[%0d] = %0d",
                     j, embedding[j]);
        end

        // Check results
        for (j = 0; j < 16; j = j + 1) begin

            if (embedding[j] != 196)
                $display("ERROR: Embedding[%0d] expected 196, got %0d",
                         j, embedding[j]);
            else
                $display("PASS: Embedding[%0d] = 196", j);

        end

        $display("====================================");

        #20;
        $finish;

    end

endmodule