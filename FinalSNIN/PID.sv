module PID (
    clk,
    rst_n,
    error,
    not_pedaling,
    drv_mag
);

  input clk, rst_n, not_pedaling;
  input signed [12:0] error;
  output logic [11:0] drv_mag;
  parameter FAST_SIM = 1;

  // Internal signals
  logic [8:0] D_saturation;
  logic [12:0] flipflop1, flipflop2, flipflop3, dffD;
	logic [13:0] P_term, I_term, D_term, D_term_in, PID_term;
  logic [17:0] integrator, intg_in, error_se, error_added, error_sat;
  logic [19:0] cntr;
  logic signed [12:0] error_ff;
  logic [11:0] drv_mag_in;
  logic positions, FullDecimator;

  // Decimator logic
  generate
    if (FAST_SIM) begin
      assign FullDecimator = &cntr[14:0];
    end else begin
      assign FullDecimator = &cntr;
    end
  endgenerate

  assign error_se = {{5{error[12]}}, error};
  assign error_added = error_se + integrator;
  assign positions = integrator[16] & error_added[17];
  assign error_sat = positions ? 18'h1FFFF : error_added[17] ? 18'h00000 : error_added;
  assign intg_in = not_pedaling ? 18'h00000 : FullDecimator ? error_sat : integrator;

  //counter logic
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n) cntr <= 20'h00000;
    else cntr <= cntr + 1;

  //integrator flipflop
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n) integrator <= 18'h00000;
    else integrator <= intg_in;

  //logic of Dterm
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      flipflop1 <= 13'h00000;
      flipflop2 <= 13'h00000;
      flipflop3 <= 13'h00000;
    end else if (FullDecimator) begin
      flipflop1 <= error[12:0];
      flipflop2 <= flipflop1;
      flipflop3 <= flipflop2;
    end else begin
      flipflop1 <= flipflop1;
      flipflop2 <= flipflop2;
      flipflop3 <= flipflop3;
    end
  end
  //pipeline - for error
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n) error_ff <= 12'h000;
		else error_ff <= error;
  // Derivative = current error - delayed error
  assign dffD = error_ff - flipflop3;
  assign D_saturation = (dffD[12] & ~&(dffD[11:9])) ? 9'b100000000 : (~dffD[12] & |(dffD[11:9])) ? 9'b011111111 : dffD;

  // Proportional and Integral terms
  assign P_term = error;
  assign I_term = {2'b00, integrator[16:5]};
  
  // PID output computation
  assign D_term_in = {{4{D_saturation[8]}}, D_saturation, 1'b0};
  //pipeline - for D term
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n) D_term <= 12'h000;
		else D_term <= D_term_in;
  // Saturate PID output to 12 bits
  assign PID_term = P_term + I_term + D_term;
  //assign drv_mag = (PID_term[13]) ? 12'h000 : PID_term[12] ? 12'hFFF : PID_term[11:0];
  assign drv_mag_in = (PID[13]) ? 12'h000 : PID[12] ? 12'hFFF : PID[11:0];
	//pipeline - end of drv_mag
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n) drv_mag <= 12'h000;
		 else drv_mag <= drv_mag_in;
endmodule
