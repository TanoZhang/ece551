module synch_detect_tb();	

reg clk;				// system clock
reg asynch_sig_in;		// models the asynchronous signal coming in

wire rise_edge;			// signal output from DUT

/////// Instantiate DUT /////////
synch_detect iDUT(.asynch_sig_in(asynch_sig_in), .clk(clk), .rise_edge(rise_edge));

always begin
  clk = 0;
  asynch_sig_in = 1;
  repeat(3) @(negedge clk);		// wait till 3rd falling clock edge
  asynch_sig_in = 0;
  repeat(2) @(posedge clk);
  #1;
  if (rise_edge) begin
    $display("ERROR: triggered on falling edge instead of rising\n");
	$stop();
  end
  @(posedge clk);
  asynch_sig_in = 1;
  
  @(posedge clk);				// wait a clock
  #1;
  if (rise_edge) begin
    $display("ERROR: triggering too early...did you double flop?\n");
	$stop();
  end
  @(posedge clk);
  #1;							// wait one time unit
  if (!rise_edge) begin
    $display("You should have detected rising edge here\n");
	$stop();
  end
  @(posedge clk);
  #1;							// wait one time unit
  if (rise_edge) begin
    $display("ERROR: Hmmm...should have dropped rise_edge by now\n");
    $stop();
  end
  $display("YAHOO!! test passed!\n");
  $stop();  
end

always
  #10 clk <= ~clk;		// toggle clock every 10 time units
  
endmodule