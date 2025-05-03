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

    logic PWM_sig;                  // Internal PWM signal
    logic grn1, grn2;               // Intermediate green signals
    logic ylw1, ylw2;               // Intermediate yellow signals
    logic blu1, blu2;               // Intermediate blue signals

    // Instantiate PWM
    PWM PWM11(
        .clk(clk),
        .rst_n(rst_n),
        .duty(duty),
        .PWM_synch(PWM_synch),      
        .PWM_sig(PWM_sig)           
    );

    // Green non-overlap driver
    nonoverlap GREEN(
        .clk(clk),
        .rst_n(rst_n),
        .highIn(grn1),              
        .lowIn(grn2),              
        .highOut(highGrn),         
        .lowOut(lowGrn)             
    );

    // Yellow non-overlap driver
    nonoverlap YELLOW(
        .clk(clk),
        .rst_n(rst_n),
        .highIn(ylw1),
        .lowIn(ylw2),
        .highOut(highYlw),
        .lowOut(lowYlw)
    );

    // Blue non-overlap driver
    nonoverlap BLUE(
        .clk(clk),
        .rst_n(rst_n),
        .highIn(blu1),
        .lowIn(blu2),
        .highOut(highBlu),
        .lowOut(lowBlu)
    );

    // Selector logic
    always_comb begin
        // output for yellow
        {ylw1, ylw2} = (selYlw == 2'b01) ? {~PWM_sig, PWM_sig} : (selYlw == 2'b10) ? {PWM_sig, ~PWM_sig} : (selYlw == 2'b11) ? {1'b0, PWM_sig} : {1'b0, 1'b0};
        // output for green
        {grn1, grn2} = (selGrn == 2'b01) ? {~PWM_sig, PWM_sig} : (selGrn == 2'b10) ? {PWM_sig, ~PWM_sig} : (selGrn == 2'b11) ? {1'b0, PWM_sig} : {1'b0, 1'b0};   
        // output for blue
        {blu1, blu2} = (selBlu == 2'b01) ? {~PWM_sig, PWM_sig} : (selBlu == 2'b10) ? {PWM_sig, ~PWM_sig} : (selBlu == 2'b11) ? {1'b0, PWM_sig} : {1'b0, 1'b0};
    end
    
endmodule
