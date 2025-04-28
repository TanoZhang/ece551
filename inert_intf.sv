
module inert_intf (
    input clk, rst_n,       
    input INT,          //Active high interrupt from sensor. 
    output logic SS_n,        //Active low chip select for SPI
    output logic SCLK,        //SPI clock
    output MOSI,        //SPI data out
    input MISO,         //SPI data in
    output logic signed [12:0] incline, //Incline data from inertial integrator
    output logic vld     //Valid data from inertial integrator
);

/*
 * internal signals
 */
// data to be written to SPI. 
logic [15:0] cmd;

// SPI interface signals:
logic snd; 
logic done;
logic [15:0] resp; // Response from SPI interface.

// 16 bit timer that waits until rst_n deasserts to start. 
logic [15:0] timer; //Timer for 16 clock cycles

logic INT_ff1, INT_ff2; // Flopped INT signal for meta-stability.

// Inertial data registers.
logic [7:0] rollL, rollH, 
            yawL, yawH, // 8 bit registers for each axis.   
            ayL, ayH, azL, azH;

logic [7:0] LED;

/**
 * Initialize modules.
 */ 
SPI_mnrch iSPI_mnrch (
    .clk(clk),
    .rst_n(rst_n),
    .SS_n(SS_n),
    .SCLK(SCLK),
    .MOSI(MOSI),
    .MISO(MISO),
    .snd(snd),
    .cmd(cmd),
    .done(done),
    .resp(resp)
);

inertial_integrator iInertial_Integrator (
    .clk(clk), 
    .rst_n(rst_n),
    .vld(vld),
    .roll_rt({rollH, rollL}), // 16 bit roll rate data from inertial sensor.
    .yaw_rt({yawH, yawL}),   // 16 bit yaw rate data from inertial sensor.
    .AY({ayH, ayL}),         // 16 bit AY data from inertial sensor.
    .AZ({azH, azL}),         // 16 bit AZ data from inertial sensor.
    .incline(incline),       // 12 bit incline data from inertial sensor.
    .LED(LED)               // 8 bit LED output for incline data.
);

// 16 bit timer block.
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        timer <= 16'h0;
    end else begin
        timer <= timer + 1'b1;
    end
end

// Double flopping INT signal. 
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        INT_ff1 <= 1'b0;
        INT_ff2 <= 1'b0;
    end else begin
        INT_ff1 <= INT; // First flip-flop for meta-stability.
        INT_ff2 <= INT_ff1; // Second flip-flop for meta-stability.
    end
end

typedef enum logic [3:0]{ INIT1, INIT2, INIT3, INIT4, READY, // READY - waiting for new data interrupt from sensor. 
                          READ1, READ2, READ3, READ4,       // READ states - reading and storing data from sensor.
                          READ5, READ6, READ7, READ8, VALID // VALID - indicate to inertial integrator that data is valid. 
                        } state_t;

state_t state, next_state; // State and next state variables for the FSM.

// State register
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    state <= INIT1;
  else
    state <= next_state;
end

