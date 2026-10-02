module fc_196_16 #(
    parameter DATA_W = 8,
    parameter ACC_W  = 32
)(
    input  wire                         clk,
    input  wire                         rst,
    input  wire                         start,

    input  wire signed [DATA_W-1:0]     feature [0:195],
    input  wire signed [DATA_W-1:0]     weight  [0:15][0:195],
    input  wire signed [ACC_W-1:0]      bias    [0:15],

    output reg  signed [ACC_W-1:0]      embedding [0:15],
    output reg                          done
);

    integer i, j;

    reg signed [ACC_W-1:0] acc [0:15];

    always @(posedge clk) begin

        if (rst) begin
            done <= 1'b0;

            for (j = 0; j < 16; j = j + 1) begin
                acc[j]       <= 0;
                embedding[j] <= 0;
            end
        end

        else begin
            done <= 1'b0;

            if (start) begin

                // Calculate all 16 output neurons
                for (j = 0; j < 16; j = j + 1) begin

                    acc[j] = bias[j];

                    for (i = 0; i < 196; i = i + 1) begin
                        acc[j] = acc[j] +
                                 feature[i] * weight[j][i];
                    end

                    embedding[j] <= acc[j];

                end

                done <= 1'b1;
            end
        end
    end

endmodule