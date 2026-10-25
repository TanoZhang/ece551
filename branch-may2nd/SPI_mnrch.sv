module SPI_mnrch(clk, rst_n, SS_n, SCLK, MOSI, MISO, snd, cmd, done, resp);

typedef enum reg [1:0] {IDLE, SHIFT_STATE, BACKPORCH} state_t;
state_t state, nxt_state;

input clk, rst_n, snd, MISO;
input [15:0] cmd;

output SCLK, MOSI;
output logic SS_n, done;
output [15:0] resp;

logic [15:0] shift_reg, shift_mux;
logic [4:0] SCLK_div, bit_cntr;
logic full, shift, ld_SCLK, init, set_done, done16;

//SCLK logic
assign SCLK = SCLK_div[4];
assign full = &SCLK_div;
assign shift = (SCLK_div == 5'b10001);

always_ff@(posedge clk)
  if(ld_SCLK)
    SCLK_div <= 5'b10111;
  else
    SCLK_div <= SCLK_div + 1;

//shift counter logic
assign done16 = bit_cntr[4];
always_ff@(posedge clk)
  if(shift && ~init)
    bit_cntr <= bit_cntr + 1;
  else if(init)
    bit_cntr <= 5'b00000;
  else
    bit_cntr <= bit_cntr;

//shifter logic
assign shift_mux = (init) ? cmd : (shift) ? {shift_reg[14:0], MISO} : shift_reg;
assign MOSI = shift_reg[15];
assign resp = shift_reg;
always_ff@(posedge clk)
  shift_reg <= shift_mux;

//state machine logic
always_ff @(posedge clk, negedge rst_n)
  if (!rst_n) begin
    state <= IDLE;
  end else begin
    state <= nxt_state;
  end
  
always_comb begin
  nxt_state = state;
  init = 1'b0;
  ld_SCLK = 1'b0;
  set_done = 1'b1;
  
  case(state)
    IDLE: if(snd) begin
	  nxt_state = SHIFT_STATE;
	  set_done = 1'b0;
	  init = 1'b1;
	end else begin
      ld_SCLK = 1'b1;
	end
	SHIFT_STATE: if(done16) begin
	  nxt_state = BACKPORCH;
	  set_done = 1'b0;
	end else begin
	  set_done = 1'b0;
	end
	default: if(full) begin //BACKPORCH
	  nxt_state = IDLE;
	  ld_SCLK = 1'b1;
	  //init = 1'b1;
	end else begin
	  set_done = 0;
	end
  endcase
end

//flip-flop logic that drives SS_n and done
always_ff @(posedge clk, negedge rst_n)
  if (!rst_n) begin
    SS_n <= 1'b1;
	done <= 1'b0;
  end else begin
    SS_n <= (set_done);
	done <= (set_done);
  end

endmodule