//
// nonoverlap.sv - Ensures non-overlapping PWM signals for MOSFET gate drivers
//
// - When `highIn` or `lowIn` change, both outputs go LOW for 32 clock cycles.
// - After the dead time, outputs take their respective input values.
// - Prevents shoot-through currents in power MOSFETs.
//

module nonoverlap (
    input  logic clk,          // 50MHz system clock
    input  logic rst_n,        // Active-low reset
    input  logic highIn,       // Input for high-side FET
    input  logic lowIn,        // Input for low-side FET
    output logic highOut,      // Output for high-side FET (non-overlapping)
    output logic lowOut        // Output for low-side FET (non-overlapping)
);

    // Dead-time counter (5-bit counter to count 32 cycles)
    logic [5:0] deadTimeCounter;
    logic       deadTime;  // Flag indicating deadTime period

    // Detect a change in input signals
    logic highIn_prev, lowIn_prev;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            highIn_prev <= 0;
            lowIn_prev  <= 0;
        end else begin
            highIn_prev <= highIn;
            lowIn_prev  <= lowIn;
        end
    end

    wire input_changed = (highIn_prev != highIn) || (lowIn_prev != lowIn);


    // Dead-time logic: both outputs LOW for 32 cycles on input change
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            deadTimeCounter <= 6'd0;
            deadTime    <= 1'b0;
        end else if (input_changed) begin
            deadTimeCounter <= 6'd32;  // Set counter to 32 cycles
            deadTime    <= 1'b1;   // Enter dead-time phase
        end else if (deadTimeCounter > 0) begin
            deadTimeCounter <= deadTimeCounter - 1'd1; // Count down
        end else if (deadTimeCounter == 0)begin
            deadTime <= 1'b0;  // Exit dead-time phase after 32 cycles
        end
    end

    // Output logic: Hold LOW during dead time, then follow inputs
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            highOut <= 1'b0; //reset output
            lowOut  <= 1'b0;
        end else if (deadTime) begin
            highOut <= 1'b0; //force output to be 0 during deadtime
            lowOut  <= 1'b0;
        end else begin
            highOut <= highIn; //take value from input directly when not in dead time
            lowOut  <= lowIn;
        end
    end

endmodule