always_comb begin
    // Defaults: 
    next_state = state; // Default to current state
    snd = 1'b0; 
    cmd = 16'h0D02;
    vld = 1'b0;

    case (state)
        /**
         *  INITIALIZATION SEQUENCE
         */
        INIT1: begin
            cmd = 16'h0D02; // 0x0D02 - Enable interrupt upon data ready. 
            // Wait for timer to expire before -> INIT2. 
            if (&timer) begin
                next_state = INIT2;
                snd = 1'b1; // initiate SPI transaction. 
            end else begin
                next_state = INIT1;
            end
        end

        INIT2: begin
            cmd = 16'h1053; // Setup accel for 208Hz data rate, +/- 2g accel range, 50Hz LPF
            // Wait for done signal frm SPI. 
            if (done) begin
                next_state = INIT3;
                snd = 1'b1; // initiate SPI transaction. 
            end else begin
                next_state = INIT2;
            end
        end

        INIT3: begin
            cmd = 16'h1150; // Setup gyro for 208Hz data rate, +/- 245°/sec range.
            // Wait for done signal frm SPI. 
            if (done) begin
                next_state = INIT4;
                snd = 1'b1; // initiate SPI transaction. 
            end else begin
                next_state = INIT3;
            end
        end

        INIT4: begin
            cmd = 16'h1460; // Turn rounding on for both accel and gyro
            // Wait for done signal frm SPI. 
            if (done) begin
                next_state = READY;
                snd = 1'b1; // initiate SPI transaction. 
            end else begin
                next_state = INIT4;
            end
        end

        /**
         *  READY STATE
         */
        READY: begin
            // Wait for INT signal to go high. 
            if (INT_ff2) begin
                next_state = READ1; // Go to READ state. 
                snd = 1'b1; // initiate SPI transaction.
            end else begin
                next_state = READY; // Stay in READY state. 
            end
        end

        /**
         *  READ SEQUENCE 
         *  note - all lower bits are don't cares. 
         *  Data must be read into corresponding registers from lower bit of resp. 
         */
        READ1: begin
            cmd = 16'hA4xx;
            // Wait for done signal frm SPI. 
            if (done) begin
                next_state = READ2;
                // Capture data from SPI.
                rollL = resp[7:0]; // Read lower byte of roll data.
                snd = 1'b1; // initiate SPI transaction. 
            end else begin
                next_state = READ1;
            end
        end

        READ2: begin
            cmd = 16'hA5xx;
            // Wait for done signal frm SPI. 
            if (done) begin
                next_state = READ3;
                // Capture data from SPI.
                rollH = resp[7:0]; // Read higher byte of roll data.
                snd = 1'b1; // initiate SPI transaction. 
            end else begin
                next_state = READ2;
            end
        end

        READ3: begin
            cmd = 16'hA6xx;
            // Wait for done signal from SPI. 
            if (done) begin
                next_state = READ4;
                // Capture data from SPI.
                yawL = resp[7:0]; // Read lower byte of yaw data.
                snd = 1'b1; // initiate SPI transaction. 
            end else begin
                next_state = READ3;
            end
        end

        READ4: begin
            cmd = 16'hA7xx;
            // Wait for done signal from SPI. 
            if (done) begin
                next_state = READ5;
                // Capture data from SPI.
                yawH = resp[7:0]; // Read higher byte of yaw data.
                snd = 1'b1; // initiate SPI transaction. 
            end else begin
                next_state = READ4;
            end
        end

        READ5: begin
            cmd = 16'hAAxx;
            // Wait for done signal from SPI. 
            if (done) begin
                next_state = READ6;
                // Capture data from SPI.
                ayL = resp[7:0]; // Read lower byte of ay data.
                snd = 1'b1; // initiate SPI transaction. 
            end else begin
                next_state = READ5;
            end
        end

        READ6: begin
            cmd = 16'hABxx;
            // Wait for done signal from SPI. 
            if (done) begin
                next_state = READ7;
                // Capture data from SPI.
                ayH = resp[7:0]; // Read higher byte of ay data.
                snd = 1'b1; // initiate SPI transaction. 
            end else begin
                next_state = READ6;
            end
        end

        READ7: begin
            cmd = 16'hACxx;
            // Wait for done signal from SPI. 
            if (done) begin
                next_state = READ8;
                // Capture data from SPI.
                azL = resp[7:0]; // Read lower byte of az data.
                snd = 1'b1; // initiate SPI transaction. 
            end else begin
                next_state = READ7;
            end
        end

        READ8: begin
            cmd = 16'hADxx;
            // Wait for done signal from SPI. 
            if (done) begin
                next_state = VALID;
                // Capture data from SPI.
                azH = resp[7:0]; // Read higher byte of az data.
                snd = 1'b1; // initiate SPI transaction. 
            end else begin
                next_state = READ8;
            end
        end

        VALID: begin
            vld = 1'b1; // Indicate to inertial integrator that data is valid.
            next_state = READY; // Go back to READY state.
        end

        default: begin
            next_state = INIT1; // Default to INIT1 state.
        end
    endcase
end
endmodule