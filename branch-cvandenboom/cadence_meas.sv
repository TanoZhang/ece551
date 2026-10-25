module cadence_meas # (
    parameter FAST_SIM = 1
)(
    input clk, rst_n,
    input cadence_filt, 
    output logic [7:0] cadence_per
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
assign timerD = (cadence_rise) ? 24'b0 : // timer reset to 0 on cadence rise or rst
                (timerQ == THIRD_SEC) ? timerQ : 
                timerQ + 1'b1; // increment timer

// Freezes timer when it is == THIRD_SEC
always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
        timerQ <= 24'b0;
    else if (timerQ != THIRD_SEC)
        timerQ <= timerD;
end

assign capture_per = (timerQ == THIRD_SEC) && (cadence_rise);

// The input to the cadence_per register.
assign cadence_perD = (!rst_n) ? THIRD_SEC_UPPER :
                      (!capture_per) ? cadence_perD : // hold value
                      (FAST_SIM) ? timerQ[23:16] : 
                      timerQ[14:7];

// Cadence per register.
always_ff @(posedge clk) begin // no rst
    cadence_per <= cadence_perD; // capture cadence per
end

// not_pedaling output
assign not_pedaling = (THIRD_SEC_UPPER == cadence_per);

endmodule