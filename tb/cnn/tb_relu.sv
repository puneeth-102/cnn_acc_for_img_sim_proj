`timescale 1ns/1ps

module tb_relu;

    logic signed [31:0] data_in [0:783];

    logic signed [31:0] data_out [0:783];

    integer i;


    // --------------------------------------------------
    // DUT
    // --------------------------------------------------

    relu dut (
        .data_in  (data_in),
        .data_out (data_out)
    );


    // --------------------------------------------------
    // Test
    // --------------------------------------------------

    initial begin

        // Initialize everything to zero

        for (i = 0; i < 784; i = i + 1) begin
            data_in[i] = 32'sd0;
        end


        // ----------------------------------------------
        // Test values
        // ----------------------------------------------

        data_in[0] = 32'sd10;
        data_in[1] = -32'sd5;
        data_in[2] = 32'sd0;
        data_in[3] = -32'sd20;
        data_in[4] = 32'sd15;
        data_in[5] = -32'sd1;


        #10;


        // ----------------------------------------------
        // Display
        // ----------------------------------------------

        $display("--------------------------------");
        $display("ReLU TEST");
        $display("--------------------------------");

        $display("Input  [0] = %0d | Output [0] = %0d",
                 data_in[0], data_out[0]);

        $display("Input  [1] = %0d | Output [1] = %0d",
                 data_in[1], data_out[1]);

        $display("Input  [2] = %0d | Output [2] = %0d",
                 data_in[2], data_out[2]);

        $display("Input  [3] = %0d | Output [3] = %0d",
                 data_in[3], data_out[3]);

        $display("Input  [4] = %0d | Output [4] = %0d",
                 data_in[4], data_out[4]);

        $display("Input  [5] = %0d | Output [5] = %0d",
                 data_in[5], data_out[5]);


        // ----------------------------------------------
        // Automatic checking
        // ----------------------------------------------

        if ((data_out[0] == 10) &&
            (data_out[1] == 0)  &&
            (data_out[2] == 0)  &&
            (data_out[3] == 0)  &&
            (data_out[4] == 15) &&
            (data_out[5] == 0)) begin

            $display("--------------------------------");
            $display("RELU TEST PASSED");
            $display("--------------------------------");

        end
        else begin

            $display("--------------------------------");
            $display("RELU TEST FAILED");
            $display("--------------------------------");

        end


        #10;

        $finish;

    end

endmodule