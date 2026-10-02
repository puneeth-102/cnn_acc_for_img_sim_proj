`timescale 1ns/1ps

module tb_embedding_memory;

    // --------------------------------------------------
    // Parameters
    // --------------------------------------------------

    parameter DATA_WIDTH = 32;
    parameter DEPTH      = 16;


    // --------------------------------------------------
    // Clock and reset
    // --------------------------------------------------

    logic clk;
    logic rst;


    // --------------------------------------------------
    // Write interface
    // --------------------------------------------------

    logic                         write_en;
    logic [$clog2(DEPTH)-1:0]     write_addr;
    logic signed [DATA_WIDTH-1:0]  write_data;


    // --------------------------------------------------
    // Read interface
    // --------------------------------------------------

    logic [$clog2(DEPTH)-1:0]     read_addr;
    logic signed [DATA_WIDTH-1:0]  read_data;


    integer i;


    // ==================================================
    // DUT
    // ==================================================

    embedding_memory #(
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (DEPTH)
    ) dut (

        .clk       (clk),
        .rst       (rst),

        .write_en  (write_en),
        .write_addr(write_addr),
        .write_data(write_data),

        .read_addr (read_addr),
        .read_data (read_data)

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

        // ----------------------------------------------
        // Initial values
        // ----------------------------------------------

        rst        = 1'b1;
        write_en   = 1'b0;
        write_addr = '0;
        write_data = '0;
        read_addr  = '0;


        // ----------------------------------------------
        // Reset
        // ----------------------------------------------

        #20;

        rst = 1'b0;

        #10;


        // =================================================
        // WRITE TEST
        // =================================================

        $display("----------------------------------------");
        $display("Writing embedding values...");
        $display("----------------------------------------");


        for (i = 0; i < DEPTH; i = i + 1) begin

            @(negedge clk);

            write_en   = 1'b1;
            write_addr = i;
            write_data = 32'sd100 + i;

        end


        @(negedge clk);

        write_en = 1'b0;


        // Give memory time to complete final write

        @(posedge clk);


        // =================================================
        // READ TEST
        // =================================================

        $display("----------------------------------------");
        $display("Reading embedding values...");
        $display("----------------------------------------");


        for (i = 0; i < DEPTH; i = i + 1) begin

            read_addr = i;

            #1;

            $display(
                "Address = %0d | Data = %0d",
                i,
                read_data
            );

        end


        // =================================================
        // FINISH
        // =================================================

        $display("----------------------------------------");
        $display("Embedding memory test completed");
        $display("----------------------------------------");

        #20;

        $finish;

    end

endmodule