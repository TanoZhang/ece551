module cadence_filt_tb();

  ///////////////////////
  // Declare stimulus //
  /////////////////////
  logic clk,rst_n;
  logic cadence;
  
  ////////////////////////////////////////////
  // Declare signals to monitor DUT output //
  //////////////////////////////////////////
  wire cadence_filt, cadence_rise;
  
  //////////////////////
  // Instantiate DUT //
  ////////////////////
  cadence_filt iDUT(.clk(clk),.rst_n(rst_n),.cadence(cadence),
                    .cadence_filt(cadence_filt),.cadence_rise(cadence_rise));
					
  initial begin
    clk = 0;
	rst_n = 0;
	cadence = 0;		// start at zero
	@(negedge clk);
	rst_n = 1;
	
	repeat(65536) @(negedge clk);	// wait over 1ms
	if (cadence_filt!==1'b0) begin
	  $display("ERR: At time %t expect cadence_filt = 0, was %b",$time,cadence_filt);
	  $stop();
	end else
	  $display("GOOD: Passed first test");
	
	@(negedge clk);
	cadence = 1;		// change cadence
	repeat (10000) @(negedge clk);
	if (cadence_filt!==1'b0) begin
	  $display("ERR: At time %t cadence_filt should still be 0, was %b",$time,cadence_filt);
	  $stop();
	end else
	  $display("GOOD: Passed second test");
	 
	cadence = 0;		// bounce low
	repeat(10000) @(negedge clk);
	cadence = 1;
	repeat(10000) @(negedge clk);
	if (cadence_filt!==1'b0) begin
	  $display("ERR: At time %t cadence_filt should still be 0, was %b",$time,cadence_filt);
	  $stop();
	end else
	  $display("GOOD: Passed third test");
	  
	repeat(60000) @(negedge clk);
	if (cadence_filt!==1'b1) begin
	  $display("ERR: At time %t expect cadence_filt = 1, was %b",$time,cadence_filt);
	  $stop();
	end else
	  $display("GOOD: Passed fourth test");
    	
	///////////////////////////////////////////////

	@(negedge clk);
	cadence = 0;		// change cadence
	repeat (10000) @(negedge clk);
	if (cadence_filt!==1'b1) begin
	  $display("ERR: At time %t cadence_filt should still be 1, was %b",$time,cadence_filt);
	  $stop();
	end else
	  $display("GOOD: Passed fifth test");
	 
	cadence = 1;		// bounce high
	repeat(10000) @(negedge clk);
	cadence = 0;
	repeat(10000) @(negedge clk);
	if (cadence_filt!==1'b1) begin
	  $display("ERR: At time %t cadence_filt should still be 1, was %b",$time,cadence_filt);
	  $stop();
	end else
	  $display("GOOD: Passed sixth test");
	  
	repeat(60000) @(negedge clk);
	if (cadence_filt!==1'b0) begin
	  $display("ERR: At time %t expect cadence_filt = 0, was %b",$time,cadence_filt);
	  $stop();
	end else
	  $display("YAHOO! all tests passed");	
	
	$stop();
	
  end

  always
    #5 clk = ~clk;
	
endmodule