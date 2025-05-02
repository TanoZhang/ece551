/******************************************************
 * File: cadence_filt
 * 
 * Description:
 * - Implements a digital **debounce filter** for a cadence signal.
 * - Synchronizes the asynchronous **bouncy** cadence input.
 * - Ensures stability by using a **multi-stage flip-flop design**.
 * - Generates a **stable cadence signal (`cadence_filt`)**.
 * - Detects rising edges with **`cadence_rise`** for event triggering.
 *
 ******************************************************/

module cadence_filt # (
    parameter FAST_SIM = 1
)(
    input  logic clk,          // 50MHz system clock
    input  logic rst_n,        // Active-low asynchronous reset
    input  logic cadence,      // Noisy raw cadence signal (bouncy and asynchronous)
    output logic cadence_filt, // Debounced and stable cadence output
    output logic cadence_rise  // Pulse indicating a rising edge in cadence
);

    // Internal flip-flop signals for synchronization
    logic q1, q2, q3;
    logic chngd_n;            // Signal to detect stability of cadence
    logic [15:0] stbl_cnt;    // Counter to ensure cadence stability
	logic cnt_full;            //
	
	generate if (FAST_SIM)
		assign cnt_full = &stbl_cnt[8:0];
	else
		assign cnt_full = &stbl_cnt;
	endgenerate
    
    // capture raw cadence signal
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q1 <= 1'b0;
        else
            q1 <= cadence; 
    end

    // metastability for cadence signal. 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q2 <= 1'b0;
        else
            q2 <= q1;
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q3 <= 1'b0;
        else
            q3 <= q2; 
    end

    // Detect rising edge and stability of cadence signal
    always_comb begin
        cadence_rise = q2 & ~q3; 
        chngd_n = ~(q2 ^ q3);    
    end

    // stability counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            stbl_cnt <= 16'h0000; // Reset counter
        else if (chngd_n)
            stbl_cnt <= stbl_cnt + 1'b1; // Increment if stable
        else
            stbl_cnt <= 16'h0000; // Reset if cadence changes
    end

    // update cadence_filt when timer is full
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cadence_filt <= 1'b0;
        else if (cnt_full) 
            cadence_filt <= q3; 
        else
            cadence_filt <= cadence_filt;
    end

endmodule
