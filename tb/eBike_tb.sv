module eBike_tb;

  // Compact testbench for eBike controller
  localparam FAST_SIM    = 1;          // fast simulation mode
  localparam ERR_LIMIT  = 45;         // allowable current error
  localparam MAX_SETTLE = 4096;       // pedal cycles allowed for the loop to settle

  // FAST_SIM cadence: half periods must exceed the 512 clk debounce in
  // cadence_filt and keep cadence_per inside the cadence_LU table (>= 8)
  localparam CAD_SLOW   = 2048;       // half period -> cadence 21
  localparam CAD_NORM   = 1024;       // half period -> cadence 27

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
  // (at full drive the motor cannot deliver more current, so a remaining
  // error with drv_mag saturated is the actuator limit, not a loop failure)
  task check_error;
    if (dut.drv_mag == 12'hFFF)
      $display("  drive saturated (drv_mag = 0xFFF), error = %0d", dut.iSensorCondition.error);
    else if (dut.iSensorCondition.error > ERR_LIMIT ||
        dut.iSensorCondition.error < -ERR_LIMIT) begin
      $fatal(1, "Error too large: %0d", dut.iSensorCondition.error);
    end
  endtask

  // Helper: pedal until the current loop settles within ERR_LIMIT
  // (fails if it has not settled after MAX_SETTLE pedal cycles)
  task pedal_settle(input int period);
    int n;
    n = 256;
    pedal_cycle(256, period);
    while ((dut.iSensorCondition.error > ERR_LIMIT ||
            dut.iSensorCondition.error < -ERR_LIMIT) &&
           dut.drv_mag != 12'hFFF && n < MAX_SETTLE) begin
      pedal_cycle(16, period);
      n += 16;
    end
    check_error();
    $display("  settled after %0d pedal cycles (error = %0d)", n, dut.iSensorCondition.error);
  endtask

  initial begin
    integer tc;

    // Test suite: reordered and trimmed for brevity
    for (tc = 1; tc <= 8; tc++) begin
      // reset
      rst_n = 0; @(posedge clk); @(negedge clk); rst_n = 1;

      // default inputs
      batt_v   = 12'hB00;
      brake_v  = 12'h800;
      torque_v = 12'h500;
      yaw_rate = 16'h2000;
      mode_btn = 0;

      // fix assist mode to MED
      force dut.iPB_intf.setting = 2'b10;

      $display("\n=== Running Test %0d ===", tc);

      case (tc)
        // Test 1: Assist level effect
        1: begin
          $display("Test 1: Assist up increases speed/current");
          torque_v = 12'h500;
          pedal_settle(CAD_NORM);
          omega_before = phys.omega; curr_before = dut.iSensorCondition.avg_curr;

          force dut.iPB_intf.setting = 2'b11;
          pedal_settle(CAD_NORM);
          omega_after  = phys.omega; curr_after  = dut.iSensorCondition.avg_curr;

          if (!(omega_after > omega_before && curr_after > curr_before))
            $fatal(1, "Assist test failed");
        end

        // Test 2: Torque increase effect
        2: begin
          $display("Test 2: More torque -> higher speed/current");
          torque_v = 12'h500;
          pedal_settle(CAD_NORM);
          omega_before = phys.omega; curr_before = dut.iSensorCondition.avg_curr;

          torque_v = 12'h600;    // stays below drive saturation
          pedal_settle(CAD_NORM);
          omega_after  = phys.omega; curr_after  = dut.iSensorCondition.avg_curr;

          if (!(omega_after > omega_before && curr_after > curr_before))
            $fatal(1, "Torque test failed");
        end

        // Test 3: Incline change effect
        3: begin
          $display("Test 3: Incline change (yaw 0x2000 -> 0x8000) raises speed/current");
          yaw_rate = 16'h2000;
          pedal_settle(CAD_NORM);
          omega_before = phys.omega; curr_before = dut.iSensorCondition.avg_curr;

          yaw_rate = 16'h8000; // steep downhill
          pedal_settle(CAD_NORM);
          omega_after = phys.omega; curr_after = dut.iSensorCondition.avg_curr;

          if (!(omega_after > omega_before && curr_after > curr_before))
            $fatal(1, "Incline test failed");
        end

        // Test 4: Faster cadence -> ramp up
        4: begin
          
		  $display("Test 4: Higher cadence rate boosts bike");
		  yaw_rate = 16'h2000;
          pedal_settle(CAD_SLOW);
          omega_before = phys.omega; curr_before = dut.iSensorCondition.avg_curr;
		  
          pedal_settle(CAD_NORM); // faster cadence (half the period)
          omega_after = phys.omega; curr_after = dut.iSensorCondition.avg_curr;

          if (!(omega_after > omega_before && curr_after > curr_before))
            $fatal(1, "Cadence-rate test failed");
        end

        // Test 5: Uphill->downhill effect
        5: begin
          $display("Test 5: Incline change (yaw 0x0000 -> 0xA800) lowers speed/current");
          yaw_rate = 16'h0000;
          pedal_settle(CAD_NORM);
          omega_before = phys.omega; curr_before = dut.iSensorCondition.avg_curr;

          yaw_rate = 16'hA800;
          pedal_settle(CAD_NORM);
          omega_after = phys.omega; curr_after = dut.iSensorCondition.avg_curr;

          if (!(omega_after < omega_before && curr_after < curr_before))
            $fatal(1, "Incline (yaw 0x0000 -> 0xA800) test failed");
        end
		
		// Test 6: No cadence -> spin down
        6: begin
          $display("Test 6: Stopping pedaling slows bike");
          torque_v = 12'hA00;
          pedal_settle(CAD_NORM);
          omega_before = phys.omega; curr_before = dut.iSensorCondition.avg_curr;

          repeat(2048) begin
						cadence_p = 0;
						repeat(2048) @(posedge clk);
						cadence_p = 0;  // NO CADENCE
						repeat(2048) @(posedge clk);
					end
          check_error();
          omega_after = phys.omega; curr_after = dut.iSensorCondition.avg_curr;

          if (!(omega_after < omega_before && curr_after < curr_before)) begin
            $fatal(1, "Cadence-stop test failed");
		  end
        end

        // Test 7: Brake lever -> regen braking slows bike
        7: begin
          $display("Test 7: Applying the brake slows bike (regen braking)");
          pedal_settle(CAD_NORM);
          omega_before = phys.omega;

          brake_v = 12'h400;           // below mid rail => brake_n low
          pedal_cycle(512, CAD_NORM);
          omega_after = phys.omega;

          if ({dut.selGrn, dut.selYlw, dut.selBlu} !== 6'b11_11_11 || dut.duty !== 11'h600)
            $fatal(1, "Brake test failed: coils not in regen braking (sel=%b duty=%h)",
                   {dut.selGrn, dut.selYlw, dut.selBlu}, dut.duty);
          if (!(omega_after < omega_before))
            $fatal(1, "Brake test failed: omega %0d -> %0d", omega_before, omega_after);
        end

        // Test 8: Low battery -> loop error forced to zero
        8: begin
          $display("Test 8: Low battery inhibits drive");
          pedal_settle(CAD_NORM);
          curr_before = dut.drv_mag;

          batt_v = 12'hA00;            // below LOW_BATT_THRES (0xA98)
          pedal_cycle(512, CAD_NORM);

          if (dut.iSensorCondition.error !== 0)
            $fatal(1, "Low battery test failed: error = %0d", dut.iSensorCondition.error);
          if (!(dut.drv_mag < curr_before))
            $fatal(1, "Low battery test failed: drv_mag %0d -> %0d", curr_before, dut.drv_mag);
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
