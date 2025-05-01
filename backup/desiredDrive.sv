module desiredDrive (
    input  logic [11:0] avg_torque,
    input  logic [4:0] cadence,
    input  logic [12:0] incline,
    input  logic [2:0] scale,
    input  logic not_pedaling,
    output logic [11:0] target_curr
);

    localparam TORQUE_MIN = 12'h380; // Offset for torque sensor

    // Compute torque offset
    logic [12:0] torque_off;
    assign torque_off = {1'b0, avg_torque} - TORQUE_MIN;

    // Clip torque to zero
    logic [11:0] torque_pos;
    assign torque_pos = (torque_off[12]) ? 12'b0 : torque_off[11:0];

    logic [9:0] incline_sat;
    assign incline_sat = (incline > 10'sd511) ? 10'd511 :
                         (incline < -10'sd512) ? 10'd0 : incline[9:0];

    // Adjust incline factor
    logic [10:0] incline_factor;
    assign incline_factor = incline_sat + 11'd256;

    //incline factor to max 511, min 0
    logic [8:0] incline_lim;
    assign incline_lim = (incline_factor[10]) ? 9'd0 :
                         (incline_factor > 9'd511) ? 9'd511 : incline_factor[8:0];

    logic [6:0] cadence_factor;
    assign cadence_factor = (cadence > 5'd1) ? (cadence + 7'd32) : 7'd0;

    // Compute assist amount
    logic [29:0] assist_prod;
    assign assist_prod = (not_pedaling) ? 30'b0 :
                         (torque_pos * incline_lim * cadence_factor * scale);

    //current output
    always_comb begin
        if (not_pedaling)
            target_curr = 12'h000;
        else if (|assist_prod[29:26])
            target_curr = 12'hFFF; // Cap at max if overflow
        else
            target_curr = assist_prod[25:14];
    end

endmodule
