module rst_synch(
    input clk,
    input RST_n,    // async reset input
    output logic rst_n  // synced reset output
);

// flop between stages
logic qq1;

always_ff @(negedge clk or negedge RST_n) begin
    if (!RST_n) begin
        qq1 <= 1'b0;
        rst_n <= 1'b0;
    end
    else begin
        qq1 <= 1'b1;
        rst_n <= qq1;
    end
end
endmodule