module flatten #(
    parameter INPUT_VALUES = 196,
    parameter DATA_WIDTH   = 32
)(
    input  logic signed [DATA_WIDTH-1:0]
        data_in [0:INPUT_VALUES-1],

    output logic signed [DATA_WIDTH-1:0]
        data_out [0:INPUT_VALUES-1]
);

    integer i;

    always_comb begin

        for (i = 0; i < INPUT_VALUES; i = i + 1) begin
            data_out[i] = data_in[i];
        end

    end

endmodule