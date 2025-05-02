module mtr_drv (
    input  logic         clk,
    input  logic         rst_n,
    input  logic [10:0]  duty,
    input  logic [1:0]   selGrn,  // drive mode for green coil
    input  logic [1:0]   selYlw,  // drive mode for yellow coil
    input  logic [1:0]   selBlu,  // drive mode for blue coil
    output tri           highGrn, // high side drive for green coil
    output tri           lowGrn,  // low side drive for green coil
    output tri           highYlw, // high side drive for yellow coil
    output tri           lowYlw,  // low side drive for yellow coil
    output tri           highBlu, // high side drive for blue coil
    output tri           lowBlu,  // low side drive for blue coil
output logic PWM_synch
);

    // Internal signals from PWM and nonoverlap modules
    logic pwm_sig;

    // Instantiate PWM generator module
    PWM pwm11 (
         .clk     (clk),
         .rst_n   (rst_n),
         .duty    (duty),
         .PWM_sig (pwm_sig),
	 .PWM_synch(PWM_synch)
    );

    // Internal registers to hold drive outputs
    logic highGrnIn, lowGrnIn;
    logic highBluIn, lowBluIn;
    logic highYlwIn, lowYlwIn;

    // Instantiate nonoverlap module to ensure dead time
    nonoverlap nonoverlap_grn (
         .clk      (clk),
         .rst_n    (rst_n),
    .highIn(highGrnIn),   // Control input for high side FET
    .lowIn(lowGrnIn),    // Control input for low side FET
    .highOut(highGrn),  // Output for high side FET (dead time enforced)
    .lowOut(lowGrn)   
    );

    // Instantiate nonoverlap module to ensure dead time
    nonoverlap nonoverlap_ylw (
         .clk      (clk),
         .rst_n    (rst_n),
    .highIn(highYlwIn),   // Control input for high side FET
    .lowIn(lowYlwIn),    // Control input for low side FET
    .highOut(highYlw),  // Output for high side FET (dead time enforced)
    .lowOut(lowYlw)   
    );

    // Instantiate nonoverlap module to ensure dead time
    nonoverlap nonoverlap_blu (
         .clk      (clk),
         .rst_n    (rst_n),
    .highIn(highBluIn),   // Control input for high side FET
    .lowIn(lowBluIn),    // Control input for low side FET
    .highOut(highBlu),  // Output for high side FET (dead time enforced)
    .lowOut(lowBlu)   
    );


    // Drive logic for green coil
    always_comb begin
       case (selGrn)
         2'b00: begin  // Not driven: high impedance on both outputs
            highGrnIn = 1'b0;
            lowGrnIn  = 1'b0;
         end
         2'b11: begin  // Reverse current: high side gets pwm_lo, low side gets pwm_hi
            highGrnIn = 1'b0;
            lowGrnIn  = pwm_sig;
         end
         2'b01: begin  // Forward current: high side gets pwm_hi, low side gets pwm_lo
            highGrnIn = ~pwm_sig;
            lowGrnIn  = pwm_sig;
         end
         2'b10: begin  // Dynamic braking: high side is 0, low side gets pwm_lo
            highGrnIn = pwm_sig;
            lowGrnIn  = ~pwm_sig;
         end
       endcase
    end

    // Drive logic for green coil
    always_comb begin
       case (selBlu)
         2'b00: begin  // Not driven: high impedance on both outputs
            highBluIn = 1'b0;
            lowBluIn  = 1'b0;
         end
         2'b11: begin  // Reverse current: high side gets pwm_lo, low side gets pwm_hi
            highBluIn = 1'b0;
            lowBluIn  = pwm_sig;
         end
         2'b01: begin  // Forward current: high side gets pwm_hi, low side gets pwm_lo
            highBluIn = ~pwm_sig;
            lowBluIn  = pwm_sig;
         end
         2'b10: begin  // Dynamic braking: high side is 0, low side gets pwm_lo
            highBluIn = pwm_sig;
            lowBluIn  = ~pwm_sig;
         end
       endcase
    end

    // Drive logic for green coil
    always_comb begin
       case (selYlw)
         2'b00: begin  // Not driven: high impedance on both outputs
            highYlwIn = 1'b0;
            lowYlwIn  = 1'b0;
         end
         2'b11: begin  // Reverse current: high side gets pwm_lo, low side gets pwm_hi
            highYlwIn = 1'b0;
            lowYlwIn  = pwm_sig;
         end
         2'b01: begin  // Forward current: high side gets pwm_hi, low side gets pwm_lo
            highYlwIn = ~pwm_sig;
            lowYlwIn  = pwm_sig;
         end
         2'b10: begin  // Dynamic braking: high side is 0, low side gets pwm_lo
            highYlwIn = pwm_sig;
            lowYlwIn  = ~pwm_sig;
         end
       endcase
    end

endmodule

