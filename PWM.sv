//
// PWM.sv - 11-bit Pulse Width Modulation (PWM) Generator
//
// This module generates a PWM signal based on an 11-bit counter (0-2047).
// - The duty cycle is set by the `duty` input (0 to 2047).
// - The PWM signal (`PWM_sig`) is HIGH when `counter < duty`, otherwise LOW.
// - The synchronization signal (`PWM_synch`) pulses HIGH when `counter == 1`.
// - The clock is 50 MHz, so one full PWM period lasts 40.96 s.
//
// The output `PWM_sig` is glitch-free, ensuring stable motor control.
//

module PWM (
    input logic clk,             // 50MHz system clock
    input logic rst_n,           // Active-low reset
    input logic [10:0] duty,     // 11-bit duty cycle input (range: 0 - 2047)

    output logic PWM_sig,        // PWM output (glitch-free)
    output logic PWM_synch       // Synchronization pulse (high when counter == 1)
);
    // 11-bit counter
    logic [10:0] counter;

    //======================================================
    // Counter and PWM Signal Generation
    //======================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 11'd0;
            PWM_sig <= 1'b0;
        end else begin
            if (counter == 11'd2047)  // Reset the counter at 2048
                counter <= 11'd0;
            else
                counter <= counter + 11'd1;
            
            // PWM signal generation
            PWM_sig <= (counter < duty);
        end
    end

    //======================================================
    // PWM Synchronization Signal
    //======================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            PWM_synch <= 1'b0;
        else
            PWM_synch <= (counter == 11'h001);  // Sync signal on counter == 1
    end

endmodule

