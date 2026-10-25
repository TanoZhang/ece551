module brushless_mtr_drv_tb2();

  /// stimulus declared as type reg;
  reg clk, rst_n;
  reg [11:0] drv_mag;
  reg brake_n;
  
  /// internal signals ///
  wire PWM_synch;
  wire [10:0] duty;
  wire [1:0] selGrn,selYlw,selBlu;
  wire highGrn,lowGrn;
  wire highYlw,lowYlw;
  wire highBlu,lowBlu;
  wire hallGrn,hallYlw,hallBlu;
  
  ////////////////////////////////
  // Instantiate brushless DUT //
  //////////////////////////////
  brushless DUT1(.clk(clk),.rst_n(rst_n),.drv_mag(drv_mag),
                 .PWM_synch(PWM_synch),.hallGrn(hallGrn),
				 .hallYlw(hallYlw),.hallBlu(hallBlu),
				 .brake_n(brake_n),.duty(duty),.selGrn(selGrn),
				 .selYlw(selYlw),.selBlu(selBlu));	

  //////////////////////////////
  // Instantiate mtr_drv DUT //
  ////////////////////////////	
  mtr_drv DUT2(.clk(clk),.rst_n(rst_n),.duty(duty),.selGrn(selGrn),
               .selYlw(selYlw),.selBlu(selBlu),.highGrn(highGrn),
			   .lowGrn(lowGrn),.highYlw(highYlw),.lowYlw(lowYlw),
			   .highBlu(highBlu),.lowBlu(lowBlu),.PWM_synch(PWM_synch));
			   
  //////////////////////////////////////////////
  // Instantiate Model of Coil Drive & Motor //
  ////////////////////////////////////////////	
  hub_wheel_model iMDL(.clk(clk),.rst_n(rst_n),.highGrn(highGrn),.lowGrn(lowGrn),
                       .highYlw(highYlw),.lowYlw(lowYlw),.highBlu(highBlu),
                       .lowBlu(lowBlu),.hallGrn(hallGrn),.hallYlw(hallYlw),
					   .hallBlu(hallBlu),.avg_curr());
			   
  initial begin
    clk = 0;
	rst_n = 0;
	drv_mag = 12'h7FF; 	// 50% duty
	brake_n = 1;

    @(negedge clk);
	rst_n = 1;
	
	repeat(1000000) @(posedge clk);
	$stop();
	
  end

  always
    #5 clk = ~clk;  
				 
endmodule