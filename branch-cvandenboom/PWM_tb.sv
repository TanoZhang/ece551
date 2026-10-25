//
// PWM_tb.sv
//
// This testbench verifies the functionality of the PWM module by applying 
// different duty cycles and observing the PWM output waveform.
//
// - A 50MHz clock is generated (20 ns period).
// - Various duty cycles (0%, 25%, 50%, 75%, 100%) are tested.
// - The simulation runs long enough to observe multiple PWM cycles (at least 500 µs).
//

module PWM_tb;
    // Testbench signals
    logic clk, rst_n;
    logic [10:0] duty;
    logic PWM_sig, PWM_synch;

    // Instantiate the PWM11 module
    PWM dut (
        .clk(clk),
        .rst_n(rst_n),
        .duty(duty),
        .PWM_sig(PWM_sig),
        .PWM_synch(PWM_synch)
    );

    // Clock generation (50 MHz)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;  // 50 MHz clock
    end

    // Test sequence
    initial begin
        rst_n = 0;  // Apply reset
        duty = 11'd0;  // Start with 0% duty cycle

        // Release reset
        #100 rst_n = 1;

	// Apply different duty cycles, holding each for 40.96 µs (one PWM period)
        #40960 duty = 11'd1024;  // 50% Duty Cycle
        #40960 duty = 11'd512;   // 25% Duty Cycle
        #40960 duty = 11'd1536;  // 75% Duty Cycle
        #40960 duty = 11'd0;     // 0% Duty Cycle
        #40960 duty = 11'd2047;  // 100% Duty Cycle

   
        #500000 $stop;  // End simulation
    end
endmodule

