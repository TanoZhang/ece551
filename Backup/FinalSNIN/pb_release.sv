module PB_release (
    input  logic clk,
    input  logic rst_n,
    input  logic PB,
    output logic released
);

    // Three flip-flops used to synchronize the raw PB input
    logic pre1, pre2, pre3;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pre1 <= 1'b0;
            pre2 <= 1'b0;
            pre3 <= 1'b0;
        end
        else begin
            pre1 <= PB;    // 1st stage
            pre2 <= pre1;  // 2nd stage
            pre3 <= pre2;  // 3rd stage
        end
    end

    assign released = ~(pre2 || pre3);

endmodule