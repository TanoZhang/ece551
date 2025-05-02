module desiredDrive(avg_torque, cadence, not_pedaling, incline, scale, target_curr);
	input [11:0] avg_torque;
	input [4:0] cadence;
	input not_pedaling;
	input signed [12:0] incline;
	input [2:0] scale;
  
	output [11:0] target_curr;
  
	logic [9:0] incline_sat;
	logic [10:0] incline_factor;
	logic [8:0] incline_lim;
	logic [5:0] cadence_factor;
	logic [12:0] torque_off;
	logic [11:0] torque_pos;
	logic [29:0] assist_prod;
	
	localparam TORQUE_MIN = 12'h380;
	
	assign incline_sat = (incline[12] && ~|incline[11:9]) ? 10'b1000000000 :
                       (!incline[12] && |incline[11:9]) ? 10'b0111111111 :
						incline[9:0];

	assign incline_factor = {incline_sat[9], incline_sat} + 10'b0100000000;
	assign incline_lim = (incline_factor[10]) ? 9'b000000000 :
                       (!incline_factor[10] && |incline_factor[9]) ? 9'b111111111 :
						incline_factor[8:0];
	assign cadence_factor = (~|cadence) ? 5'b00000 :
						cadence + 6'b100000;
	assign torque_off = avg_torque - TORQUE_MIN;
	assign torque_pos = (torque_off[12]) ? 12'h000 : torque_off[11:0];
	assign assist_prod = (not_pedaling) ? 30'h00000000 :
						torque_pos * incline_lim * cadence_factor * scale;
	
	assign target_curr = (assist_prod[29:27]) ? 12'hFFF :
						assist_prod[26:15];
endmodule