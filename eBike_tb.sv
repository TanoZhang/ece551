module eBike_tb();

	// Testbench for verifying the eBike controller functionality
	// Tests pedal torque, cadence sensing, assist modes, incline detection, and braking
  
	localparam FAST_SIM = 1;		// accelerate simulation by default
	localparam errorThreshold = 50;  // Threshold for determining if avg_curr is close enough to target

	///////////////////////////
	// Stimulus of type reg //
	/////////////////////////
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
  
	//////////////////////////////////////////////////
	// Instantiate model of analog input circuitry //
	////////////////////////////////////////////////
	AnalogModel iANLG(.clk(clk), .rst_n(RST_n), .SS_n(A2D_SS_n), .SCLK(A2D_SCLK),
		.MISO(A2D_MISO), .MOSI(A2D_MOSI), .BATT(BATT),
		.CURR(curr), .BRAKE(BRAKE), .TORQUE(TORQUE));

	////////////////////////////////////////////////////////////////
	// Instantiate model inertial sensor used to measure incline //
	//////////////////////////////////////////////////////////////
	eBikePhysics iPHYS(.clk(clk), .RST_n(RST_n), .SS_n(inertSS_n), .SCLK(inertSCLK),
		.MISO(inertMISO), .MOSI(inertMOSI), .INT(inertINT),
		.yaw_rt(YAW_RT), .highGrn(highGrn), .lowGrn(lowGrn),
		.highYlw(highYlw), .lowYlw(lowYlw), .highBlu(highBlu),
		.lowBlu(lowBlu), .hallGrn(hallGrn), .hallYlw(hallYlw),
		.hallBlu(hallBlu), .avg_curr(curr));

	//////////////////////
	// Instantiate DUT //
	////////////////////
	eBike #(FAST_SIM) iDUT(.clk(clk), .RST_n(RST_n), .A2D_SS_n(A2D_SS_n), .A2D_MOSI(A2D_MOSI),
		.A2D_SCLK(A2D_SCLK), .A2D_MISO(A2D_MISO), .hallGrn(hallGrn),
		.hallYlw(hallYlw), .hallBlu(hallBlu), .highGrn(highGrn),
		.lowGrn(lowGrn), .highYlw(highYlw), .lowYlw(lowYlw),
		.highBlu(highBlu), .lowBlu(lowBlu), .inertSS_n(inertSS_n),
		.inertSCLK(inertSCLK), .inertMOSI(inertMOSI),
		.inertMISO(inertMISO), .inertINT(inertINT),
		.cadence(cadence), .tgglMd(tgglMd), .TX(TX),
		.LED(setting));

	// UART receiver for monitoring telemetry
	wire [35:0] rx_data;
	wire rdy, clr_rdy;
	
	// Optional UART for telemetry monitoring
	// UART_rcv iUART(.clk(clk), .rst_n(RST_n), .RX(TX), .rdy(rdy), .rx_data(rx_data), .clr_rdy(clr_rdy));
	
	// Task to simulate pedaling for a given number of cycles
	task simulate_pedaling;
		input integer num_cycles;
		input integer interval;
		
		begin
			repeat(num_cycles) begin
				cadence = 0;
				repeat(interval) @(posedge clk);
				cadence = 1;
				repeat(interval) @(posedge clk);
			end
		end
	endtask
	
	// Task to check if current has stabilized
	task check_stability;
		begin
			if(iDUT.iSensorCondition.error > errorThreshold || iDUT.iSensorCondition.error < -errorThreshold) begin
				$display("Error value: %d", iDUT.iSensorCondition.error); 
				$display("Avg current never approached the target current.");
				$stop;
			end
		end
	endtask
	
	initial begin
	
		integer testcase = 1; // Starting testcase, can be changed
		
	 	clk = 0; // Initialize clock
	 	
	 	//***************************** Test Suite ******************************************
	 	
	 	// Run through a set of test cases
		for(testcase = 1; testcase <= 7; testcase = testcase + 1) begin
			
			// Reset everything at the start of each test
			RST_n = 0;
			@(posedge clk);
			@(negedge clk);
			RST_n = 1;
			
			// Set initial conditions common to all tests
			BATT = 12'hB11;   // Battery good
			BRAKE = 12'h900;  // Brake not applied
			TORQUE = 12'h400; // Default torque
			YAW_RT = 16'h0000; // Flat ground
			cadence = 0;      // No pedaling initially
			tgglMd = 0;       // Initialize mode button to not pressed
			
			// Set proper assist mode for testing (medium)
			force iDUT.setting = 2'b10;
			
			$display("Starting Test Case %0d", testcase);
			
			case(testcase)
				// TEST 1: CHECKS THAT WHEN TORQUE INCREASES, OMEGA AND CURR SHOULD INCREASE
				1: begin
					$display("Test Case 1: Verify that increased torque increases motor speed and current");
					
					// Initial conditions for test case 1 - medium torque, uphill
					BATT = 12'hB11;     // Battery not low
					BRAKE = 12'h900;    // Brake not applied
					TORQUE = 12'h400;   // Medium torque initially
					YAW_RT = 16'h2000;  // Uphill
					
					// Simulate pedaling for a period
					simulate_pedaling(2048, 2048);
					
					// Check if we reached stable state
					check_stability();
					
					// Record current omega and current values
					omega_temp1 = iPHYS.omega;
					avg_curr_temp1 = iDUT.iSensorCondition.avg_curr;
					$display("Initial values - Omega: %d, Avg Current: %d", omega_temp1, avg_curr_temp1);
					
					// Increase torque
					TORQUE = 12'h983;   // Higher torque
					
					// Continue pedaling
					simulate_pedaling(2048, 2048);
					
					// Check stable state again
					check_stability();
					
					// Record new values after torque increase
					omega_temp2 = iPHYS.omega;
					avg_curr_temp2 = iDUT.iSensorCondition.avg_curr;
					$display("Final values - Omega: %d, Avg Current: %d", omega_temp2, avg_curr_temp2);
					
					// Verify that omega and current increased
					if(!(omega_temp1 < omega_temp2)) begin
						$display("Test #%d Failed: Omega did not increase when torque increased.", testcase);
						$display("  Initial omega: %d, Final omega: %d", omega_temp1, omega_temp2);
						$stop;
					end
					
					if(!(avg_curr_temp1 < avg_curr_temp2)) begin
						$display("Test #%d Failed: Avg_curr did not increase when torque increased.", testcase);
						$display("  Initial avg_curr: %d, Final avg_curr: %d", avg_curr_temp1, avg_curr_temp2);
						$stop;
					end
					
					$display("Test #%d Passed: Omega and Current increased with increased torque", testcase);
				end
				
				// TEST 2: CHECKS THAT IF CADENCE GOES TO ZERO THE OMEGA SHOULD DECREASE TO NEARLY ZERO
				2: begin
					$display("Test Case 2: Verify that when cadence is zero, motor speed decreases");
					
					// Initial conditions - high torque, uphill, with cadence
					force iDUT.setting = 2'b10;
					BATT = 12'hB11;     // Battery not low
					BRAKE = 12'h900;    // Brake not applied
					TORQUE = 12'h983;   // High torque
					YAW_RT = 16'h2000;  // Uphill
					
					// Simulate pedaling with cadence
					repeat(2048) begin
						cadence = 0;
						repeat(2048) @(posedge clk);
						cadence = 1;  // WITH CADENCE
						repeat(2048) @(posedge clk);
					end
					
					// Check if we reached stable state
					check_stability();
					
					// Record initial values with pedaling
					omega_temp1 = iPHYS.omega;
					avg_curr_temp1 = iDUT.iSensorCondition.avg_curr;
					$display("With pedaling - Omega: %d, Avg Current: %d", omega_temp1, avg_curr_temp1);
					
					// Now simulate without pedaling (always cadence=0)
					repeat(2048) begin
						cadence = 0;
						repeat(2048) @(posedge clk);
						cadence = 0;  // NO CADENCE
						repeat(2048) @(posedge clk);
					end
					
					// Check stable state again
					check_stability();
					
					// Record new values without pedaling
					omega_temp2 = iPHYS.omega;
					avg_curr_temp2 = iDUT.iSensorCondition.avg_curr;
					$display("Without pedaling - Omega: %d, Avg Current: %d", omega_temp2, avg_curr_temp2);
					
					// Verify that omega and current decreased
					if(!(omega_temp1 > omega_temp2)) begin
						$display("Test #%d Failed: Omega did not decrease when cadence was zero.", testcase);
						$display("  With pedaling omega: %d, Without pedaling omega: %d", omega_temp1, omega_temp2);
						$stop;
					end
					
					if(!(avg_curr_temp1 > avg_curr_temp2)) begin
						$display("Test #%d Failed: Avg_curr did not decrease when cadence became zero.", testcase);
						$display("  With pedaling avg_curr: %d, Without pedaling avg_curr: %d", avg_curr_temp1, avg_curr_temp2);
						$stop;
					end
					
					$display("Test #%d Passed: Omega and Current decreased when cadence stopped", testcase);
				end
				
				// TEST 3: CHECKS WHEN GOING FROM UPHILL TO DOWNHILL IF OMEGA DECREASES
				3: begin
					$display("Test Case 3: Verify that changing from uphill to downhill decreases motor speed and current");
					
					// Initial conditions - medium torque, uphill
					force iDUT.setting = 2'b10;
					BATT = 12'hB11;     // Battery not low
					BRAKE = 12'h900;    // Brake not applied
					TORQUE = 12'h600;   // Medium torque
					YAW_RT = 16'h2000;  // Uphill
					
					// Simulate pedaling uphill
					simulate_pedaling(2048, 2048);
					
					// Check if we reached stable state
					check_stability();
					
					// Record uphill values
					omega_temp1 = iPHYS.omega;
					avg_curr_temp1 = iDUT.iSensorCondition.avg_curr;
					$display("Uphill - Omega: %d, Avg Current: %d", omega_temp1, avg_curr_temp1);
					
					// Switch to downhill
					YAW_RT = 16'hA800;  // Downhill
					
					// Wait for some time to stabilize
					repeat(3000000) @(posedge clk);
					
					// Reset to flat for stable simulation
					YAW_RT = 16'h0000;
					
					// Continue pedaling
					simulate_pedaling(2048, 2048);
					
					// Check stable state again
					check_stability();
					
					// Record downhill values
					omega_temp2 = iPHYS.omega;
					avg_curr_temp2 = iDUT.iSensorCondition.avg_curr;
					$display("Downhill - Omega: %d, Avg Current: %d", omega_temp2, avg_curr_temp2);
					
					// Verify that omega and current decreased
					if(!(omega_temp1 > omega_temp2)) begin
						$display("Test #%d Failed: Omega did not decrease when going downhill.", testcase);
						$display("  Uphill omega: %d, Downhill omega: %d", omega_temp1, omega_temp2);
						$stop;
					end
					
					if(!(avg_curr_temp1 > avg_curr_temp2)) begin
						$display("Test #%d Failed: Avg_curr did not decrease when going from uphill to downhill.", testcase);
						$display("  Uphill avg_curr: %d, Downhill avg_curr: %d", avg_curr_temp1, avg_curr_temp2);
						$stop;
					end
					
					$display("Test #%d Passed: Omega and Current decreased when transitioning from uphill to downhill", testcase);
				end
				
				// TEST 4: CHECKS THAT WHEN YOU INCREASE SETTING THE CURRENT AND OMEGA INCREASE
				4: begin
					$display("Test Case 4: Verify that increasing assist level increases motor speed and current");
					
					// Start with low assist setting
					force iDUT.setting = 2'b01;  // Low assist
					BATT = 12'hB11;     // Battery not low
					BRAKE = 12'h900;    // Brake not applied
					TORQUE = 12'h600;   // Medium torque
					YAW_RT = 16'h2000;  // Uphill
					
					// Simulate pedaling
					simulate_pedaling(2048, 2048);
					
					// Check if we reached stable state
					check_stability();
					
					// Record values at low assist
					omega_temp1 = iPHYS.omega;
					avg_curr_temp1 = iDUT.iSensorCondition.avg_curr;
					$display("Low assist - Omega: %d, Avg Current: %d", omega_temp1, avg_curr_temp1);
					
					// Increase to high assist setting
					force iDUT.setting = 2'b11;  // High assist
					
					// Continue pedaling
					simulate_pedaling(2048, 2048);
					
					// Check stable state again
					check_stability();
					
					// Record values at high assist
					omega_temp2 = iPHYS.omega;
					avg_curr_temp2 = iDUT.iSensorCondition.avg_curr;
					$display("High assist - Omega: %d, Avg Current: %d", omega_temp2, avg_curr_temp2);
					
					// Verify that omega and current increased
					if(!(omega_temp1 < omega_temp2)) begin
						$display("Test #%d Failed: Omega did not increase when setting increased.", testcase);
						$display("  Low assist omega: %d, High assist omega: %d", omega_temp1, omega_temp2);
						$stop;
					end
					
					if(!(avg_curr_temp1 < avg_curr_temp2)) begin
						$display("Test #%d Failed: Avg_curr did not increase when setting increased.", testcase);
						$display("  Low assist avg_curr: %d, High assist avg_curr: %d", avg_curr_temp1, avg_curr_temp2);
						$stop;
					end
					
					$display("Test #%d Passed: Omega and Current increased when assist level increased", testcase);
				end
				
				// TEST 5: CHECKS IF WHEN THE INCLINE INCREASES SO DOES THE OMEGA AND CURR
				5: begin
					$display("Test Case 5: Verify that increasing incline increases motor speed and current");
					
					// Start with low incline
					force iDUT.setting = 2'b01;  // Low assist
					BATT = 12'hB11;     // Battery not low
					BRAKE = 12'h900;    // Brake not applied
					TORQUE = 12'h600;   // Medium torque
					YAW_RT = 16'h2000;  // Low incline
					
					// Simulate pedaling on low incline
					simulate_pedaling(2048, 2048);
					
					// Check if we reached stable state
					check_stability();
					
					// Record values at low incline
					omega_temp1 = iPHYS.omega;
					avg_curr_temp1 = iDUT.iSensorCondition.avg_curr;
					$display("Low incline - Omega: %d, Avg Current: %d", omega_temp1, avg_curr_temp1);
					
					// Increase to steep incline
					YAW_RT = 16'h8000;  // Steep incline
					
					// Continue pedaling
					simulate_pedaling(2048, 2048);
					
					// Check stable state again
					check_stability();
					
					// Record values at high incline
					omega_temp2 = iPHYS.omega;
					avg_curr_temp2 = iDUT.iSensorCondition.avg_curr;
					$display("High incline - Omega: %d, Avg Current: %d", omega_temp2, avg_curr_temp2);
					
					// Verify that omega and current increased
					if(!(omega_temp1 < omega_temp2)) begin
						$display("Test #%d Failed: Omega did not increase when incline increased.", testcase);
						$display("  Low incline omega: %d, High incline omega: %d", omega_temp1, omega_temp2);
						$stop;
					end
					
					if(!(avg_curr_temp1 < avg_curr_temp2)) begin
						$display("Test #%d Failed: Avg_curr did not increase when incline increased.", testcase);
						$display("  Low incline avg_curr: %d, High incline avg_curr: %d", avg_curr_temp1, avg_curr_temp2);
						$stop;
					end
					
					$display("Test #%d Passed: Omega and Current increased when incline increased", testcase);
				end
				
				// TEST 6: CHECKS IF THE OMEGA INCREASES WHEN GOING FROM DOWNHILL TO UPHILL
				6: begin
					$display("Test Case 6: Verify that changing from downhill to uphill increases motor speed and current");
					
					// Start downhill
					force iDUT.setting = 2'b10;  // Medium assist
					BATT = 12'hB11;     // Battery not low
					BRAKE = 12'h900;    // Brake not applied
					TORQUE = 12'h600;   // Medium torque
					YAW_RT = 16'hA800;  // Downhill
					
					// Wait for some time for the simulation to settle
					repeat(3000000) @(posedge clk);
					
					// Set to flat for stable simulation
					YAW_RT = 16'h0000;
					
					// Simulate pedaling downhill
					simulate_pedaling(2048, 2048);
					
					// Check if we reached stable state
					check_stability();
					
					// Record downhill values
					omega_temp1 = iPHYS.omega;
					avg_curr_temp1 = iDUT.iSensorCondition.avg_curr;
					$display("Downhill - Omega: %d, Avg Current: %d", omega_temp1, avg_curr_temp1);
					
					// Switch to uphill
					YAW_RT = 16'h8000;  // Uphill
					
					// Continue pedaling
					simulate_pedaling(2048, 2048);
					
					// Check stable state again
					check_stability();
					
					// Record uphill values
					omega_temp2 = iPHYS.omega;
					avg_curr_temp2 = iDUT.iSensorCondition.avg_curr;
					$display("Uphill - Omega: %d, Avg Current: %d", omega_temp2, avg_curr_temp2);
					
					// Verify that omega and current increased
					if(!(omega_temp1 < omega_temp2)) begin
						$display("Test #%d Failed: Omega did not increase when going uphill.", testcase);
						$display("  Downhill omega: %d, Uphill omega: %d", omega_temp1, omega_temp2);
						$stop;
					end
					
					if(!(avg_curr_temp1 < avg_curr_temp2)) begin
						$display("Test #%d Failed: Avg_curr did not increase when going from downhill to uphill.", testcase);
						$display("  Downhill avg_curr: %d, Uphill avg_curr: %d", avg_curr_temp1, avg_curr_temp2);
						$stop;
					end
					
					$display("Test #%d Passed: Omega and Current increased when transitioning from downhill to uphill", testcase);
				end
				
				// TEST 7: CHECKS IF WHEN THE CADENCE RATE IS INCREASED SO DOES THE OMEGA AND CURR
				7: begin
					$display("Test Case 7: Verify that increasing cadence rate increases motor speed and current");
					
					// Start with normal cadence rate
					force iDUT.setting = 2'b10;  // Medium assist
					BATT = 12'hB11;     // Battery not low
					BRAKE = 12'h900;    // Brake not applied
					TORQUE = 12'h600;   // Medium torque
					YAW_RT = 16'h0000;  // Flat ground
					
					// Simulate pedaling with normal cadence rate
					repeat(2048) begin
						cadence = 0;
						repeat(2048) @(posedge clk);  // Normal interval
						cadence = 1;
						repeat(2048) @(posedge clk);  // Normal interval
					end
					
					// Check if we reached stable state
					check_stability();
					
					// Record values at normal cadence rate
					omega_temp1 = iPHYS.omega;
					avg_curr_temp1 = iDUT.iSensorCondition.avg_curr;
					$display("Normal cadence rate - Omega: %d, Avg Current: %d", omega_temp1, avg_curr_temp1);
					
					// Increase cadence rate (shorter intervals between transitions)
					repeat(2048) begin
						cadence = 0;
						repeat(1024) @(posedge clk);  // Faster cadence (half the interval)
						cadence = 1;
						repeat(1024) @(posedge clk);  // Faster cadence (half the interval)
					end
					
					// Check stable state again
					check_stability();
					
					// Record values at higher cadence rate
					omega_temp2 = iPHYS.omega;
					avg_curr_temp2 = iDUT.iSensorCondition.avg_curr;
					$display("Faster cadence rate - Omega: %d, Avg Current: %d", omega_temp2, avg_curr_temp2);
					
					// Verify that omega and current increased
					if(!(omega_temp1 < omega_temp2)) begin
						$display("Test #%d Failed: Omega did not increase when cadence increased.", testcase);
						$display("  Normal cadence omega: %d, Faster cadence omega: %d", omega_temp1, omega_temp2);
						$stop;
					end
					
					if(!(avg_curr_temp1 < avg_curr_temp2)) begin
						$display("Test #%d Failed: Avg_curr did not increase when cadence increased.", testcase);
						$display("  Normal cadence avg_curr: %d, Faster cadence avg_curr: %d", avg_curr_temp1, avg_curr_temp2);
						$stop;
					end
					
					$display("Test #%d Passed: Omega and Current increased when cadence rate increased", testcase);
				end
				
				// TEST 8: CHECKS IF WHEN THE BRAKES ARE APPLIED THE OMEGA AND CURR DROP (Optional)
				8: begin
					$display("Test Case 8: Verify that applying brakes reduces motor speed and current");
					
					// Setup - medium assist, medium torque, uphill
					force iDUT.setting = 2'b10;  // Medium assist
					BATT = 12'hB11;     // Battery not low
					BRAKE = 12'h900;    // Brake not applied initially
					TORQUE = 12'h600;   // Medium torque
					YAW_RT = 16'h2000;  // Uphill
					
					// Simulate pedaling without braking
					simulate_pedaling(2048, 2048);
					
					// Record values without braking
					omega_temp1 = iPHYS.omega;
					avg_curr_temp1 = iDUT.iSensorCondition.avg_curr;
					$display("Without braking - Omega: %d, Avg Current: %d", omega_temp1, avg_curr_temp1);
					
					// Apply brake
					force iDUT.brake_n = 0;
					BRAKE = 12'h400;    // Brake applied
					
					// Continue pedaling with brake applied
					simulate_pedaling(2048, 2048);
					
					// Record values with braking
					omega_temp2 = iPHYS.omega;
					avg_curr_temp2 = iDUT.iSensorCondition.avg_curr;
					$display("With braking - Omega: %d, Avg Current: %d", omega_temp2, avg_curr_temp2);
					
					// Verify that omega and current decreased
					if(!(omega_temp1 > omega_temp2)) begin
						$display("Test #%d Failed: Omega did not decrease when brakes applied.", testcase);
						$display("  Without braking omega: %d, With braking omega: %d", omega_temp1, omega_temp2);
						$stop;
					end
					
					if(!(avg_curr_temp1 > avg_curr_temp2)) begin
						$display("Test #%d Failed: Avg_curr did not decrease when brakes applied.", testcase);
						$display("  Without braking avg_curr: %d, With braking avg_curr: %d", avg_curr_temp1, avg_curr_temp2);
						$stop;
					end
					
					$display("Test #%d Passed: Omega and Current decreased when brakes were applied", testcase);
					
					// Release the brake for clean state
					release iDUT.brake_n;
				end
				
			endcase
			
			$display("Test Case %0d completed successfully\n", testcase);
		end
	
		// All tests passed if we got here
		$display("YAHOO! ALL TESTS PASSED!");
		$stop();
	end

	// Clock generation
  	always
		#10 clk = ~clk;
		
	// Monitor functions
	// Monitor for settings changes
	always @(setting) begin
		case(setting)
			2'b00: $display("Setting changed to OFF (0)");
			2'b01: $display("Setting changed to LOW assist (1)");
			2'b10: $display("Setting changed to MEDIUM assist (2)");
			2'b11: $display("Setting changed to HIGH assist (3)");
		endcase
	end

endmodule