module desiredDrive (
    avg_torque,
    cadence,
    not_pedaling,
    incline,
    clk,
    scale,
    target_curr
);
  input [11:0] avg_torque;
  input [4:0] cadence;
  input not_pedaling;
  input clk;
  input signed [12:0] incline;
  input [2:0] scale;			// Assist level
  output [11:0] target_curr;

  logic [ 9:0] incline_saturation;	
  logic [ 8:0] incline_limit;
  logic [10:0] incline_factor;
  logic [12:0] zero_torque;
  logic [ 5:0] cadence_factor;
  logic [11:0] throttle_position;
  logic [29:0] assist;

  // Minimum torque threshold
  localparam TORQUE_MIN = 12'h380;

  //Incline Saturation limit to signed 10bit
  assign incline_saturation = (incline[12] && ~&incline[11:9]) ? 10'b1000000000 : (!incline[12] && |incline[11:9]) ? 10'b0111111111 : incline[9:0];
  //throuttle position
  assign throttle_position = (zero_torque[12]) ? 12'h000 : zero_torque[11:0];

  //incline factor shift incline_saturation to center at 512
  assign incline_factor = {incline_saturation[9], incline_saturation} + 10'b0100000000;
  assign incline_limit = (incline_factor[10]) ? 9'b000000000 : (!incline_factor[10] && |incline_factor[9]) ? 9'b111111111 : incline_factor[8:0];
  assign cadence_factor = (cadence > 5'd1) ? cadence + 6'b100000 : 6'b000000;  // cadence < 2 => not really pedaling

  //Zero torque
  assign zero_torque = avg_torque - TORQUE_MIN;

  //Assist calculation
  assign target_curr = (assist[29:27]) ? 12'hFFF : assist[26:15];
  //target output
  //assign assist = (not_pedaling) ? 30'h00000000 : throttle_position * incline_limit * cadence_factor * scale;
	
	//pipelining the code
	logic [11:0] throttle_position_reg;
	always_ff @(posedge clk) throttle_position_reg <= throttle_position;
	
	logic [8:0] incline_limit_reg;
	always_ff @(posedge clk) incline_limit_reg <= incline_limit;
	
	logic [5:0] cadence_factor_reg;
	always_ff @(posedge clk) cadence_factor_reg <= cadence_factor;
	
	logic [23:0] mult1;
	logic [29:0] mult2;
	//logic [29:0] mult2_pre;
	logic [29:0] assist_mult;
	
	always_ff @(posedge clk) mult1 <= throttle_position_reg * incline_limit_reg;
	always_ff @(posedge clk) mult2 <= mult1 * cadence_factor_reg;
	always_ff @(posedge clk) assist_mult <= mult2 * scale;
	always_ff @(posedge clk) assist <= (not_pedaling) ? 30'h00000000 : assist_mult;
endmodule
