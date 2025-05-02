module rst_synch(
    input clk,
    input RST_n,
    output logic rst_n
);
// intermediate signal between flops
logic q1;

always_ff @(negedge clk or negedge RST_n) begin
    if (!RST_n) begin
        q1 <= 1'b0;
        rst_n <= 1'b0;
    end
    else begin
        q1 <= 1'b1;
        rst_n <= q1;
    end
end

endmodule
