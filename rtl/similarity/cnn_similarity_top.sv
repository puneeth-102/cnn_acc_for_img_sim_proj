`timescale 1ns/1ps

module cnn_similarity_top #(
    parameter IMAGE_SIZE  = 16,
    parameter NUM_FILTERS = 4,
    parameter DATA_WIDTH  = 32,
    parameter FEATURE_W   = 8,
    parameter EMBEDDING_W = 32
)(
    input logic clk,
    input logic rst,

    // --------------------------------------------------
    // Control
    // --------------------------------------------------

    // Store the current image as reference
    input logic store_ref_start,

    // Compare the current image with stored reference
    input logic query_start,

    // --------------------------------------------------
    // Image
    // --------------------------------------------------

    input logic signed [7:0] image [0:255],

    // --------------------------------------------------
    // CNN weights
    // --------------------------------------------------

    input logic signed [7:0] conv_weights [0:35],

    input logic signed [FEATURE_W-1:0]
        fc_weights [0:15][0:195],

    input logic signed [EMBEDDING_W-1:0]
        fc_bias [0:15],

    // --------------------------------------------------
    // Similarity threshold
    // --------------------------------------------------

    input logic [39:0] threshold,

    // --------------------------------------------------
    // Outputs
    // --------------------------------------------------

    output logic [39:0] distance,

    output logic similar,

    output logic busy,

    output logic done
);


    // ==================================================
    // CNN SIGNALS
    // ==================================================

    logic cnn_start;

    logic cnn_busy;
    logic cnn_done;

    logic signed [EMBEDDING_W-1:0]
        cnn_embedding [0:15];


    // ==================================================
    // EMBEDDING MEMORY SIGNALS
    // ==================================================

    logic memory_write_en;

    logic [3:0] memory_write_addr;

    logic signed [EMBEDDING_W-1:0]
        memory_write_data [0:0];

    logic signed [EMBEDDING_W-1:0]
        reference_embedding [0:15];


    // ==================================================
    // QUERY EMBEDDING
    // ==================================================

    logic signed [EMBEDDING_W-1:0]
        query_embedding [0:15];


    // ==================================================
    // SIMILARITY CHECKER SIGNALS
    // ==================================================

    logic similarity_start;
    logic similarity_done;


    // ==================================================
    // CNN
    // ==================================================

    cnn_top #(
        .IMAGE_SIZE  (IMAGE_SIZE),
        .NUM_FILTERS (NUM_FILTERS),
        .DATA_WIDTH  (DATA_WIDTH),
        .FEATURE_W   (FEATURE_W),
        .EMBEDDING_W (EMBEDDING_W)
    ) u_cnn (

        .clk          (clk),
        .rst          (rst),
        .start        (cnn_start),

        .image        (image),

        .conv_weights (conv_weights),

        .fc_weights   (fc_weights),

        .fc_bias      (fc_bias),

        .embedding    (cnn_embedding),

        .busy         (cnn_busy),
        .done         (cnn_done)
    );


    // ==================================================
    // EMBEDDING MEMORY
    // ==================================================

    embedding_memory #(
        .DATA_WIDTH (EMBEDDING_W),
        .DEPTH      (16)
    ) u_embedding_memory (

        .clk                 (clk),
        .rst                 (rst),

        .write_en            (memory_write_en),
        .write_addr          (memory_write_addr),
        .write_data          (cnn_embedding[memory_write_addr]),

        .reference_embedding (reference_embedding)
    );


    // ==================================================
    // SIMILARITY CHECKER
    // ==================================================

    similarity_checker #(
        .EMBEDDING_SIZE (16),
        .DATA_WIDTH     (EMBEDDING_W),
        .DIST_WIDTH     (40)
    ) u_similarity (

        .clk                 (clk),
        .rst                 (rst),

        .start               (similarity_start),

        .query_embedding     (query_embedding),

        .reference_embedding (reference_embedding),

        .threshold           (threshold),

        .distance            (distance),

        .similar             (similar),

        .done                (similarity_done)
    );


    // ==================================================
    // CONTROLLER FSM
    // ==================================================

    typedef enum logic [3:0] {

        IDLE,

        START_REFERENCE,

        WAIT_REFERENCE,

        STORE_REFERENCE,

        WAIT_QUERY,

        START_QUERY,

        WAIT_QUERY_CNN,

        START_SIMILARITY,

        WAIT_SIMILARITY,

        COMPLETE

    } state_t;

    state_t state;


    integer i;


    // ==================================================
    // CONTROLLER
    // ==================================================

    always_ff @(posedge clk) begin

        if (rst) begin

            state <= IDLE;

            cnn_start       <= 1'b0;
            memory_write_en <= 1'b0;
            similarity_start <= 1'b0;

            memory_write_addr <= 4'd0;

            for (i = 0; i < 16; i = i + 1)
                query_embedding[i] <= '0;

            busy <= 1'b0;
            done <= 1'b0;

        end

        else begin

            // ------------------------------------------
            // Default pulse signals
            // ------------------------------------------

            cnn_start        <= 1'b0;
            memory_write_en  <= 1'b0;
            similarity_start <= 1'b0;

            done <= 1'b0;


            case (state)

                // ======================================
                // IDLE
                // ======================================

                IDLE: begin

                    busy <= 1'b0;

                    if (store_ref_start) begin

                        busy  <= 1'b1;
                        state <= START_REFERENCE;

                    end

                end


                // ======================================
                // START REFERENCE CNN
                // ======================================

                START_REFERENCE: begin

                    cnn_start <= 1'b1;

                    state <= WAIT_REFERENCE;

                end


                // ======================================
                // WAIT FOR REFERENCE CNN
                // ======================================

                WAIT_REFERENCE: begin

                    if (cnn_done) begin

                        memory_write_addr <= 4'd0;

                        state <= STORE_REFERENCE;

                    end

                end


                // ======================================
                // STORE REFERENCE EMBEDDING
                // ======================================

                STORE_REFERENCE: begin

                    memory_write_en <= 1'b1;

                    if (memory_write_addr == 4'd15) begin

                        memory_write_addr <= 4'd0;

                        state <= WAIT_QUERY;

                    end

                    else begin

                        memory_write_addr <=
                            memory_write_addr + 1'b1;

                    end

                end


                // ======================================
                // WAIT FOR QUERY
                // ======================================

                WAIT_QUERY: begin

                    busy <= 1'b0;

                    if (query_start) begin

                        busy  <= 1'b1;

                        state <= START_QUERY;

                    end

                end


                // ======================================
                // START QUERY CNN
                // ======================================

                START_QUERY: begin

                    cnn_start <= 1'b1;

                    state <= WAIT_QUERY_CNN;

                end


                // ======================================
                // WAIT FOR QUERY CNN
                // ======================================

                WAIT_QUERY_CNN: begin

                    if (cnn_done) begin

                        // Capture query embedding

                        for (i = 0; i < 16; i = i + 1)
                            query_embedding[i] <=
                                cnn_embedding[i];

                        state <= START_SIMILARITY;

                    end

                end


                // ======================================
                // START SIMILARITY
                // ======================================

                START_SIMILARITY: begin

                    similarity_start <= 1'b1;

                    state <= WAIT_SIMILARITY;

                end


                // ======================================
                // WAIT FOR SIMILARITY
                // ======================================

                WAIT_SIMILARITY: begin

                    if (similarity_done) begin

                        state <= COMPLETE;

                    end

                end


                // ======================================
                // COMPLETE
                // ======================================

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