module PID_tb();
	
	logic clk, rst_n, not_pedaling, test_over;
	logic [11:0] drv_mag;
	logic [12:0] error;
	
	PID #(.FAST_SIM(1)) iDUT(.clk(clk), .rst_n(rst_n), .error(error), .not_pedaling(not_pedaling), .drv_mag(drv_mag));
	plant_PID plant(.clk(clk), .rst_n(rst_n), .error(error), .not_pedaling(not_pedaling), .drv_mag(drv_mag), .test_over(test_over));
	
	initial begin
		clk = 0;
		rst_n = 0;
		@(negedge clk) rst_n = 1;
		@(posedge test_over);
		$stop();
	end
	always
		#5 clk = ~clk;

endmodule  