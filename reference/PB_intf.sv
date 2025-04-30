module PB_intf (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       tgglMd,         // async button input
    output logic [1:0] setting,        // 00=off, 01=low, 10=med, 11=max
    output logic [2:0] scale,          // torque scale for desiredDrive
    output logic [1:0] LED             // optional LED indicator
);

    // 3-flop synchronizer for tgglMd
    logic tgglMd_F1, tgglMd_F2, tgglMd_F3;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tgglMd_F1 <= 0;
            tgglMd_F2 <= 0;
            tgglMd_F3 <= 0;
        end else begin
            tgglMd_F1 <= tgglMd;
            tgglMd_F2 <= tgglMd_F1;
            tgglMd_F3 <= tgglMd_F2;
        end
    end

    // Rising edge detection
    wire rising_edge = tgglMd_F2 & ~tgglMd_F3;

    // 2-bit setting counter (wraps from 11 to 00)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            setting <= 2'b10; // default to medium
        else if (rising_edge)
            setting <= setting + 2'b01;
    end

    // LED output (mirrors setting)
    assign LED = setting;

    // Combinational mapping from setting to scale
    always_comb begin
        case (setting)
            2'b00: scale = 3'b000; // off
            2'b01: scale = 3'b011; // low
            2'b10: scale = 3'b101; // medium
            2'b11: scale = 3'b111; // max
        endcase
    end

endmodule
