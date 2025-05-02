module A2D_intf(clk, rst_n, MISO, batt, curr, brake,torque, SS_n, SCLK, MOSI);
input clk, rst_n, MISO;
output reg[11:0] batt, curr, brake, torque;
output SS_n, SCLK, MOSI;

logic true;
logic [13:0] counter;
logic counter_finish;
logic start;
logic snd;
logic [15:0] cmd;
logic [15:0] resp;
logic done;
logic conversion_done;
logic [1:0] DR_counter, DR_signal;
logic [2:0] ADC_channel;
wire torque_enabled, curr_enabled, batt_enabled, brake_enabled;
SPI_mnrch mnrch(.clk(clk), .rst_n(rst_n), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .snd(snd), .cmd(cmd), .MISO(MISO),.resp(resp), .done(done));

assign counter_finish = ~|counter;
assign true = torque_enabled || curr_enabled || brake_enabled || batt_enabled;
//counter for 14bits
always @(posedge clk, negedge rst_n) begin
if (!rst_n)
counter <= 0;
else
 counter <= counter + 1;
end

always @(posedge clk, negedge rst_n) begin
if (!rst_n)
DR_signal <= 2'b0;
else if start) begin
DR_signal <= DR_signal + 1;
end
end

always@(posedge clk, negedge rst_n) begin
if(!rst_n) start <= 0;
else if start) start <= 0;
else start <= true;
end

//assign cmd and ADC_channel
assign ADC_channel = DR_signal[1] ? (DR_signal[0] ? 3'b100: 3'b011) : DR_signal[0] ? 3'b001: 3'b000;
assign cmd = {2'b0, ADC_channel, 11'h000};

//state machine
typedef enum logic [1:0] {IDLE, continue, halt, read_data} state_t;
state_t state, nxt_state;

//flipflop of state
always @(posedge clk, negedge rst_n) begin
if (!rst_n)
state <= IDLE;
else
state <= nxt_state;
end

always_comb begin
snd = 0;
conversion_done = 0;
nxt_state = state;
case(state)
IDLE: if(counter_finish) begin
  nxt_state = continue;
  snd = 1;
end
continue: if(done) begin
nxt_state = halt;
end
halt: begin
nxt_state = read_data;
snd = 1;
end
read_data: if (done) begin
nxt_state = IDLE;
conversion_done = 1;
end
default: nxt_state = IDLE;
endcase
end

assign torque_enabled = conversion_done ? &DR_signal ? 1: 0 : 0;
assign curr_enabled = conversion_done ? ~DR_signal[1] && DR_signal[0] ? 1 : 0 : 0;
assign batt_enabled = conversion_done ? ~|DR_signal ? 1 : 0 : 0;
assign brake_enabled = conversion_done ? DR_signal[1] && ~DR_signal[0] ? 1 : 0 : 0;

// The output flops
always @(posedge clk, negedge rst_n) begin
if (!rst_n) begin
batt <= 12'b0;
torque <= 12'b0;
curr <= 12'b0;
brake <= 12'b0;
end
else if(true) begin
//see true enabled
if (torque_enabled) begin
torque <= {resp[11:0]};
end
if(batt_enabled) begin
batt <= {resp[11:0]};
end
if (curr_enabled)begin
curr <= {resp[11:0]};
end
if(brake_enabled)begin
brake <= {resp[11:0]};
end
end
end
endmodule