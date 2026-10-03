`timescale 1ns/1ps

module cnn_top #(
    parameter IMAGE_SIZE   = 16,
    parameter NUM_FILTERS  = 4,
    parameter DATA_WIDTH   = 32,
    parameter FEATURE_W    = 8,
    parameter EMBEDDING_W  = 32
)(
    input logic clk,
    input logic rst,
    input logic start,

    // --------------------------------------------------
    // Input image
    // 16 x 16 = 256 pixels
    // --------------------------------------------------

    input logic signed [7:0] image [0:255],

    // --------------------------------------------------
    // Convolution weights
    // 4 filters x 3 x 3 = 36
    // --------------------------------------------------

    input logic signed [7:0] conv_weights [0:35],

    // --------------------------------------------------
    // FC weights
    // 16 neurons x 196 features
    // --------------------------------------------------

    input logic signed [FEATURE_W-1:0]
        fc_weights [0:15][0:195],

    // --------------------------------------------------
    // FC bias
    // --------------------------------------------------

    input logic signed [EMBEDDING_W-1:0]
        fc_bias [0:15],

    // --------------------------------------------------
    // Final 16-dimensional embedding
    // --------------------------------------------------

    output logic signed [EMBEDDING_W-1:0]
        embedding [0:15],

    output logic busy,
    output logic done
);


    // ==================================================
    // CNN INTERNAL SIGNALS
    // ==================================================

    // Conv output:
    // 4 filters x 14 x 14 = 784

    logic signed [DATA_WIDTH-1:0]
        conv_out [0:783];

    // ReLU output

    logic signed [DATA_WIDTH-1:0]
        relu_out [0:783];

    // MaxPool output:
    // 4 x 7 x 7 = 196

    logic signed [DATA_WIDTH-1:0]
        pool_out [0:195];

    // Flatten output

    logic signed [DATA_WIDTH-1:0]
        flatten_out [0:195];

    // FC requires 8-bit input

    logic signed [FEATURE_W-1:0]
        fc_features [0:195];

    // Individual module completion signals

    logic conv_done;
    logic conv_busy;
    logic fc_done;

    // Start signals

    logic conv_start;
    logic fc_start;


    // ==================================================
    // FSM
    // ==================================================

    typedef enum logic [2:0] {
        IDLE,
        START_CONV,
        WAIT_CONV,
        START_FC,
        WAIT_FC,
        COMPLETE
    } state_t;

    state_t state;


    // ==================================================
    // CONVOLUTION
    // ==================================================

    conv3x3 #(
        .IMAGE_SIZE  (IMAGE_SIZE),
        .NUM_FILTERS (NUM_FILTERS)
    ) u_conv (
        .clk       (clk),
        .rst       (rst),
        .start     (conv_start),

        .image     (image),
        .weights   (conv_weights),

        .conv_out  (conv_out),

        .busy      (conv_busy),
        .done      (conv_done)
    );


    // ==================================================
    // RELU
    // ==================================================

    relu #(
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_VALUES (784)
    ) u_relu (
        .data_in  (conv_out),
        .data_out (relu_out)
    );


    // ==================================================
    // MAX POOL
    // ==================================================

    maxpool2x2 #(
        .INPUT_SIZE   (14),
        .NUM_CHANNELS (4),
        .DATA_WIDTH   (DATA_WIDTH)
    ) u_maxpool (
        .data_in  (relu_out),
        .data_out (pool_out)
    );


    // ==================================================
    // FLATTEN
    // ==================================================

    flatten #(
        .INPUT_VALUES (196),
        .DATA_WIDTH   (DATA_WIDTH)
    ) u_flatten (
        .data_in  (pool_out),
        .data_out (flatten_out)
    );


    // ==================================================
    // 32-bit ? 8-bit FC FEATURE CONVERSION
    // ==================================================
    //
    // TEMPORARY functional conversion.
    //
    // The actual trained model will later require
    // proper quantization/scaling.
    //
    // For now we use the lower 8 bits.
    //
    // ==================================================

    integer i;

    always_comb begin

        for (i = 0; i < 196; i = i + 1) begin

            fc_features[i] =
                flatten_out[i][FEATURE_W-1:0];

        end

    end


    // ==================================================
    // FULLY CONNECTED LAYER
    // ==================================================

    fc_196_16 #(
        .DATA_W (FEATURE_W),
        .ACC_W  (EMBEDDING_W)
    ) u_fc (
        .clk       (clk),
        .rst       (rst),
        .start     (fc_start),

        .feature   (fc_features),
        .weight    (fc_weights),
        .bias      (fc_bias),

        .embedding (embedding),
        .done      (fc_done)
    );


    // ==================================================
    // CONTROL FSM
    // ==================================================

    always_ff @(posedge clk) begin

        if (rst) begin

            state     <= IDLE;

            conv_start <= 1'b0;
            fc_start   <= 1'b0;

            busy      <= 1'b0;
            done      <= 1'b0;

        end

        else begin

            // Default:
            // start signals are one-clock pulses

            conv_start <= 1'b0;
            fc_start   <= 1'b0;

            // DONE is also a one-clock pulse

            done <= 1'b0;


            case (state)

                // --------------------------------------
                // IDLE
                // --------------------------------------

                IDLE: begin

                    busy <= 1'b0;

                    if (start) begin

                        busy <= 1'b1;

                        state <= START_CONV;

                    end

                end


                // --------------------------------------
                // Start convolution
                // --------------------------------------

                START_CONV: begin

                    conv_start <= 1'b1;

                    state <= WAIT_CONV;

                end


                // --------------------------------------
                // Wait for convolution
                // --------------------------------------


                WAIT_CONV: begin
                
                    if (conv_done) begin
                
                        state <= START_FC;
                
                    end
                
                end

                // --------------------------------------
                // Start FC
                // --------------------------------------

                START_FC: begin

                    fc_start <= 1'b1;

                    state <= WAIT_FC;

                end


                // --------------------------------------
                // Wait for FC
                // --------------------------------------

                WAIT_FC: begin

                    if (fc_done) begin

                        state <= COMPLETE;

                    end

                end


                // --------------------------------------
                // Complete
                // --------------------------------------

                COMPLETE: begin

                    busy <= 1'b0;
                    done <= 1'b1;

                    state <= IDLE;

                end


                default: begin

                    state <= IDLE;

                end

            endcase

        end

    end

endmodule