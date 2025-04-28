module PB_rise (
    input clk,
    input rst_n,        // Asynch preset signal
    input PB,
    output logic rise
);

// intermediate signal between flops
logic q1, q2, q3;

// Combinational output.
assign rise = ~q3 & q2;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        q1 <= 1'b1;
        q2 <= 1'b1;
        q3 <= 1'b1;
    end
    else begin
        q1 <= PB;
        q2 <= q1;
        q3 <= q2;
    end
end
endmodule