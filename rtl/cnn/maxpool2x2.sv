module maxpool2x2 #(
    parameter INPUT_SIZE  = 14,
    parameter NUM_CHANNELS = 4,
    parameter DATA_WIDTH = 32
)(
    input  logic signed [DATA_WIDTH-1:0]
        data_in [0:(INPUT_SIZE*INPUT_SIZE*NUM_CHANNELS)-1],

    output logic signed [DATA_WIDTH-1:0]
        data_out [0:((INPUT_SIZE/2)*(INPUT_SIZE/2)*NUM_CHANNELS)-1]
);

    localparam OUTPUT_SIZE = INPUT_SIZE / 2;

    integer ch;
    integer row;
    integer col;

    integer in_index0;
    integer in_index1;
    integer in_index2;
    integer in_index3;

    integer out_index;

    always_comb begin

        for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1) begin

            for (row = 0; row < OUTPUT_SIZE; row = row + 1) begin

                for (col = 0; col < OUTPUT_SIZE; col = col + 1) begin

                    // Four values inside the 2x2 window

                    in_index0 =
                        ch * INPUT_SIZE * INPUT_SIZE +
                        (row * 2) * INPUT_SIZE +
                        (col * 2);

                    in_index1 = in_index0 + 1;

                    in_index2 =
                        in_index0 + INPUT_SIZE;

                    in_index3 =
                        in_index2 + 1;


                    // Output location

                    out_index =
                        ch * OUTPUT_SIZE * OUTPUT_SIZE +
                        row * OUTPUT_SIZE +
                        col;


                    // Find maximum

                    data_out[out_index] = data_in[in_index0];

                    if (data_in[in_index1] >
                        data_out[out_index])
                        data_out[out_index] =
                            data_in[in_index1];

                    if (data_in[in_index2] >
                        data_out[out_index])
                        data_out[out_index] =
                            data_in[in_index2];

                    if (data_in[in_index3] >
                        data_out[out_index])
                        data_out[out_index] =
                            data_in[in_index3];

                end

            end

        end

    end

endmodule