module sensorCondition_tb();

	logic clk, rst_n, cadence, not_pedaling, TX;
	logic [11:0]  torque, curr, batt;
	logic [12:0] error, incline;
	logic [1:0] setting;
	
	sensorCondition #(.FAST_SIM(1)) iDUT(.clk(clk), .rst_n(rst_n), .torque(torque), .cadence(cadence), .curr(curr), .incline(incline), .setting(setting), .batt(batt),
	.error(error), .not_pedaling(not_pedaling), .TX(TX));
	
	initial begin
		clk = 0;
		rst_n = 0;
		@(negedge clk) rst_n = 1;
		cadence = 1;
		torque = 12'h2ff;
		curr = 12'h3ff;
		cadence = 0;
		repeat(500000)@(posedge clk);
		$stop();
	end
	
	always #5 clk = ~clk;
	//4096 clock period for cadence
	always #10240 cadence = ~cadence;
endmodule