module cadence_meas # (
    parameter FAST_SIM = 1
)(
    input clk, rst_n,
    input cadence_filt, 
    output logic [7:0] cadence_per,
    output logic not_pedaling   // Adding this to the port list
);

// 24 bit timer
logic [23:0] timerD, timerQ;
logic cadence_rise;       // Rising edge
logic [7:0] cadence_perD; // cadence per register input

logic cadence_filt_d;

logic capture_per; // capture cadence per register

logic [23:0] THIRD_SEC; // 3 sec timer value
localparam THIRD_SEC_REAL = 24'hE4E1C0;
localparam THIRD_SEC_FAST = 24'h007271; // 0.5 sec for fast simulation
localparam THIRD_SEC_UPPER = 8'hE4;

generate if (FAST_SIM)
    assign THIRD_SEC = THIRD_SEC_FAST;
else
    assign THIRD_SEC = THIRD_SEC_REAL;
endgenerate

// rise detection logic
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
        cadence_filt_d <= 1'b0;
        cadence_rise <= 1'b0;
    end else begin
        cadence_filt_d <= cadence_filt;
        cadence_rise <= cadence_filt & ~cadence_filt_d; // rising edge detection
    end
end

// The input to the timer.
assign timerD = (!rst_n) ? 24'b0:     // Reset timer on rst_n
                (cadence_rise) ? 24'b0 : // timer reset to 0 on cadence rise
                (timerQ == THIRD_SEC) ? timerQ : 
                timerQ + 1'b1; // increment timer

// Freezes timer when it is == THIRD_SEC
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        timerQ <= 24'b0;
    else
        timerQ <= timerD;   // Remove condition to allow reset on cadence_rise
end

assign capture_per = cadence_rise;   // Capture on rising edge

// The input to the cadence_per register.
assign cadence_perD = (!rst_n) ? THIRD_SEC_UPPER :
                      (!capture_per) ? cadence_per : // Hold current value if not capturing
                      (timerQ == THIRD_SEC) ? THIRD_SEC_UPPER : // If timer reached max, use UPPER value
                      (FAST_SIM) ? timerQ[14:7] :    // For fast sim, use bits [14:7]
                      timerQ[23:16];                // For real time, use bits [23:16]

// Cadence per register.
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        cadence_per <= THIRD_SEC_UPPER;
    else
        cadence_per <= cadence_perD; // capture cadence per
end

// not_pedaling output - asserted when timer reaches THIRD_SEC or cadence_per equals THIRD_SEC_UPPER
assign not_pedaling = (cadence_per == THIRD_SEC_UPPER);

endmodule