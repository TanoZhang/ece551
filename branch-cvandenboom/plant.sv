module plant(clk,rst_n,drv_duty,avg_curr);

  //////////////////////////////////////////////
  // This plant model is just a stupid average
  // of the last 128 samples of the control
  // input.  It is just a plant with some
  // lag so it would show some overshoot
  ///////////////////////////////////////
  input clk;
  input rst_n;
  input [11:0] drv_duty;
  output [11:0] avg_curr;
  
  reg [11:0]dly_mem[0:255];		// used for circular queue to delay response
  
  reg [19:0] accum;
  reg [7:0] new_ptr,old_ptr;
  reg full;						// set once queue is full
  
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  new_ptr <= 8'h00;
	else
	  new_ptr <= new_ptr + 1;
	  
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  old_ptr <= 8'h00;
	else if (full)
	  old_ptr <= old_ptr + 1;

 always_ff @(posedge clk, negedge rst_n)
   if (!rst_n)
     full <= 1'b0;
   else if (&new_ptr)
     full <= 1'b1;   
	 
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  accum <= 20'h00000;
	else
	  accum <= (full) ? accum + drv_duty - dly_mem[old_ptr] : accum + drv_duty;
	 
  always_ff @(posedge clk)
    dly_mem[new_ptr] <= drv_duty;
	
  assign avg_curr = accum[19:8];	// running average of last 256
  
endmodule
	  