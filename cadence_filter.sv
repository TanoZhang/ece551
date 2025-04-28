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

module cadence_filt (
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

    /***********************************************
     * First Flip-Flop Stage: Synchronization
     * - Captures the raw cadence input.
     * - Helps mitigate metastability issues.
     ***********************************************/
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q1 <= 1'b0; // Reset on active low
        else
            q1 <= cadence; // Capture the cadence input
    end

    /***********************************************
     * Second Flip-Flop Stage: Additional Synchronization
     * - Further stabilizes the cadence signal.
     ***********************************************/
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q2 <= 1'b0;
        else
            q2 <= q1; // Shift input from q1
    end

    /***********************************************
     * Third Flip-Flop Stage: Delayed Version
     * - Used to detect changes in cadence.
     ***********************************************/
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q3 <= 1'b0;
        else
            q3 <= q2; // Shift input from q2
    end

    /***********************************************
     * Combinational Logic:
     * - `cadence_rise`: Generates a pulse when `q2` transitions from 0 to 1.
     * - `chngd_n`: Detects whether cadence has remained stable.
     ***********************************************/
    always_comb begin
        cadence_rise = q2 & ~q3;  // Rising edge detection
        chngd_n = ~(q2 ^ q3);     // Stability check (XNOR operation)
    end

    /***********************************************
     * Stability Counter:
     * - Increments if the cadence signal remains unchanged.
     * - Resets when cadence changes.
     ***********************************************/
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            stbl_cnt <= 16'h0000; // Reset counter
        else if (chngd_n)
            stbl_cnt <= stbl_cnt + 1'b1; // Increment if stable
        else
            stbl_cnt <= 16'h0000; // Reset if cadence changes
    end

    /***********************************************
     * Stable Cadence Output:
     * - Updates `cadence_filt` when the counter reaches its max value.
     ***********************************************/
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cadence_filt <= 1'b0; // Reset stable cadence signal
        else if (&stbl_cnt)  // If all bits of stbl_cnt are 1 (stability threshold reached)
            cadence_filt <= q3; // Update with stabilized cadence value
        else
            cadence_filt <= cadence_filt; // Hold previous value
    end

endmodule
