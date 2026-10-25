module PB_intf (
    input tgglMd,           // Push button toggles through assist modes. 
    input rst_n, clk,
    output logic [1:0] setting,
    output logic [2:0] scale
);

// intermediate signal between flops
logic q1, q2, q3;

// Combinational output.
assign rise = ~q3 & q2;


// Rising edge detector (active low signal)
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        q1 <= 1'b1;
        q2 <= 1'b1;
        q3 <= 1'b1;
    end
    else begin
        q1 <= tgglMd;
        q2 <= q1;
        q3 <= q2;
    end
end

// Setting Counter
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        setting <= 2'b10; // default (medium assist)
    end
    if (!q3) begin        // rising edge detected.
        setting <= setting + 2'b1;
    end
end

// Map setting to scale
always_comb begin
    case (setting) 
        2'b00: 
            scale = 3'b000;
        2'b01: 
            scale = 3'b011;
        2'b11: 
            scale = 3'b111;
        default:    // setting of 10 is default
            scale = 3'b101;
    endcase
end

endmodule

