`timescale 1ns/1ps

module tb_maxpool2x2;

    logic signed [31:0] data_in [0:783];

    logic signed [31:0] data_out [0:195];

    integer i;


    maxpool2x2 dut (
        .data_in  (data_in),
        .data_out (data_out)
    );


    initial begin

        // Initialize all inputs to zero

        for (i = 0; i < 784; i = i + 1)
            data_in[i] = 32'sd0;


        // ------------------------------------------------
        // Channel 0
        //
        // Put known values in first 2x2 window
        //
        // 10   20
        // 30   40
        //
        // Expected maximum = 40
        // ------------------------------------------------

        data_in[0] = 10;
        data_in[1] = 20;
        data_in[14] = 30;
        data_in[15] = 40;


        // ------------------------------------------------
        // Second 2x2 window
        //
        // 5   100
        // 7   8
        //
        // Expected = 100
        // ------------------------------------------------

        data_in[2]  = 5;
        data_in[3]  = 100;
        data_in[16] = 7;
        data_in[17] = 8;


        #10;


        $display("--------------------------------");
        $display("MAXPOOL TEST");
        $display("--------------------------------");

        $display("Output[0] = %0d", data_out[0]);
        $display("Output[1] = %0d", data_out[1]);


        if ((data_out[0] == 40) &&
            (data_out[1] == 100)) begin

            $display("MAXPOOL TEST PASSED");

        end
        else begin

            $display("MAXPOOL TEST FAILED");

        end


        #10;

        $finish;

    end

endmodule