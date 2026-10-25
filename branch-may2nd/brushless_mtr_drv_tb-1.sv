//
// brushless_mtr_drv_tb.sv
//
// Testbench that instantiates:
//   1) brushless module (generates duty, selGrn/selYlw/selBlu)
//   2) mtr_drv module (generates hi/lo signals per phase with nonoverlap & PWM)
// 
//
module brushless_mtr_drv_tb;

  // ------------------------------------------------
  // 1) Testbench stimulus signals
  // ------------------------------------------------
  reg         clk;
  reg         rst_n;
  reg  [11:0] drv_mag;    // motor drive magnitude
  reg  [2:0]  hallStim;   // {hallGrn,hallYlw,hallBlu}
  reg         brake_n;    // active-low brake

  // ------------------------------------------------
  // Internal signals connecting brushless -> mtr_drv
  // ------------------------------------------------
  wire         pwm_synch; // sync pulse from PWM
  wire [10:0]  duty;
  wire [1:0]   selGrn, selYlw, selBlu;

  // ------------------------------------------------
  // Outputs from mtr_drv (the six coil signals)
  // ------------------------------------------------
  wire highGrn, lowGrn;
  wire highYlw, lowYlw;
  wire highBlu, lowBlu;

  // ------------------------------------------------
  // 2) Instantiate the brushless module (DUT #1)
  //    This design outputs 'duty' and 'sel*' lines
  //    based on hall sensors, brake, etc.
  // ------------------------------------------------
  brushless DUT_brushless (
    .clk       (clk),
    .rst_n     (rst_n),
    .drv_mag   (drv_mag),
    .PWM_synch (pwm_synch),    // brushless may latch hall inputs on this sync
    .hallGrn   (hallStim[2]),
    .hallYlw   (hallStim[1]),
    .hallBlu   (hallStim[0]),
    .brake_n   (brake_n),
    .duty      (duty),
    .selGrn    (selGrn),
    .selYlw    (selYlw),
    .selBlu    (selBlu)
  );

  // ------------------------------------------------
  // 3) Instantiate the mtr_drv module (DUT #2)
  //    This drives final hi/lo coil signals
  //    using the newly updated PWM and nonoverlap
  // ------------------------------------------------
  mtr_drv DUT_mtr_drv (
    .clk      (clk),
    .rst_n    (rst_n),
    .duty     (duty),
    .selGrn   (selGrn),
    .selYlw   (selYlw),
    .selBlu   (selBlu),
    .highGrn    (highGrn),
    .lowGrn    (lowGrn),
    .highYlw    (highYlw),
    .lowYlw  (lowYlw),
    .highBlu    (highBlu),
    .lowBlu    (lowBlu),
    .PWM_synch(pwm_synch)    // from PWM inside mtr_drv
  );

  // ------------------------------------------------
  // 4) Clock generation: 50 MHz => period = 20 ns
  // ------------------------------------------------
  initial clk = 1'b0;
  always #10 clk = ~clk;

  // ------------------------------------------------
  // 5) Test Sequence
  //    - Reset
  //    - Step through Hall states at rising edges of pwm_synch
  //    - Check invalid states, brake mode, different drv_mag
  // ------------------------------------------------
  initial begin
    // (a) Initialize signals
    rst_n    = 1'b0;
    brake_n  = 1'b1;   // normal (not braking)
    drv_mag  = 12'h300; // some moderate drive
    hallStim = 3'b101; // typical start from your table

    // (b) Release reset after 20 ns
    #20  rst_n = 1'b1;
    #50;

    // Step through your 6-step forward commutation at each rising edge of pwm_synch
    wait_rising_pwm_synch();
    hallStim = 3'b100; 
    wait_rising_pwm_synch();
    hallStim = 3'b110;
    wait_rising_pwm_synch();
    hallStim = 3'b010;
    wait_rising_pwm_synch();
    hallStim = 3'b011;
    wait_rising_pwm_synch();
    hallStim = 3'b001;
    wait_rising_pwm_synch();
    hallStim = 3'b101; // cycle back

    // (c) Invalid Hall state test
    wait_rising_pwm_synch();
    hallStim = 3'b000; // invalid => brushless should force outputs off
    #50;
    hallStim = 3'b101; // restore a valid state
    #100;

    // (d) Enter brake mode
    wait_rising_pwm_synch();
    brake_n = 1'b0;  // brake => should see REGEN logic
    #100;
    brake_n = 1'b1;  // normal mode again

    // (e) Increase drive magnitude
    #200;
    drv_mag = 12'hFFF; // maximum drive
    #500;

    // Done
    $display("TEST COMPLETE. Stopping simulation...");
    $stop;
  end

  // ------------------------------------------------
  // 6) Task: wait for rising edge of pwm_synch
  //    (In case brushless logic triggers on that event)
  // ------------------------------------------------
  task wait_rising_pwm_synch();
  begin
    // Wait until pwm_synch goes LOW
    @(posedge clk);
    while (pwm_synch == 1'b1) @(posedge clk);

    // Now wait until it goes HIGH
    while (pwm_synch == 1'b0) @(posedge clk);
    #1; // small delay after detection
  end
  endtask

endmodule

