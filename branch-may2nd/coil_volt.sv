/////////////////////////////////////////////
// Given the PWM input of the 6 FETs gates //
// this module derives the coil voltage of //
// each coil.  Used in modeling hub motor. //
/////////////////////////////////////////////
module coil_volt(clk,RST_n,highGrn,lowGrn,highYlw,lowYlw,highBlu,
                  lowBlu,coilGY,coilYB,coilBG,calc_physics);
  input clk,RST_n;
  input highGrn,lowGrn;
  input highYlw,lowYlw;
  input highBlu,lowBlu;
  output signed [12:0] coilGY;	// represents current in GY coil
  output signed [12:0] coilYB;	// represents current in GY coil
  output signed [12:0] coilBG; 	// represents current in GY coil
  output reg calc_physics;				// indicates new valid reading of coils

  reg [10:0] PWM_per_cnt;
  reg [10:0] HG_cnt,LG_cnt,HY_cnt,LY_cnt,HB_cnt,LB_cnt;
  reg [10:0] HG_dty,LG_dty,HY_dty,LY_dty,HB_dty,LB_dty;
  reg HG_ff1,LG_ff1,HY_ff1,LY_ff1,HB_ff1,LB_ff1; 
  
  wire HG_rise,HG_fall,LG_rise,LG_fall,HY_rise,HY_fall,HB_rise,HB_fall;
  wire period_over;
 
  
  ///////////////////////////////////////////////
  // Implement period counter for inverse PWM //
  /////////////////////////////////////////////
  always_ff @(posedge clk, negedge RST_n)
    if (!RST_n)
	  PWM_per_cnt <= 11'h000;
	else
	  PWM_per_cnt <= PWM_per_cnt + 1;
	  
  assign period_over = &PWM_per_cnt;
  
  ////////////////////////////////////////////////////
  // implement duty cycle counters for all 6 gates //
  //////////////////////////////////////////////////
  always_ff @(posedge clk, negedge RST_n)
    if (!RST_n)
	  HG_cnt <= 11'h000;
	else if (period_over)
	  HG_cnt <= 11'h000;
	else if (highGrn)
	  HG_cnt <= HG_cnt + 1;

  always_ff @(posedge clk, negedge RST_n)
    if (!RST_n)
	  LG_cnt <= 11'h000;
	else if (period_over)
	  LG_cnt <= 11'h000;
	else if (lowGrn)
	  LG_cnt <= LG_cnt + 1;

  always_ff @(posedge clk, negedge RST_n)
    if (!RST_n)
	  HY_cnt <= 11'h000;
	else if (period_over)
	  HY_cnt <= 11'h000;
	else if (highYlw)
	  HY_cnt <= HY_cnt + 1;

  always_ff @(posedge clk, negedge RST_n)
    if (!RST_n)
	  LY_cnt <= 11'h000;
	else if (period_over)
	  LY_cnt <= 11'h000;
	else if (lowYlw)
	  LY_cnt <= LY_cnt + 1;

  always_ff @(posedge clk, negedge RST_n)
    if (!RST_n)
	  HB_cnt <= 11'h000;
	else if (period_over)
	  HB_cnt <= 11'h000;
	else if (highBlu)
	  HB_cnt <= HB_cnt + 1;

  always_ff @(posedge clk, negedge RST_n)
    if (!RST_n)
	  LB_cnt <= 11'h000;
	else if (period_over)
	  LB_cnt <= 11'h000;
	else if (lowBlu)
	  LB_cnt <= LB_cnt + 1;	 

  //////////////////////////////////////////////////////////
  // Implement capture registers to get duty as a vector // 
  ////////////////////////////////////////////////////////
  always_ff @(posedge clk, negedge RST_n)
    if (!RST_n)
      HG_dty <= 11'h000;
    else if (period_over)
      HG_dty <= HG_cnt;

  always_ff @(posedge clk, negedge RST_n)
    if (!RST_n)
      LG_dty <= 11'h000;
    else if (period_over)
      LG_dty <= LG_cnt;

  always_ff @(posedge clk, negedge RST_n)
    if (!RST_n)
      HY_dty <= 11'h000;
    else if (period_over)
      HY_dty <= HY_cnt;

  always_ff @(posedge clk, negedge RST_n)
    if (!RST_n)
      LY_dty <= 11'h000;
    else if (period_over)
      LY_dty <= LY_cnt;

  always_ff @(posedge clk, negedge RST_n)
    if (!RST_n)
      HB_dty <= 11'h000;
    else if (period_over)
      HB_dty <= HB_cnt;

  always_ff @(posedge clk, negedge RST_n)
    if (!RST_n)
      LB_dty <= 11'h000;
    else if (period_over)
      LB_dty <= LB_cnt;	  
	  
  ///////////////////////////////////////////////////////
  // New readings are valid a cycle after period_over //
  /////////////////////////////////////////////////////
  always_ff @(posedge clk, negedge RST_n)
    if (!RST_n)
	  calc_physics <= 1'b0;
	else
	  calc_physics <= period_over;

  ///////////////////////////////////////////////////////////
  // Now based on gate drives establish each coil voltage //
  /////////////////////////////////////////////////////////
  assign coilGY = (((HG_dty<11'h3FF) && (LG_dty<11'h3FF)) |  	// coil undriven at one end
	               ((HY_dty<11'h3FF) && (LY_dty<11'h3FF))) ? 13'h000 :
				  ({2'b00,HG_dty} - {2'b00,LG_dty}) - ({2'b00,HY_dty} - {2'b00,LY_dty});

  assign coilYB = (((HY_dty<11'h3FF) && (LY_dty<11'h3FF)) |  	// coil undriven at one end
	               ((HB_dty<11'h3FF) && (LB_dty<11'h3FF))) ? 13'h000 :
				  ({2'b00,HY_dty} - {2'b00,LY_dty}) - ({2'b00,HB_dty} - {2'b00,LB_dty});

  assign coilBG = (((HB_dty<11'h3FF) && (LB_dty<11'h3FF)) |  	// coil undriven at one end
	               ((HG_dty<11'h3FF) && (LG_dty<11'h3FF))) ? 13'h000 :
				  ({2'b00,HB_dty} - {2'b00,LB_dty}) - ({2'b00,HG_dty} - {2'b00,LG_dty});
				  	
endmodule
