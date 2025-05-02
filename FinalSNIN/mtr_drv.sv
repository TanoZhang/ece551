//Driver module for motor
module mtr_drv(
    input logic clk,                // Clock input
    input logic rst_n,              // Active-low reset
    input logic [10:0] duty,        // PWM duty cycle 
    input logic [1:0] selGrn,       // Green select signal
    input logic [1:0] selYlw,       // Yellow select signal
    input logic [1:0] selBlu,       // Blue select signal
    output logic PWM_synch,         // Synchronization signal 
    output logic highGrn,           // Green high drive
    output logic lowGrn,            // Green low drive
    output logic highYlw,           // Yellow high drive
    output logic lowYlw,            // Yellow low drive
    output logic highBlu,           // Blue high drive
    output logic lowBlu             // Blue low drive
);

    logic PWM_sig;                  // PWM signal
    logic green1, green2;               // Intermediate green signals
    logic yellow1, yellow2;               // Intermediate yellow signals
    logic blue1, blue2;               // Intermediate blue signals

    // Instantiate PWM
    PWM PWM11(.clk(clk), .rst_n(rst_n), .duty(duty), .PWM_synch(PWM_synch), .PWM_sig(PWM_sig));

    // Green Instantiate
    nonoverlap green_nonoverlap(.clk(clk), .rst_n(rst_n), .highIn(green1), .lowIn(green2), .highOut(highGrn), .lowOut(lowGrn));

    // Yellow Instantiate
    nonoverlap yellow_nonoverlap(.clk(clk), .rst_n(rst_n), .highIn(yellow1), .lowIn(yellow2), .highOut(highYlw), .lowOut(lowYlw));

    // Blue Instantiate
    nonoverlap blue_nonverlap(.clk(clk), .rst_n(rst_n), .highIn(blue1), .lowIn(blue2), .highOut(highBlu), .lowOut(lowBlu));

    // logic of selector
    always_comb begin
        {green1, green2} = (selGrn == 2'b01) ? {~PWM_sig, PWM_sig} :  
                       (selGrn == 2'b10) ? {PWM_sig, ~PWM_sig} :   
                       (selGrn == 2'b11) ? {1'b0, PWM_sig} :      
                                           {1'b0, 1'b0};          

        {yellow1, yellow2} = (selYlw == 2'b01) ? {~PWM_sig, PWM_sig} :
                       (selYlw == 2'b10) ? {PWM_sig, ~PWM_sig} :
                       (selYlw == 2'b11) ? {1'b0, PWM_sig} :
                                           {1'b0, 1'b0};

        {blue1, blue2} = (selBlu == 2'b01) ? {~PWM_sig, PWM_sig} :
                       (selBlu == 2'b10) ? {PWM_sig, ~PWM_sig} :
                       (selBlu == 2'b11) ? {1'b0, PWM_sig} :
                                           {1'b0, 1'b0};
    end
endmodule