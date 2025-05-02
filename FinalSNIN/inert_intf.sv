`default_nettype none
/*
    Determines incline of bike based on inertial sensor readings
*/
module inert_intf(clk, rst_n, SS_n, SCLK, MOSI, MISO, INT, incline, vld);

    input logic clk, rst_n, MISO, INT;
    output logic SS_n, SCLK, MOSI, vld;
    output logic signed [12:0] incline;

    // Define states
    typedef enum logic [3:0] {INIT1, INIT2, INIT3, INIT4, WAIT, ROLL_L, ROLL_H, YAW_L, YAW_H, AY_L, AY_H, AZ_L, AZ_H, FINISH} state_t;
    state_t state, nxt_state;

    // Intermediate signals
    logic snd, done;
    logic [15:0] cmd, resp;
    logic [15:0] roll_rt, yaw_rt, AY, AZ;
    logic [15:0] timer;
    logic INT_ff1, INT_ff2;
    logic C_R_H, C_R_L, C_Y_H, C_Y_L, C_AY_H, C_AY_L, C_AZ_H, C_AZ_L;           // Enable update of correct register with resp

    // Instantiate SPI_mnrch
    SPI_mnrch iSPI_mnrch(.clk(clk), .rst_n(rst_n), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .snd(snd), .cmd(cmd), .done(done), .resp(resp));

    // Instantiate inertial_integrator
    inertial_integrator iInertial_integrator(.clk(clk), .rst_n(rst_n), .vld(vld), .roll_rt(roll_rt), .yaw_rt(yaw_rt), .AY(AY), .AZ(AZ), .incline(incline), .LED());

    // Infer state flops
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) state <= INIT1;
        else state <= nxt_state;
    end

    // State machine logic
    always_comb begin

        // Default outputs
        cmd = 16'h0D02;
        snd = 0;
        vld = 0;
        nxt_state = state;
        C_R_L = 0;
        C_R_H = 0;
        C_Y_L = 0;
        C_Y_H = 0;
        C_AY_L = 0;
        C_AY_H = 0;
        C_AZ_L = 0;
        C_AZ_H = 0;

        unique case (state)
            INIT1: begin
                // Default cmd = 16'h0D02
                if (&timer) begin
                    snd = 1;
                    nxt_state = INIT2;
                end
            end
            INIT2: begin
                cmd = 16'h1053;
                if (done) begin
                    snd = 1;
                    nxt_state = INIT3;
                end
            end
            INIT3: begin 
                cmd = 16'h1150;
                if (done) begin
                    snd = 1;
                    nxt_state = INIT4;
                end
            end
            INIT4: begin
                cmd = 16'h1460;
                if (done) begin
                    snd = 1;
                    nxt_state = WAIT;
                end
            end
            WAIT: begin
                cmd = 16'hxxxx;
                if (done) begin
                    nxt_state = ROLL_L;
                end
            end
            ROLL_L: begin
                cmd = 16'hA4xx;
                if (INT_ff2) begin
                    snd = 1;
                    nxt_state = ROLL_H;
                end
            end
            ROLL_H: begin
                cmd = 16'hA5xx;
                if (done) begin
                    snd = 1;
                    C_R_L = 1;
                    nxt_state = YAW_L;
                end
            end
            YAW_L: begin
                cmd = 16'hA6xx;
                if (done) begin
                    snd = 1;
                    C_R_H = 1;
                    nxt_state = YAW_H;
                end
            end
            YAW_H: begin
                cmd = 16'hA7xx;
                if (done) begin
                    snd = 1;
                    C_Y_L = 1;
                    nxt_state = AY_L;
                end
            end
            AY_L: begin
                cmd = 16'hAAxx;
                if (done) begin
                    snd = 1;
                    C_Y_H = 1;
                    nxt_state = AY_H;
                end
            end
            AY_H: begin
                cmd = 16'hABxx;
                if (done) begin
                    snd = 1;
                    C_AY_L = 1;
                    nxt_state = AZ_L;
                end
            end
            AZ_L: begin
                cmd = 16'hACxx;
                if (done) begin
                    snd = 1;
                    C_AY_H = 1;
                    nxt_state = AZ_H;
                end
            end
            AZ_H: begin
                cmd = 16'hADxx;
                if (done) begin
                    snd = 1;
                    C_AZ_L = 1;
                    nxt_state = FINISH;
                end
            end
            // Default = FINISH
            default: begin
                cmd = 16'hxxxx;
                if (done) begin
                    vld = 1;            // Valid delayed by 1 clock cycle in inertial_integrator so asserted at same time as C_AZ_H
                    C_AZ_H = 1;
                    nxt_state = ROLL_L;
                end
            end
        endcase
    end

    // Infer timer flop
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) timer <= 0;
        else timer <= timer + 1;
    end

    // Synchronize INT signal
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            INT_ff1 <= 0;
            INT_ff2 <= 0;
        end else begin
            INT_ff1 <= INT;
            INT_ff2 <= INT_ff1;
        end
    end

    // Infer holding registers
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) roll_rt[7:0] <= 0;
        else if (C_R_L) roll_rt[7:0] <= resp[7:0];
    end
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) roll_rt[15:8] <= 0;
        else if (C_R_H) roll_rt[15:8] <= resp[7:0];
    end
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) yaw_rt[7:0] <= 0;
        else if (C_Y_L) yaw_rt[7:0] <= resp[7:0];
    end
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) yaw_rt[15:8] <= 0;
        else if (C_Y_H) yaw_rt[15:8] <= resp[7:0];
    end
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) AY[7:0] <= 0;
        else if (C_AY_L) AY[7:0] <= resp[7:0];
    end
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) AY[15:8] <= 0;
        else if (C_AY_H) AY[15:8] <= resp[7:0];
    end
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) AZ[7:0] <= 0;
        else if (C_AZ_L) AZ[7:0] <= resp[7:0];
    end
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) AZ[15:8] <= 0;
        else if (C_AZ_H) AZ[15:8] <= resp[7:0];
    end
endmodule