module HW4P6(clk,RST_n,A2D_SS_n,A2D_MOSI,A2D_SCLK,
             A2D_MISO,hallGrn,hallYlw,hallBlu,highGrn,
			 lowGrn,highYlw,lowYlw,highBlu,lowBlu,
			 brake_n,LED);
			 
  input clk;				// 50MHz clk
  input RST_n;				// active low RST_n from push button
  output A2D_SS_n;			// Slave select to A2D on DE0
  output A2D_SCLK;			// SPI clock to A2D on DE0
  output A2D_MOSI;			// serial output to A2D (what channel to read)
  input A2D_MISO;			// serial input from A2D
  input hallGrn;			// hall position input for "Green" phase
  input hallYlw;			// hall position input for "Yellow" phase
  input hallBlu;			// hall position input for "Blue" phase
  output highGrn;			// high side gate drive for "Green" phase
  output lowGrn;			// low side gate drive for "Green" phase
  output highYlw;			// high side gate drive for "Yellow" phase
  output lowYlw;			// low side gate drive for "Yellow" phas
  output highBlu;			// high side gate drive for "Blue" phase
  output lowBlu;			// low side gate drive for "Blue" phase
  input brake_n;			// if low means brakes applied
  output [7:0] LED;			// to 8 LEDs useful for debug purposes
  
  reg n000, rst_n;
  wire [11:0] throttle, drv_mag;
  wire [10:0] duty;
  wire [1:0] selGrn, selYlw, selBlu;

  
  assign drv_mag = throttle - 12'h260;	// slide pot has an offset
  
  //////////////////////////////////////////////////////////
  // Instantiation of your brushless DC motor controller //
  ////////////////////////////////////////////////////////
  brushless iBRSH(.clk(clk),.rst_n(rst_n),.drv_mag(drv_mag),.hallGrn(hallGrn),
            .hallYlw(hallYlw),.hallBlu(hallBlu),.duty(duty),.brake_n(1'b1),
			.selGrn(selGrn),.selYlw(selYlw),.selBlu(selBlu),.PWM_synch(PWM_synch));
	
  ///////////////////////////////
  // Instantiate motor driver //
  /////////////////////////////
  mtr_drv iMTR(.clk(clk),.rst_n(rst_n),.duty(duty),.selGrn(selGrn),
               .selYlw(selYlw),.selBlu(selBlu),.highGrn(highGrn),
			   .lowGrn(lowGrn),.highYlw(highYlw),.lowYlw(lowYlw),
			   .highBlu(highBlu),.lowBlu(lowBlu),.PWM_synch(PWM_synch));
			   
  /////////////////////////////////////////////
  // Instantiate throttle to read slide pot //
  ///////////////////////////////////////////
  throttle iSPD(.clk(clk),.rst_n(rst_n),.throttle(throttle),.SS_n(A2D_SS_n),
                .SCLK(A2D_SCLK),.MOSI(A2D_MOSI),.MISO(A2D_MISO)); 
 
  always_ff @(negedge clk, negedge RST_n)
    if (!RST_n) begin
	  n000 <= 1'b0;
	  rst_n <= 1'b0;
	end else begin
	  n000 <= 1'b1;
	  rst_n <= n000;
	end
	
  assign LED = drv_mag[11:4];	

endmodule
