module PWM(clk, rst_n, duty, PWM_sig, PWM_synch);
  input clk, rst_n;
  input [10:0] duty;

  output logic PWM_sig, PWM_synch;
  
  logic [10:0] cnt;
  logic PWM_sig_in;
  
  //counter logic
  assign PWM_synch = (cnt == 11'h001);
  always @(posedge clk or negedge rst_n)
    if (!rst_n)
      cnt <= 11'h000;
    else
      cnt <= cnt + 1;
  
  
  //output flop logic
  assign PWM_sig_in = !(cnt > duty);
  always @(posedge clk or negedge rst_n)
    if (!rst_n)
      PWM_sig <= 0;
    else 
	  PWM_sig <= PWM_sig_in;
	
 endmodule
  