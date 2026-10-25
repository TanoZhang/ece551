module PID_cntrl_tb();

  reg clk, rst_n;
  reg [11:0] target_curr;
  
  wire [11:0] avg_curr;		// average consumption of plant
  wire [11:0] drv_duty;		// from PID controller to plant
  
  /////////////////////////////////
  // Instantiate PID controller //
  ///////////////////////////////
  PID iCNTRL(.clk(clk),.rst_n(rst_n),.target_curr(target_curr),
             .avg_curr(avg_curr),.drv_duty(drv_duty));

  /////////////////////////////////
  // Instantiate model of plant //
  ///////////////////////////////			 
  plant iPLNT(.clk(clk),.rst_n(rst_n),.drv_duty(drv_duty),
              .avg_curr(avg_curr));
			  
  initial begin
    clk = 0;
	rst_n = 0;
	target_curr = 12'h000;
	//// wait 1.5 clocks for reset ////
	@(posedge clk);
	@(negedge clk) rst_n = 1;
	
	//// step function increase in target (desired) current ////
	repeat(100) @(negedge clk);
	target_curr = 12'h800;
	
	//// just wait a bunch of time for response of PID loop ////
	repeat(5000) @(posedge clk);
	
	$stop();
  end
  
  always
    #5 clk = ~clk;
  
endmodule