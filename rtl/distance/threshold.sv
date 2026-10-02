`timescale 1ns/1ps

module threshold #(
    parameter DIST_W = 40
)(
    input  logic signed [DIST_W-1:0] distance,
    input  logic signed [DIST_W-1:0] threshold_value,

    output logic similar
);

    always_comb begin
        if (distance <= threshold_value)
            similar = 1'b1;
        else
            similar = 1'b0;
    end

endmodule