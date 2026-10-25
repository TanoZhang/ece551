module inert_intf(clk, rst_n, SS_n, SCLK, MOSI, MISO, INT, incline, vld);
    input logic clk; 
    input logic rst_n; 
    input logic INT;
    input logic MISO; 
    output logic SS_n;
    output logic MOSI;
    output logic SCLK; 
    output logic vld;
    output logic signed [12:0] incline;

    //local signals
    logic [15:0] cmd, resp;
    logic [15:0] timekeeper;
    logic snd, done;
    logic [15:0] roll_rt, yaw_rt, AY, AZ;
    logic sync_int1, sync_int2, RH_en, RL_en, YH_en, YL_en, AH_en, AL_en, AZH_en, AZL_en;

    // different states
    typedef enum logic [3:0] {phase1, phase2, phase3, phase4, phase_halt, acquiring1, acquiring2, acquiring3, acquiring4, acquiring5, acquiring6, acquring7, acquiring8, phase_stop} state_t;
    state_t state, next_state;

    //inertia integrator instantiation
    inertial_integrator iInertial_integrator(.clk(clk), .rst_n(rst_n), .vld(vld), .roll_rt(roll_rt), .yaw_rt(yaw_rt), .AY(AY), .AZ(AZ), .incline(incline), .LED());

    // SPI_mnrch Instantiation
    SPI_mnrch iSPI_mnrch(.clk(clk), .rst_n(rst_n), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .snd(snd), .cmd(cmd), .done(done), .resp(resp));

    //start state flipflop
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) state <= phase1;
        else state <= next_state;
    end

    always_comb begin
        // initialization
        cmd = 16'h0D02;
        snd = 0;        vld = 0;
        next_state = state;
        RL_en = 0;        RH_en = 0;
        YL_en = 0;        YH_en = 0;
        AL_en = 0;        AH_en = 0;
        AZL_en = 0;        AZH_en = 0;

        unique case (state)
            phase1: begin
                if (&timekeeper) begin
                    snd = 1;
                    next_state = phase2;
                end
            end
            phase2: begin
                cmd = 16'h1053;
                if (done) begin
                    snd = 1;
                    next_state = phase3;
                end
            end
            phase3: begin 
                cmd = 16'h1150;
                if (done) begin
                    snd = 1;
                    next_state = phase4;
                end
            end
            phase4: begin
                cmd = 16'h1460;
                if (done) begin
                    snd = 1;
                    next_state = phase_halt;
                end
            end
            phase_halt: begin
                cmd = 16'hxxxx;
                if (done) begin
                    next_state = acquiring1;
                end
            end
            acquiring1: begin
                cmd = 16'hA4xx;
                if (sync_int2) begin
                    snd = 1;
                    next_state = acquiring2;
                end
            end
            acquiring2: begin
                cmd = 16'hA5xx;
                if (done) begin
                    snd = 1;
                    RL_en = 1;
                    next_state = acquiring3;
                end
            end
            acquiring3: begin
                cmd = 16'hA6xx;
                if (done) begin
                    snd = 1;
                    RH_en = 1;
                    next_state = acquiring4;
                end
            end
            acquiring4: begin
                cmd = 16'hA7xx;
                if (done) begin
                    snd = 1;
                    YL_en = 1;
                    next_state = acquiring5;
                end
            end
            acquiring5: begin
                cmd = 16'hAAxx;
                if (done) begin
                    snd = 1;
                    YH_en = 1;
                    next_state = acquiring6;
                end
            end
            acquiring6: begin
                cmd = 16'hABxx;
                if (done) begin
                    snd = 1;
                    AL_en = 1;
                    next_state = acquring7;
                end
            end
            acquring7: begin
                cmd = 16'hACxx;
                if (done) begin
                    snd = 1;
                    AH_en = 1;
                    next_state = acquiring8;
                end
            end
            acquiring8: begin
                cmd = 16'hADxx;
                if (done) begin
                    snd = 1;
                    AZL_en = 1;
                    next_state = phase_stop;
                end
            end
            phase_stop: begin
                cmd = 16'hxxxx;
                if (done) begin
                    AZH_en = 1;
                    vld = 1;
                    next_state = acquiring1;
                end
            end
            default: next_state = phase1;
        endcase
    end

    // timekeeper
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            timekeeper <= 0;
        else 
            timekeeper <= timekeeper + 1;
    end

    // int signal come in
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            sync_int1 <= 0;
            sync_int2 <= 0;
        end else begin
            sync_int1 <= INT;
            sync_int2 <= sync_int1;
        end
    end

    // Registers
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            roll_rt[7:0] <= 0;
        else if (RL_en) 
            roll_rt[7:0] <= resp[7:0];
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            roll_rt[15:8] <= 0;
        else if (RH_en) 
            roll_rt[15:8] <= resp[7:0];
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            yaw_rt[7:0] <= 0;
        else if (YL_en) 
            yaw_rt[7:0] <= resp[7:0];
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            yaw_rt[15:8] <= 0;
        else if (YH_en) 
            yaw_rt[15:8] <= resp[7:0];
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            AY[7:0] <= 0;
        else if (AL_en) 
            AY[7:0] <= resp[7:0];
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            AY[15:8] <= 0;
        else if (AH_en) 
            AY[15:8] <= resp[7:0];
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            AZ[7:0] <= 0;
        else if (AZL_en) 
            AZ[7:0] <= resp[7:0];
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            AZ[15:8] <= 0;
        else if (AZH_en) 
            AZ[15:8] <= resp[7:0];
    end

endmodule