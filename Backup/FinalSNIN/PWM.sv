module PWM (
    clk,
    rst_n,
    duty,
    PWM_sig,
    PWM_synch
);
  input clk, rst_n;
  input [10:0] duty;
  output logic PWM_sig, PWM_synch;

  //internal signal
  logic [10:0] counter;
  logic PWM_sig_in;

  //counter logic
  assign PWM_synch = (counter == 11'h001);
  always @(posedge clk or negedge rst_n)
    if (!rst_n) counter <= 11'h000;
    else counter <= counter + 1;

  //logic of output
  assign PWM_sig_in = !(counter > duty);
  always @(posedge clk or negedge rst_n)
    if (!rst_n) PWM_sig <= 0;
    else PWM_sig <= PWM_sig_in;

endmodule