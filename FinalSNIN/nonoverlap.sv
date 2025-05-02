module nonoverlap (clk,rst_n,highIn,lowIn,highOut,lowOut);
    input logic clk;
    input logic rst_n;
    input logic highIn; 
    input logic lowIn;
    output logic highOut;
    output logic lowOut;

    // internal singlas
    logic change, previous_low, previous_high, forced_low;
    logic [5:0] cnt; //counter

    // change the signal
    assign change = (!forced_low) && ((highIn != previous_high) || (lowIn != previous_low));

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)begin
            cnt <= 0;
            highOut <= 0;
            lowOut <= 0;
            forced_low <= 0;
            previous_low <= 0; 
            previous_high <= 0;
        end else begin
            // When there is a change in input signals, enter forced low state.
            if (change) begin
                forced_low <= 1;
                cnt <= 0;
            end
                if (forced_low) begin
                    // during low period, set highOut and lowOut to 0
                    lowOut <= 0;
                    highOut <= 0;
                    cnt <= cnt + 1;
                        if (cnt == 31) begin
                            // After 32 cycles, exit forced low state. 
                            highOut <= highIn;
                            lowOut <= lowIn;
                            forced_low <= 0;
                            cnt  <= 0;
                        end
            end else begin
                highOut <= (change) ? 0 : highIn;
                lowOut <= (change) ? 0 : lowIn;
            end
            // store current inputs
            previous_high <= highIn;
            previous_low <= lowIn;
        end
    end
endmodule