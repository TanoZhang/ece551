module PB_intf (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        tgglMd,
    output logic [1:0]  setting,
    output logic [2:0]  scale,
    output logic [2:0]  LED
);

    logic tgglMd_F1, tgglMd_F2;

    // Rising edge detection
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tgglMd_F1 <= 0;
            tgglMd_F2 <= 0;
        end else begin
            tgglMd_F1 <= tgglMd;
            tgglMd_F2 <= tgglMd_F1;
        end
    end

    // Mode counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            setting <= 2'b10; // default to "normal"
        else if (tgglMd_F1 && !tgglMd_F2)
            setting <= setting + 2'd1;
    end

    // Output scale based on setting
    always_comb begin
        case (setting)
            2'b00: scale = 3'd0;  // off
            2'b01: scale = 3'd1;  // hard
            2'b10: scale = 3'd2;  // normal
            2'b11: scale = 3'd3;  // easy
        endcase

        // Optional: LED display matches setting
        LED = 1 << setting;
    end

endmodule