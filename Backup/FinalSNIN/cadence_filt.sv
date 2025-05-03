/******************************************************
 * File: cadence_filt
 * 
 * Description:
 * - Debounce filter for cadence signal.
 * - Synchronizes noisy cadence input.
 * - Uses multi-stage flop and stability counter.
 * - Outputs stable cadence (`cadence_filt`).
 * - Generates `cadence_rise` pulse on rising edge.
 *
 ******************************************************/

module cadence_filt #(
    parameter FAST_SIM = 1
) (
    input  logic clk,           // 50MHz system clock
    input  logic rst_n,         // Active-low asynchronous reset
    input  logic cadence,       // Noisy raw cadence signal (bouncy and asynchronous)
    output logic cadence_filt,  // Debounced and stable cadence output
    output logic cadence_rise   // Pulse indicating a rising edge in cadence
);

  // Internal flip-flop signals for synchronization
  logic q1, q2, q3;  // Flip-flops to sync cadence signal
  logic        n_updated;  // High when cadence is stable
  logic [15:0] stability_cntr;  // Stability counter
  logic        cnt_full;  //   Counter full flag


  // Stability counter width
  generate
    if (FAST_SIM) assign cnt_full = &stability_cntr[8:0];
    else assign cnt_full = &stability_cntr;
  endgenerate

  // capture raw cadence
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) q1 <= 1'b0;
    else q1 <= cadence;
  end

  // metastability for cadence signal.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) q2 <= 1'b0;
    else q2 <= q1;
  end
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) q3 <= 1'b0;
    else q3 <= q2;
  end

  // Detect rising edge and stability of cadence signal
  always_comb begin
    cadence_rise = q2 & ~q3;
    n_updated = ~(q2 ^ q3);
  end

  // stability counter
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) stability_cntr <= 16'h0000;  // Reset counter
    else if (n_updated) stability_cntr <= stability_cntr + 1'b1;  // Increment if stable
    else stability_cntr <= 16'h0000;  // Reset if cadence changes
  end

  // update cadence_filt when timer is full
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) cadence_filt <= 1'b0;
    else if (cnt_full) cadence_filt <= q3;
    else cadence_filt <= cadence_filt;
  end

endmodule
