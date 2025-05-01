module A2D_intf(clk, rst_n, batt, curr, brake, torque, SS_n, SCLK, MOSI, MISO);

	typedef enum reg [1:0] {IDLE, READ, PAUSE} state_t;
	state_t state, nxt_state;

	input clk, MISO, rst_n;
	
	output logic [11:0] batt, curr, brake, torque;
	output SS_n, SCLK, MOSI;

	logic [13:0] counter;
	logic [15:0] resp, cmd;
	logic [2:0] channel;
	logic [3:0] channelCount;
	logic done, snd, cnv_cmplt;
	

	assign cmd = {2'b00,channel[2:0],11'h000};
	SPI_mnrch spi(.clk(clk), .rst_n(rst_n), .SS_n(SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO), .snd(snd), .cmd(cmd), 
	    .done(done), .resp(resp));
	
	//14 bit delay counter
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n) counter <= 14'h0000;
		else counter <= counter + 1;
	
	//state machine logic
	always_ff @(posedge clk, negedge rst_n)
	if (!rst_n) begin
		state <= IDLE;
	end else begin
		state <= nxt_state;
	end
  
	always_comb begin
		nxt_state = state;
		snd = 0;
		cnv_cmplt = 0;
		case(state)
			IDLE: if(&counter) begin
				nxt_state = READ;
				channel = 3'b000;
				channelCount = 0;
				snd = 1;
			end
			READ: if(done) begin
				nxt_state = PAUSE;
				case(channelCount)
					1: channel = 3'b001;
					3: channel = 3'b011;
					5: channel = 3'b100;
					7: nxt_state = IDLE; //done with all 8 transactions
				endcase
				channelCount++;
				cnv_cmplt = 1;
			end
			default: begin //PAUSE
				nxt_state = READ;
				snd = 1;
			end
	endcase
	end
	
	//battery register
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n) batt <= 12'h0000;
		else if (cnv_cmplt && (channelCount == 2)) batt <= resp[11:0];
	
	//current register
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n) curr <= 12'h0000;
		else if (cnv_cmplt && (channelCount == 4)) curr <= resp[11:0];
	
	//brake register
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n) brake <= 12'h0000;
		else if (cnv_cmplt && (channelCount == 6)) brake <= resp[11:0];
		
	//torque register
	always_ff @(posedge clk, negedge rst_n)
		if(!rst_n) torque <= 12'h0000;
		else if (cnv_cmplt && (channelCount == 8)) torque <= resp[11:0];
endmodule