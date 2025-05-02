module eBike_tb2();

	localparam FAST_SIM = 1;
	reg clk, RST_n;
	reg [11:0] BATT;				// analog values - battery voltage
	reg [11:0] BRAKE, TORQUE;		// analog values for brake lever and pedal torque
	reg cadence;					// pulse input from pedal cadence sensor
	reg tgglMd;	                    // push button for assist mode (off, hard, medium, easy)
	reg [15:0] YAW_RT;			    // models angular rate of incline (+ => uphill)
  
	//////////////////////////////////////////////////
	// Declare signals to interconnect //
	////////////////////////////////////////////////
	wire A2D_SS_n, A2D_MOSI, A2D_SCLK, A2D_MISO;		// A2D SPI interface
	wire highGrn, lowGrn, highYlw;					    // FET control
	wire lowYlw, highBlu, lowBlu;					    //   PWM signals
	wire hallGrn, hallBlu, hallYlw;					    // hall sensor outputs
	wire inertSS_n, inertSCLK, inertMISO, inertMOSI, inertINT;	// Inert sensor SPI bus
  
	wire [1:0] setting;		// drive LEDs on real design
	wire [11:0] curr;		// comes from eBikePhysics back to AnalogModel
	wire TX;                // UART transmit from telemetry
	
	//Variables for omega testing
	reg signed [19:0] omega_temp1;
	reg signed [19:0] omega_temp2;
	logic [11:0] avg_curr_temp1;
	logic [11:0] avg_curr_temp2;
	
	AnalogModel iANLG(.clk(clk), .rst_n(RST_n), .SS_n(A2D_SS_n), .SCLK(A2D_SCLK),
		.MISO(A2D_MISO), .MOSI(A2D_MOSI), .BATT(BATT),
		.CURR(curr), .BRAKE(BRAKE), .TORQUE(TORQUE));
		
	eBikePhysics iPHYS(.clk(clk), .RST_n(RST_n), .SS_n(inertSS_n), .SCLK(inertSCLK),
		.MISO(inertMISO), .MOSI(inertMOSI), .INT(inertINT),
		.yaw_rt(YAW_RT), .highGrn(highGrn), .lowGrn(lowGrn),
		.highYlw(highYlw), .lowYlw(lowYlw), .highBlu(highBlu),
		.lowBlu(lowBlu), .hallGrn(hallGrn), .hallYlw(hallYlw),
		.hallBlu(hallBlu), .avg_curr(curr));
		
	eBike #(FAST_SIM) iDUT(.clk(clk), .RST_n(RST_n), .A2D_SS_n(A2D_SS_n), .A2D_MOSI(A2D_MOSI),
		.A2D_SCLK(A2D_SCLK), .A2D_MISO(A2D_MISO), .hallGrn(hallGrn),
		.hallYlw(hallYlw), .hallBlu(hallBlu), .highGrn(highGrn),
		.lowGrn(lowGrn), .highYlw(highYlw), .lowYlw(lowYlw),
		.highBlu(highBlu), .lowBlu(lowBlu), .inertSS_n(inertSS_n),
		.inertSCLK(inertSCLK), .inertMOSI(inertMOSI),
		.inertMISO(inertMISO), .inertINT(inertINT),
		.cadence(cadence), .tgglMd(tgglMd), .TX(TX),
		.LED(setting));
		
	initial begin
		TORQUE = 12'h700;
		BATT = 12'hB11;
		YAW_RT = 16'h0000;
		
		RST_n = 0;
		clk = 0;
		cadence = 0;
		tgglMd = 0;
		
		@(negedge clk) RST_n = 1;
		repeat(850000)@(posedge clk);
		TORQUE = 12'h500;
		repeat(850000)@(posedge clk);
		$stop();
	end
	
	always #5 clk = ~clk;
	always #10240 cadence = ~cadence;
endmodule