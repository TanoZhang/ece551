`timescale 1ns/1ps

module cadence_meas_tb();
  // Parameters
  parameter CLK_PERIOD = 10;  // 10 ns clock period (100 MHz)
  
  // TestBench Signals
  logic clk, rst_n;
  logic cadence_filt;
  logic [7:0] cadence_per;
  logic not_pedaling;
  
  // Instantiate the DUT (Device Under Test)
  cadence_meas #(
    .FAST_SIM(1)  // Use fast simulation mode
  ) DUT (
    .clk(clk),
    .rst_n(rst_n),
    .cadence_filt(cadence_filt),
    .cadence_per(cadence_per),
    .not_pedaling(not_pedaling)
  );
  
  // Clock generation
  always begin
    clk = 1'b0;
    #(CLK_PERIOD/2);
    clk = 1'b1;
    #(CLK_PERIOD/2);
  end
  
  // Test stimulus
  initial begin
    // Initialize signals
    rst_n = 1'b0;
    cadence_filt = 1'b0;
    
    // Reset sequence
    #(CLK_PERIOD*5);
    rst_n = 1'b1;
    #(CLK_PERIOD*5);
    
    // Test Case 1: Normal pedaling (faster cadence)
    $display("Test Case 1: Normal pedaling with faster cadence");
    repeat(5) begin
      // Create cadence pulses at 500 clock cycles apart (5 ?s)
      cadence_filt = 1'b1;
      #(CLK_PERIOD*2);
      cadence_filt = 1'b0;
      #(CLK_PERIOD*498);
    end
    
    // Wait to see if not_pedaling is deasserted
    #(CLK_PERIOD*1000);
    $display("not_pedaling = %b, cadence_per = %h", not_pedaling, cadence_per);
    
    // Test Case 2: Slower pedaling
    $display("Test Case 2: Slower pedaling");
    repeat(3) begin
      // Create cadence pulses at 2000 clock cycles apart (20 ?s)
      cadence_filt = 1'b1;
      #(CLK_PERIOD*2);
      cadence_filt = 1'b0;
      #(CLK_PERIOD*1998);
    end
    
    // Wait to see if not_pedaling is still deasserted
    #(CLK_PERIOD*1000);
    $display("not_pedaling = %b, cadence_per = %h", not_pedaling, cadence_per);
    
    // Test Case 3: No pedaling (timeout)
    $display("Test Case 3: No pedaling (timeout)");
    
    // Wait for THIRD_SEC_FAST time to elapse (for FAST_SIM=1, this is 0x7271 clock cycles)
    #(CLK_PERIOD*30000);
    
    // Check if not_pedaling is asserted
    $display("not_pedaling = %b, cadence_per = %h", not_pedaling, cadence_per);
    
    // Test Case 4: Resume pedaling after timeout
    $display("Test Case 4: Resume pedaling after timeout");
    repeat(3) begin
      cadence_filt = 1'b1;
      #(CLK_PERIOD*2);
      cadence_filt = 1'b0;
      #(CLK_PERIOD*998);
    end
    
    // Check if not_pedaling is deasserted again
    #(CLK_PERIOD*1000);
    $display("not_pedaling = %b, cadence_per = %h", not_pedaling, cadence_per);
    
    // End simulation
    $display("Simulation completed");
    #(CLK_PERIOD*1000);
    $finish;
  end
  
  // Monitor signals for debugging
  initial begin
    $monitor("Time = %t, rst_n = %b, cadence_filt = %b, cadence_per = %h, not_pedaling = %b", 
             $time, rst_n, cadence_filt, cadence_per, not_pedaling);
  end
  
endmodule
