module conv3x3 #(
    parameter IMAGE_SIZE = 16,
    parameter NUM_FILTERS = 4
)(
    input  logic clk,
    input  logic rst,
    input  logic start,

    // 16x16 = 256 pixels
    input logic signed [7:0] image [0:255],

    // 4 filters × 3 × 3 = 36 weights
    input logic signed [7:0] weights [0:35],

    // 4 × 14 × 14 = 784 outputs
    output logic signed [31:0] conv_out [0:783],

    output logic busy,
    output logic done
);

    localparam OUTPUT_SIZE = IMAGE_SIZE - 2;

    // --------------------------------------------------
    // MAC signals
    // --------------------------------------------------

    logic signed [7:0] mac_pixel;
    logic signed [7:0] mac_weight;

    logic mac_clear;
    logic mac_en;

    logic signed [31:0] mac_acc;


    // --------------------------------------------------
    // MAC instance
    // --------------------------------------------------

    mac_unit mac_inst (
        .clk       (clk),
        .rst       (rst),
        .clear_acc (mac_clear),
        .en        (mac_en),
        .pixel     (mac_pixel),
        .weight    (mac_weight),
        .acc_out   (mac_acc)
    );


    // --------------------------------------------------
    // FSM
    // --------------------------------------------------

    typedef enum logic [2:0] {
        IDLE,
        CLEAR_ACC,
        MAC_CALC,
        STORE
    } state_t;

    state_t state;


    // --------------------------------------------------
    // Position counters
    // --------------------------------------------------

    integer row;
    integer col;
    integer filter;
    integer k;


    // --------------------------------------------------
    // Temporary coordinates
    // --------------------------------------------------

    integer pixel_row;
    integer pixel_col;

    integer weight_base;
    integer output_index;


    // --------------------------------------------------
    // Combinational MAC inputs
    // --------------------------------------------------

    always_comb begin

        mac_pixel  = 8'sd0;
        mac_weight = 8'sd0;

        mac_clear = 1'b0;
        mac_en    = 1'b0;

        pixel_row = row + (k / 3);
        pixel_col = col + (k % 3);

        weight_base = filter * 9;

        if (state == CLEAR_ACC) begin

            mac_clear = 1'b1;

        end

        else if (state == MAC_CALC) begin

            mac_en = 1'b1;

            mac_pixel =
                image[pixel_row * IMAGE_SIZE + pixel_col];

            mac_weight =
                weights[weight_base + k];

        end

    end


    // --------------------------------------------------
    // Sequential controller
    // --------------------------------------------------

    always_ff @(posedge clk) begin

        if (rst) begin

            state  <= IDLE;

            row    <= 0;
            col    <= 0;
            filter <= 0;
            k      <= 0;

            busy   <= 1'b0;
            done   <= 1'b0;

        end

        else begin

            // DONE is a one-cycle pulse
            done <= 1'b0;


            case (state)

                // --------------------------------------
                // IDLE
                // --------------------------------------

                IDLE: begin

                    busy <= 1'b0;

                    if (start) begin

                        row    <= 0;
                        col    <= 0;
                        filter <= 0;
                        k      <= 0;

                        busy <= 1'b1;

                        state <= CLEAR_ACC;

                    end

                end


                // --------------------------------------
                // Clear MAC accumulator
                // --------------------------------------

                CLEAR_ACC: begin

                    k <= 0;

                    state <= MAC_CALC;

                end


                // --------------------------------------
                // Perform 9 MAC operations
                // --------------------------------------

                MAC_CALC: begin

                    if (k == 8) begin

                        state <= STORE;

                    end

                    else begin

                        k <= k + 1;

                    end

                end


                // --------------------------------------
                // Store convolution result
                // --------------------------------------

                STORE: begin

                    output_index =
                        filter * 196 +
                        row * 14 +
                        col;

                    conv_out[output_index] <= mac_acc;


                    // Move to next output pixel

                    if (col < 13) begin

                        col <= col + 1;
                        k   <= 0;

                        state <= CLEAR_ACC;

                    end

                    else begin

                        col <= 0;

                        if (row < 13) begin

                            row <= row + 1;
                            k   <= 0;

                            state <= CLEAR_ACC;

                        end

                        else begin

                            row <= 0;

                            if (filter < NUM_FILTERS-1) begin

                                filter <= filter + 1;
                                k      <= 0;

                                state <= CLEAR_ACC;

                            end

                            else begin

                                busy  <= 1'b0;
                                done  <= 1'b1;

                                state <= IDLE;

                            end

                        end

                    end

                end

                default: begin

                    state <= IDLE;

                end

            endcase

        end

    end

endmodule