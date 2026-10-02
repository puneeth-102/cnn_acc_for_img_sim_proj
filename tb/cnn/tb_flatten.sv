`timescale 1ns/1ps

module tb_flatten;

    logic signed [31:0] data_in  [0:195];
    logic signed [31:0] data_out [0:195];

    integer i;

    flatten dut (
        .data_in  (data_in),
        .data_out (data_out)
    );

    initial begin

        // Put easily recognizable values
        for (i = 0; i < 196; i = i + 1) begin
            data_in[i] = i;
        end

        #10;

        $display("--------------------------------");
        $display("FLATTEN TEST");
        $display("--------------------------------");

        $display("Input[0]   = %0d", data_in[0]);
        $display("Output[0]  = %0d", data_out[0]);

        $display("Input[49]  = %0d", data_in[49]);
        $display("Output[49] = %0d", data_out[49]);

        $display("Input[100]  = %0d", data_in[100]);
        $display("Output[100] = %0d", data_out[100]);

        $display("Input[195]  = %0d", data_in[195]);
        $display("Output[195] = %0d", data_out[195]);


        if ((data_out[0]   == 0)   &&
            (data_out[49]  == 49)  &&
            (data_out[100] == 100) &&
            (data_out[195] == 195)) begin

            $display("--------------------------------");
            $display("FLATTEN TEST PASSED");
            $display("--------------------------------");

        end
        else begin

            $display("--------------------------------");
            $display("FLATTEN TEST FAILED");
            $display("--------------------------------");

        end

        #10;

        $finish;

    end

endmodule