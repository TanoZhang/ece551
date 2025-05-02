module hub_wheel_model(clk,rst_n,highGrn,lowGrn,highYlw,lowYlw,highBlu,
                       lowBlu,hallGrn,hallYlw,hallBlu,avg_curr);
					  
  input clk,rst_n;				// 50MHz clk and active low asynch reset
  input highGrn,lowGrn;			// MOSFET gate controls Green coil
  input highYlw,lowYlw;			// MOSFET gate controls Yellow coil
  input highBlu,lowBlu;			// MOSFET gate controls Blue coil
  output hallGrn,hallYlw,hallBlu;	// hall sensor outputs
  output [11:0] avg_curr;		// model of current consumed
  
  localparam FRICTION = 13'h070;
  
  reg signed [12:0] alpha;		// angular acceleration
  reg signed [19:0] omega;		// angular velocity
  reg [14:0] theta;				// angular position (0 to 359)*64
  reg [15:0] avg_curr_accum;
  
  wire signed [12:0] coilGY,coilYB,coilBG;
  wire [11:0] abs_coilGY,abs_coilYB,abs_coilBG;
  wire calc_physics;
  
  wire [2:0] rot_state; 		// {hallGrn,hallYlw,hallBlu} as a vector
  wire [8:0] pos;				// scaling of angular position used for hall outputs
  wire signed [15:0] new_theta;	// intermediate term for calculating theta
  logic signed [12:0] raw_torque;
  wire signed [12:0] net_torque;
  wire [18:0] omega_abs;
  wire [12:0] back_emf;			// opposing electrical voltage subtracted from coil voltage
  wire [19:0] avg_curr_prod;
  wire [11:0] sum_coil_v;
  wire [23:0] curr_omega_factor;
  wire [14:0] curr_factor; 
  
  
  /////////////////////////////////////////////////////////////////////
  // Instantiate inverse PWM block to get voltages applied to coils //
  ///////////////////////////////////////////////////////////////////
  coil_volt iCOIL(.clk(clk),.RST_n(rst_n),.highGrn(highGrn),.lowGrn(lowGrn),
                  .highYlw(highYlw),.lowYlw(lowYlw),.highBlu(highBlu),
                  .lowBlu(lowBlu),.coilGY(coilGY),.coilYB(coilYB),
				  .coilBG(coilBG),.calc_physics(calc_physics));
				  
  assign abs_coilGY = (coilGY[12]) ? -coilGY : coilGY;
  assign abs_coilYB = (coilYB[12]) ? -coilYB : coilYB;
  assign abs_coilBG = (coilBG[12]) ? -coilBG : coilBG;  
	
  assign avg_curr_prod = 15*avg_curr_accum;
  assign sum_coil_v = abs_coilGY + abs_coilYB + abs_coilBG;
  assign curr_omega_factor = sum_coil_v * (11'h200 + omega_abs[18:8]);
  assign curr_factor = curr_omega_factor[23:9];
  always @(posedge calc_physics, negedge rst_n)
    if (!rst_n)
      avg_curr_accum <= 16'h0000;
    else
      avg_curr_accum <= avg_curr_prod[19:4] + curr_factor; 
  assign avg_curr = avg_curr_accum[15:4];

  //////////////////////////////////////////////////////////////////////////
  // assign hall outputs according to pos(ition) which is based on theta //
  ////////////////////////////////////////////////////////////////////////
  assign pos = theta[14:6];
  assign rot_state = ((pos>=0) && (pos<60)) ? 3'b101 : 		// Green rise state
                     ((pos>=60) && (pos<120)) ? 3'b100 :	// 2nd state of Green
					 ((pos>=120) && (pos<180)) ? 3'b110 : 	// Yellow rise state
					 ((pos>=180) && (pos<240)) ? 3'b010 :	// 2nd state of Yellow
					 ((pos>=240) && (pos<300)) ? 3'b011 :	// Blue rise state
					 ((pos>=300) && (pos<360)) ? 3'b001 :	// 2nd state of Blue
                     3'bxxx;								// this should never happen
					 
  assign hallGrn = rot_state[2];
  assign hallYlw = rot_state[1];
  assign hallBlu = rot_state[0];
  
  /////////////////////////////////////////////////////////
  // Calculate angular position as integration of omega //
  // but with rollover from "359" to "0" ////////////////
  ////////////////////////////////////////
  assign new_theta = {1'b0,theta} + {{4{omega[19]}},omega[19:8]};
  
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  theta <= 15'd1920;		// start at 30*64 degrees (middle of Green rise state)
	else if (calc_physics)
	  if (new_theta[15])		// if negative wrap the other way
	    theta <= 15'd23040 + new_theta[14:0];
	  else if (new_theta>=16'd23040)	// if greater than full circle modulo it.
	    theta <= new_theta[14:0] - 15'd23040;
	  else
	    theta <= new_theta[14:0];

  /////////////////////////////////////////////////////////
  // Calculate angular velocity as integration of alpha //
  ///////////////////////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  omega <= 20'h000;
	else if (calc_physics)
	  omega <= omega + {{9{alpha[12]}},alpha[12:2]};
	  
  //////////////////////////////////////////////////////////////////////////////
  // Calculate torque based on current position and coil voltages & back_emf //
  ////////////////////////////////////////////////////////////////////////////
  assign omega_abs = (omega[19]) ? -omega : omega;
  assign back_emf = omega_abs[17:5];
  
  always_comb begin
    case (rot_state)
	  3'b101 : begin
	    if (coilGY>=0)
		  raw_torque = coilGY - back_emf;
		else if (coilGY<0)
		  raw_torque = coilGY + back_emf;
		else
		  raw_torque = 12'h000;
	  end
	  3'b100 : begin
	    if (coilBG<=0)
		  raw_torque = -coilBG - back_emf;
		else if (coilYB>0)
		  raw_torque = -coilYB + back_emf;
		else
		  raw_torque = 12'h000;
	  end
	  3'b110 : begin
	    if (coilYB>=0)
		  raw_torque = coilYB - back_emf;
		else if (coilBG<0)
		  raw_torque = coilBG + back_emf;
		else
		  raw_torque = 12'h000;
	  end
	  3'b010 : begin
	    if (coilGY<=0)
		  raw_torque = -coilGY - back_emf;
		else if (coilGY>0)
		  raw_torque = -coilGY + back_emf;
		else
		  raw_torque = 12'h000;
	  end
	  3'b011 : begin
	    if (coilBG>=0)
		  raw_torque = coilBG - back_emf;
		else if (coilYB<0)
		  raw_torque = coilYB + back_emf;
		else
		  raw_torque = 12'h000;
	  end
	  3'b001 : begin
	    if (coilYB<=0)
		  raw_torque = -coilYB - back_emf;
		else if (coilBG>0)
		  raw_torque = -coilBG + back_emf;
		else
		  raw_torque = 12'h000;
	  end	  
	endcase
  end
  
  ///////////////////////////////////////////////////////////
  // Now modify raw_torque based on friction and back_emf //
  /////////////////////////////////////////////////////////
  assign net_torque = (raw_torque > FRICTION) ? raw_torque - FRICTION :
                      (raw_torque < -FRICTION) ? raw_torque + FRICTION :
					  (omega>20'h00200) ? -FRICTION :
					  (omega<-20'h00200) ? FRICTION :
					  13'h000;
	
  assign alpha = {{1{net_torque[12]}},net_torque[12:1]};	
					  
  
endmodule
