module desiredDrive(
    input [11:0]avg_torque,     // Unsigned torque the rider is putting on the cranks
    input [4:0]cadence,         // Unsigned number proportional to the sqrt of the speed of pedaling
    input not_pedaling,         // Asserts if cadence is so slow that rider is not pedaling
    input signed [12:0]incline,        // Signed incline
    input [2:0]scale,
    output [11:0]target_curr
);
localparam TORQUE_MIN = 12'h380;

// Saturate incline with module
logic [9:0]incline_sat;
incline_sat sat(.incline(incline[12:0]), .incline_sat(incline_sat[9:0]));

// Create incline factor
logic [10:0]incline_factor;
// Sign extend and add 256
assign incline_factor = {incline_sat[9], incline_sat} + 10'b0100_0000_00;

// Limit incline factor
logic [8:0] incline_lim;
assign incline_lim = (incline_factor[10]==1'b1) ? 9'b000000000 :
                     (incline_factor[10:0]==10'b0111111111) ? 9'b010000000 :
                     incline_factor[8:0];

// Create cadence factor
logic [5:0] cadence_factor;
// Add 32 to cadence if it is > 1, 0 otherwise
assign cadence_factor = (cadence[4:0] > 5'b00001) ? (cadence[4:0] + 6'b100000) : 6'b000000;

logic [12:0] torque_off;
assign torque_off = {1'b0, avg_torque} - {1'b0, TORQUE_MIN};

// Zero clipped version of torque_off
logic [11:0] torque_pos;
assign torque_pos = (torque_off[12]) ? 12'b0 : torque_off[11:0];

// How much we want the motor to assist the rider
logic [29:0] assist_prod;
assign assist_prod = (not_pedaling) ? 30'b0 : torque_pos * incline_lim * cadence_factor * scale;

assign target_curr = (assist_prod[29:27] != 3'b000) ? 12'hFFF : assist_prod[26:15];



endmodule