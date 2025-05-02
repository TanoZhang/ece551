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

    // Define states
    typedef enum logic [3:0] {INIT1, INIT2, INIT3, INIT4, WAIT, 
                              READ1, READ2, READ3, READ4, READ5, 
                              READ6, READ7, READ8, FINISH} state_t;

    state_t state, nxt_state;

    //intermediate signals
    logic snd, done;
    logic [15:0] cmd, resp;
    logic [15:0] timer;
    logic [15:0] roll_rt, yaw_rt, AY, AZ;
    logic INT_ff1, INT_ff2;
    logic rollH, rollL, yawH, yawL, AYH, AYL, AZH, AZL;           // Enable update of correct register with resp

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
        rollL = 0;
        rollH = 0;
        yawL = 0;
        yawH = 0;
        AYL = 0;
        AYH = 0;
        AZL = 0;
        AZH = 0;

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
                    nxt_state = READ1;
                end
            end
            READ1: begin
                cmd = 16'hA4xx;
                if (INT_ff2) begin
                    snd = 1;
                    nxt_state = READ2;
                end
            end
            READ2: begin
                cmd = 16'hA5xx;
                if (done) begin
                    snd = 1;
                    rollL = 1;
                    nxt_state = READ3;
                end
            end
            READ3: begin
                cmd = 16'hA6xx;
                if (done) begin
                    snd = 1;
                    rollH = 1;
                    nxt_state = READ4;
                end
            end
            READ4: begin
                cmd = 16'hA7xx;
                if (done) begin
                    snd = 1;
                    yawL = 1;
                    nxt_state = READ5;
                end
            end
            READ5: begin
                cmd = 16'hAAxx;
                if (done) begin
                    snd = 1;
                    yawH = 1;
                    nxt_state = READ6;
                end
            end
            READ6: begin
                cmd = 16'hABxx;
                if (done) begin
                    snd = 1;
                    AYL = 1;
                    nxt_state = READ7;
                end
            end
            READ7: begin
                cmd = 16'hACxx;
                if (done) begin
                    snd = 1;
                    AYH = 1;
                    nxt_state = READ8;
                end
            end
            READ8: begin
                cmd = 16'hADxx;
                if (done) begin
                    snd = 1;
                    AZL = 1;
                    nxt_state = FINISH;
                end
            end
            // Default = FINISH
            default: begin
                cmd = 16'hxxxx;
                if (done) begin
                    vld = 1;            // Valid delayed by 1 clock cycle in inertial_integrator so asserted at same time as AZH
                    AZH = 1;
                    nxt_state = READ1;
                end
            end
        endcase
    end

    // Timer
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            timer <= 0;
        else 
            timer <= timer + 1;
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

    // Registers
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            roll_rt[7:0] <= 0;
        else if (rollL) 
            roll_rt[7:0] <= resp[7:0];
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            roll_rt[15:8] <= 0;
        else if (rollH) 
            roll_rt[15:8] <= resp[7:0];
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            yaw_rt[7:0] <= 0;
        else if (yawL) 
            yaw_rt[7:0] <= resp[7:0];
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            yaw_rt[15:8] <= 0;
        else if (yawH) 
            yaw_rt[15:8] <= resp[7:0];
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            AY[7:0] <= 0;
        else if (AYL) 
            AY[7:0] <= resp[7:0];
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            AY[15:8] <= 0;
        else if (AYH) 
            AY[15:8] <= resp[7:0];
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            AZ[7:0] <= 0;
        else if (AZL) 
            AZ[7:0] <= resp[7:0];
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) 
            AZ[15:8] <= 0;
        else if (AZH) 
            AZ[15:8] <= resp[7:0];
    end

endmodule