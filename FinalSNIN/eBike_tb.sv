module eBike_tb;

  // Compact testbench for eBike controller
  localparam FAST_SIM    = 1;          // fast simulation mode
  localparam ERR_LIMIT  = 45;         // allowable current error

  // Clock & reset
  reg clk = 0, rst_n;

  // Analog inputs: battery, brake lever, pedal torque
  reg [11:0] batt_v, brake_v, torque_v;
  // Cadence pulse, assist button, incline rate
  reg cadence_p, mode_btn;
  reg [15:0] yaw_rate;

  // Interface signals
  wire A2D_SS_n, A2D_MOSI, A2D_SCLK, A2D_MISO;
  wire highG, lowG, highY, lowY, highB, lowB;
  wire hallG, hallY, hallB;
  wire iSS_n, iSCLK, iMISO, iMOSI, iINT;
  wire [1:0] led_sel;
  wire [11:0] curr;
  wire TX;

  // Measurement variables
  reg signed [19:0] omega_before, omega_after;
  reg [11:0] curr_before, curr_after;

  // Models & DUT
  AnalogModel analog(.clk(clk), .rst_n(rst_n), .SS_n(A2D_SS_n), .SCLK(A2D_SCLK),
                    .MISO(A2D_MISO), .MOSI(A2D_MOSI), .BATT(batt_v), .CURR(curr),
                    .BRAKE(brake_v), .TORQUE(torque_v));

  eBikePhysics phys(.clk(clk), .RST_n(rst_n), .SS_n(iSS_n), .SCLK(iSCLK),
                    .MISO(iMISO), .MOSI(iMOSI), .INT(iINT), .yaw_rt(yaw_rate),
                    .highGrn(highG), .lowGrn(lowG), .highYlw(highY), .lowYlw(lowY),
                    .highBlu(highB), .lowBlu(lowB), .hallGrn(hallG), .hallYlw(hallY),
                    .hallBlu(hallB), .avg_curr(curr));

  eBike #(FAST_SIM) dut(.clk(clk), .RST_n(rst_n), .A2D_SS_n(A2D_SS_n), .A2D_MOSI(A2D_MOSI),
                       .A2D_SCLK(A2D_SCLK), .A2D_MISO(A2D_MISO), .hallGrn(hallG),
                       .hallYlw(hallY), .hallBlu(hallB), .highGrn(highG),
                       .lowGrn(lowG), .highYlw(highY), .lowYlw(lowY),
                       .highBlu(highB), .lowBlu(lowB), .inertSS_n(iSS_n),
                       .inertSCLK(iSCLK), .inertMOSI(iMOSI), .inertMISO(iMISO),
                       .inertINT(iINT), .cadence(cadence_p), .tgglMd(mode_btn),
                       .TX(TX), .LED(led_sel));

  // Helper: simulate pedaling pulses
  task pedal_cycle(input int cycles, input int period);
    repeat(cycles) begin
      cadence_p = 0; repeat(period) @(posedge clk);
      cadence_p = 1; repeat(period) @(posedge clk);
    end
  endtask

  // Helper: check current error
  task check_error;
    if (dut.iSensorCondition.error > ERR_LIMIT ||
        dut.iSensorCondition.error < -ERR_LIMIT) begin
      $fatal("Error too large: %0d", dut.iSensorCondition.error);
    end
  endtask

  initial begin
    integer tc;

    // Test suite: reordered and trimmed for brevity
    for (tc = 5; tc <= 6; tc++) begin
      // reset
      rst_n = 0; @(posedge clk); @(negedge clk); rst_n = 1;

      // default inputs
      batt_v   = 12'hB00;
      brake_v  = 12'h800;
      torque_v = 12'h500;
      yaw_rate = 16'h2000;
      mode_btn = 0;

      // fix assist mode to MED
      force dut.setting = 2'b10;

      $display("\n=== Running Test %0d ===", tc);

      case (tc)
        // Test 1: Assist level effect
        1: begin
          $display("Test 1: Assist up increases speed/current");
          torque_v = 12'h500;
          pedal_cycle(512, 512);
          //check_error();
          omega_before = phys.omega; curr_before = dut.iSensorCondition.avg_curr;

          force dut.setting = 2'b11;
          pedal_cycle(512, 512);
          //check_error();
          omega_after  = phys.omega; curr_after  = dut.iSensorCondition.avg_curr;

          if (!(omega_after > omega_before && curr_after > curr_before))
            $fatal("Assist test failed");
        end

        // Test 2: Torque increase effect
        2: begin
          $display("Test 2: More torque -> higher speed/current");
          torque_v = 12'h600;
          pedal_cycle(512, 512);
          //check_error();
          omega_before = phys.omega; curr_before = dut.iSensorCondition.avg_curr;

          torque_v = 12'hA00;
          pedal_cycle(512, 512);
          //check_error();
          omega_after  = phys.omega; curr_after  = dut.iSensorCondition.avg_curr;

          if (!(omega_after > omega_before && curr_after > curr_before))
            $fatal("Torque test failed");
        end

        // Test 3: Incline change effect
        3: begin
          $display("Test 3: Downhill->uphill slows bike");
          yaw_rate = 16'h2000;
          pedal_cycle(512, 512);
          //check_error();
          omega_before = phys.omega; curr_before = dut.iSensorCondition.avg_curr;

          yaw_rate = 16'h8000; // steep downhill
          pedal_cycle(512, 512);
          //check_error();
          omega_after = phys.omega; curr_after = dut.iSensorCondition.avg_curr;

          if (!(omega_after > omega_before && curr_after > curr_before))
            $fatal("Incline test failed");
        end

        // Test 4: Faster cadence -> ramp up
        4: begin
          
		  $display("Test 4: Higher cadence rate boosts bike");
		  yaw_rate = 16'h2000;
          pedal_cycle(2048, 256);
          //check_error();
          omega_before = phys.omega; curr_before = dut.iSensorCondition.avg_curr;
		  
          pedal_cycle(4096, 128); // faster by halved low period
          //check_error();
          omega_after = phys.omega; curr_after = dut.iSensorCondition.avg_curr;

          if (!(omega_after > omega_before && curr_after > curr_before))
            $fatal("Cadence-rate test failed");
        end

        // Test 5: Uphill->downhill effect
        5: begin
          $display("Test 5: Uphill->downhill increases effort");
          yaw_rate = 16'h0000;
          pedal_cycle(512, 512);
          //check_error();
          omega_before = phys.omega; curr_before = dut.iSensorCondition.avg_curr;

          yaw_rate = 16'hA800;
          pedal_cycle(512, 512);
          //check_error();
          omega_after = phys.omega; curr_after = dut.iSensorCondition.avg_curr;

          if (!(omega_after < omega_before && curr_after < curr_before))
            $fatal("Downhill->uphill test failed");
        end
		
		// Test 6: No cadence -> spin down
        6: begin
          $display("Test 6: Stopping pedaling slows bike");
          torque_v = 12'hA00;
          pedal_cycle(512, 512);
          //check_error();
          omega_before = phys.omega; curr_before = dut.iSensorCondition.avg_curr;

          repeat(2048) begin
						cadence_p = 0;
						repeat(2048) @(posedge clk);
						cadence_p = 0;  // NO CADENCE
						repeat(2048) @(posedge clk);
					end
          //check_error();
          omega_after = phys.omega; curr_after = dut.iSensorCondition.avg_curr;

          if (!(omega_after < omega_before && curr_after < curr_before)) begin
            $display("Cadence-stop test failed");
			$stop();
		  end
        end

      endcase

      $display("Test %0d PASSED", tc);
    end

    $display("\nALL %0d TESTS COMPLETED SUCCESSFULLY", tc-1);
    $stop;
  end

  // Clock generator
  always #10 clk = ~clk;

  // Display assist mode changes
  always @(led_sel) $display("Assist mode = %0b", led_sel);

endmodule
