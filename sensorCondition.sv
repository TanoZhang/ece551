module sensorCondition #(
    parameter FAST_SIM = 0
) (
    input clk,
    input rst_n,
    input [11:0] torque,
    input cadence_raw,
    input [11:0] curr,
    input signed [12:0] incline,
    input [2:0] scale,
    input [11:0] batt,
    output logic signed [12:0] error,
    output not_pedaling,
    output TX
);

  localparam [11:0] LOW_BATT_THRES = 12'hA98;
  // internal signals
  logic include_curr;
  logic [11:0] avg_curr, target_curr;
  logic [13:0] current_accmulator;
  logic [21:0] timer_current;

  // cadence measurement

  logic cadence_filt, cadence_rise;
  logic [7:0] cadence_per;
  logic [4:0] cadence;

  // torque measurement

  logic [16:0] torque_accumulator;
  logic [11:0] avg_torque;

  // pedaling detection

  logic torque_not_pedaling;
  logic start_pedaling;

  cadence_meas #(
      .FAST_SIM(FAST_SIM)
  ) icadence_meas (
      .clk(clk),
      .rst_n(rst_n),
      .cadence_filt(cadence_filt),
      .cadence_per(cadence_per),
      .not_pedaling(not_pedaling)
  );

  cadence_filt #(
      .FAST_SIM(FAST_SIM)
  ) icadence_filt (
      .clk(clk),
      .rst_n(rst_n),
      .cadence(cadence_raw),
      .cadence_filt(cadence_filt),
      .cadence_rise(cadence_rise)
  );

  cadence_LU icadence_LU (
      .cadence_per(cadence_per),
      .cadence(cadence)
  );

  telemetry itelemetry (
      .clk(clk),
      .rst_n(rst_n),
      .batt_v(batt),
      .avg_curr(avg_curr),
      .avg_torque(avg_torque),
      .TX(TX)
  );

  desiredDrive idesiredDrive (
      .avg_torque(avg_torque),
      .cadence(cadence),
	  .clk(clk),
      .not_pedaling(not_pedaling),
      .incline(incline),
      .scale(scale),
      .target_curr(target_curr)
  );

  // current averaging

  // one sample every 2^22 clocks (84ms); a single bit like timer_current[21] would be high for 2^21 clocks in a row
  assign include_curr = (FAST_SIM) ? (&timer_current[15:0]) : (&timer_current);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) timer_current <= 0;
    else timer_current <= timer_current + 1;
  end

  // current accumulation

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_accmulator <= 0;
    else if (include_curr) current_accmulator <= (current_accmulator * 3 >> 2) + curr;
  end

  assign avg_curr = current_accmulator[13:2];

  // torque averaging

  assign start_pedaling = torque_not_pedaling & ~not_pedaling;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      torque_not_pedaling <= 1;
      torque_accumulator <= 0;
    end else begin
      torque_not_pedaling <= not_pedaling;
      if (start_pedaling) torque_accumulator <= {1'b0, torque, 4'b0};
      else if (cadence_rise) torque_accumulator <= ((torque_accumulator * 31) >> 5) + torque;
    end
  end

  assign avg_torque = torque_accumulator[16:5];

  // compute error
  always_comb begin
    if (batt < LOW_BATT_THRES || not_pedaling) error = 13'd0;
    else error = $signed({1'b0, target_curr}) - $signed({1'b0, avg_curr});
  end
endmodule
