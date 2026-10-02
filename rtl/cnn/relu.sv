module relu #(
    parameter DATA_WIDTH = 32,
    parameter NUM_VALUES = 784
)(
    input  logic signed [DATA_WIDTH-1:0] data_in [0:NUM_VALUES-1],

    output logic signed [DATA_WIDTH-1:0] data_out [0:NUM_VALUES-1]
);

    integer i;

    always_comb begin

        for (i = 0; i < NUM_VALUES; i = i + 1) begin

            if (data_in[i] < 0)
                data_out[i] = '0;
            else
                data_out[i] = data_in[i];

        end

    end

endmodule