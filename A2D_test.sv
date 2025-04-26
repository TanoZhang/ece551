module A2D_test(clk,RST_n,SEL,LED,SCLK,a2d_SS_n,MOSI,MISO,
                highGrn,lowGrn,highYlw,lowYlw,highBlu,lowBlu);

  input clk,RST_n;		// clk and unsynched reset from PB
  input SEL;			// from 2nd PB, cycle through outputs
  input MISO;			// from A2D
  
  output [7:0] LED;
  output a2d_SS_n;			// active low slave select to A2D
  output SCLK;			// SCLK to A2D SPI
  output MOSI;
  ///// Need to ensure following are always driven low ////
  output highGrn,lowGrn;
  output highYlw,lowYlw;
  output highBlu,lowBlu;
  
  reg [1:0] cnt2;
  
  wire en_2bit;
  wire rst_n;
  wire [11:0] batt,curr,brake,torque;

  /// Ensure all power FETs off ////
  assign highGrn = 1'b0;
  assign lowGrn = 1'b0;
  assign highYlw = 1'b0;
  assign lowYlw = 1'b0;
  assign highBlu = 1'b0;
  assign lowBlu = 1'b0;
  ////////////////////////////////////////////////////////////////
  // Infer 2-bit counter to select which output to map to LEDs //
  //////////////////////////////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  cnt2 <= 2'b00;
	else if (en_2bit)
	  cnt2 <= cnt2 + 1;
	  
  ////////////////////////////////////////////////
  // Mux to select which output to map to LEDs //
  //////////////////////////////////////////////  
  assign LED = (cnt2==2'b00) ? batt[11:4] :
               (cnt2==2'b01) ? curr[11:4] :
			   (cnt2==2'b10) ? brake[11:4] :
			   torque[11:4];
	
  //////////////////////
  // Instantiate DUT //
  ////////////////////  
  A2D_intf iDUT(.clk(clk),.rst_n(rst_n),.batt(batt),
                .curr(curr),.brake(brake),.torque(torque),
				.SS_n(a2d_SS_n),.SCLK(SCLK),
				.MOSI(MOSI),.MISO(MISO));

			   
  ///////////////////////////////////////////////
  // Instantiate Push Button release detector //
  /////////////////////////////////////////////
  PB_rise iPB(.clk(clk),.rst_n(rst_n),.PB(SEL),.rise(en_2bit));
  
  /////////////////////////////////////
  // Instantiate reset synchronizer //
  ///////////////////////////////////
  rst_synch iRST(.clk(clk),.RST_n(RST_n),.rst_n(rst_n));   
	  
endmodule
  