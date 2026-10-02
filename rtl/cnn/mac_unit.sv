module mac_unit (
    input  logic        clk,
    input  logic        rst,

    // Control
    input  logic        clear_acc,
    input  logic        en,

    // Signed INT8 inputs
    input  logic signed [7:0] pixel,
    input  logic signed [7:0] weight,

    // Signed accumulator output
    output logic signed [31:0] acc_out
);

    // 8-bit × 8-bit = 16-bit product
    logic signed [15:0] product;

    assign product = pixel * weight;

    always_ff @(posedge clk) begin
        if (rst) begin
            acc_out <= 32'sd0;
        end
        else if (clear_acc) begin
            acc_out <= 32'sd0;
        end
        else if (en) begin
            acc_out <= acc_out + {{16{product[15]}}, product};
        end
    end

endmodule