module sensorCondition #(parameter FAST_SIM = 0)
(
    input  clk,
    input  rst_n,
    input  [11:0] torque,
    input  cadence_raw,
    input  [11:0] curr,
    input  [12:0] incline,
    input  [2:0]  scale,
    input  [11:0] batt,
    output logic [12:0] error,
    output not_pedaling,
    output TX
);

    localparam [11:0] LOW_BATT_THRES = 12'hA98;

    // internal signals
    // current averaging
    logic [13:0] curr_accum;
    logic [11:0] avg_curr;
    logic include_curr;
    logic [21:0] curr_timer;
    logic [11:0] target_curr;

    // cadence measurement
    logic cadence_filt, cadence_rise;
    logic [7:0] cadence_per;
    logic [4:0] cadence;

    // torque measurement
    logic [16:0] torque_accum;
    logic [11:0] avg_torque;

    // pedaling detection
    logic not_pedaling_torque;
    logic pedaling_start;

    cadence_meas #(.FAST_SIM(FAST_SIM)) iCAD_meas (
        .clk(clk),
        .rst_n(rst_n),
        .cadence_filt(cadence_filt),
        .cadence_per(cadence_per),
        .not_pedaling(not_pedaling)
    );

    cadence_filt #(.FAST_SIM(FAST_SIM)) iCAD_filt (
        .clk(clk),
        .rst_n(rst_n),
        .cadence(cadence_raw),
        .cadence_filt(cadence_filt),
        .cadence_rise(cadence_rise)
    );

    cadence_LU iCAD_LU (
        .cadence_per(cadence_per),
        .cadence(cadence)
    );

    telemetry iDUT_tel (
        .clk(clk),
        .rst_n(rst_n),
        .batt_v(batt),
        .avg_curr(avg_curr),
        .avg_torque(avg_torque),
        .TX(TX)
    );

    desiredDrive iDUT_drv (
        .avg_torque(avg_torque),
        .cadence(cadence),
        .not_pedaling(not_pedaling),
        .incline(incline),
        .scale(scale),
        .target_curr(target_curr)
    );

    // current averaging
    assign include_curr = (FAST_SIM) ? (&curr_timer[15:0]) : curr_timer[21];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            curr_timer <= 0;
        else
            curr_timer <= curr_timer + 1;
    end

    // current accumulation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            curr_accum <= 0;
        else if (include_curr)
            curr_accum <= (curr_accum * 3 >> 2) + curr;
    end

    assign avg_curr = curr_accum[13:2];

    // torque averaging
    assign pedaling_start = not_pedaling_torque & ~not_pedaling;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            not_pedaling_torque <= 1;
            torque_accum <= 0;
        end else begin
            not_pedaling_torque <= not_pedaling;
            if (pedaling_start)
                torque_accum <= {1'b0, torque, 4'b0};
            else if (cadence_rise)
                torque_accum <= ((torque_accum * 31) >> 5) + torque;
        end
    end

    assign avg_torque = torque_accum[16:5];

    // compute error
    always_comb begin
        if (batt < LOW_BATT_THRES || not_pedaling)
            error = 13'd0;
        else
            error = $signed(target_curr) - $signed(avg_curr);
    end

    

endmodule