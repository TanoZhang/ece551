module PID(clk, rst_n, error, not_pedaling, drv_mag);
	
	input clk, rst_n, not_pedaling;
	input signed [12:0] error;
	
	output logic [11:0] drv_mag;
	
	parameter FAST_SIM = 1;
	
	logic [17:0] integrator, sign_extended_error, added_error, sat_error, integrator_in;
	logic [19:0] counter;
	logic [12:0] ff1, ff2, ff3, D_diff;
	logic [8:0] D_sat;
	logic [13:0] P_term, I_term, D_term, PID;
	logic pos_ov, decimator_full;
	
	generate 
		if (FAST_SIM) begin
			assign decimator_full = &counter[14:0];
		end else begin
			assign decimator_full =  &counter;
		end
	endgenerate
	
	//I_term logic
	assign sign_extended_error = {{5{error[12]}}, error};
	assign added_error = sign_extended_error + integrator;
	assign pos_ov = integrator[16] & added_error[17];
	assign sat_error = pos_ov ? 18'h1FFFF : added_error[17] ? 18'h00000 : added_error;
	
	//counter logic
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n) counter <= 20'h00000;
		else counter <= counter + 1;
	
	//integrator flop output
	assign integrator_in = not_pedaling ? 18'h00000 : decimator_full ? sat_error : integrator;
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n) integrator <= 18'h00000;
		else integrator <= integrator_in;
	
	
	//D_term logic
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) begin
			ff1 <= 13'h00000;
			ff2 <= 13'h00000;
			ff3 <= 13'h00000;
		end else if (decimator_full) begin
			ff1 <= error[12:0];
			ff2 <= ff1;
			ff3 <= ff2;
		end else begin
			ff1 <= ff1;
			ff2 <= ff2;
			ff3 <= ff3;
		end
	end
	
	assign D_diff = error - ff3;
	assign D_sat = (D_diff[12] & ~&(D_diff[11:9])) ? 9'b100000000 : (~D_diff[12] & |(D_diff[11:9])) ? 9'b011111111 : D_diff;

	assign D_term = {{4{D_sat[8]}}, D_sat, 1'b0};
	assign I_term = {2'b00, integrator[16:5]};
	assign P_term = error;
	
	assign PID = P_term + I_term + D_term;
	assign drv_mag = (PID[13]) ? 12'h000 : PID[12] ? 12'hFFF : PID[11:0];
	
endmodule