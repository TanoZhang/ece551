module plant_PID(clk,rst_n,drv_mag,error,not_pedaling,test_over);

  input clk,rst_n;
  input [11:0] drv_mag;
  output signed [12:0] error;
  output reg not_pedaling;
  output reg test_over;
  
  ////////////////////////////////////////
  // desired drive will be set and stepped
  // within the plant model 
  ////////////////////////////
  reg [11:0] desired_drive;
  
  ////////////////////////////////////////
  // Internal registers to plant model //
  //////////////////////////////////////
  reg [13:0] decimator;
  reg [14:0] avg_curr_accum;
  
  wire [11:0] avg_curr;
  
  initial begin
    test_over = 0;
	not_pedaling = 0;				// rider will be continuously pedaling for first two tests
    desired_drive = 12'h900;		// set desired drive to rather high level
	repeat(10000) @(posedge clk);	// wait for error to be calculated
	while (error>12'h00A) begin		// while the error is significant
	  @(posedge clk);				// we wait for loop to settle
	end
	
	repeat(10000) @(posedge clk);	// wait for error to be calculated
	desired_drive = 12'h400;		// now drop desired suddenly to less than half
	while (error<-12'h00A) begin	// while error still significant
	  @(posedge clk);				// we wait for loop to settle
	end

    desired_drive = 12'h900;		// go back to high desired drive
	repeat(10000) @(posedge clk);	// wait for error to be calculated
	while (error>12'h200) begin		// while the error is large
	  @(posedge clk);				// we wait for loop to settle and keep pedaling
	end	
	not_pedaling = 1;				// then rider stops pedaling (integral term in PID should reset)
	repeat(100000) @(posedge clk);	// rider not pedaling for 100k clocks
	not_pedaling = 0;				// rider resumes pedaling
	while (error>12'h00A) begin		// while the error is large
	  @(posedge clk);				// we wait for loop to settle and keep pedaling
	end		
	
	test_over = 1;
  end
  
  always @(posedge clk, negedge rst_n)
    if (!rst_n)
	  decimator <= 14'h00000;
	else
	  decimator <= decimator + 1;
	  
  always @(posedge clk, negedge rst_n)
    if (!rst_n)
      avg_curr_accum <= 15'h0000;
	else if (&decimator)
	  avg_curr_accum <= avg_curr*7 + drv_mag;
	  
  assign avg_curr = avg_curr_accum[14:3];
  
  assign error = {1'b0,desired_drive} - {1'b0,avg_curr};
	  

endmodule;  
