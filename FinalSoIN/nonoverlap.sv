module nonoverlap (clk,rst_n,highIn,lowIn,highOut,lowOut);
    // input and output
    input logic clk, rst_n, highIn, lowIn;
    output logic highOut, lowOut;

    // local logics
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
            if (change) begin
                forced_low <= 1;
                cnt <= 0;
            end
                if (forced_low) begin
                    lowOut <= 0;
                    highOut <= 0;
                    cnt <= cnt + 1;
                        if (cnt == 31) begin
                            forced_low <= 0;
                        cnt  <= 0;
                        highOut <= highIn;
                        lowOut <= lowIn;
                        end
            end else begin
                highOut <= (change) ? 0 : highIn;
                lowOut <= (change) ? 0 : lowIn;
            end
            previous_high <= highIn;
            previous_low <= lowIn;
        end
    end
endmodule