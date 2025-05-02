/////////////////////////////////////////////////////
// Model of a Serial Peripheral Interconnect Master||
/////////////////////////////////////////////////////
module SPI_mnrch (
    input logic clk, //clock
    input logic rst_n, //asynch active low reset
    output logic SS_n, //active low serf select
    output logic SCLK, //serial clock
    output logic MOSI, //Monarch Out Serf In
    input logic MISO, //Monarch In Serf Out
    input logic snd, //send signal
    input logic [15:0] cmd, //command input
    output logic done, //done signal
    output logic [15:0] resp); //response output

    //initialize intermediate logic
    logic ld_SCLK;
    logic [4:0]SCLK_div;
    logic shft;
    logic [4:0]bit_cntr;
    logic init;
    logic done16;
    logic [15:0]shft_reg;
    logic set_done;

    //initialize FSM enum
    typedef enum reg [1:0] {IDLE, COUNT, DONE} state_t;
    state_t state, nxt_state;

    //Serial clock generator
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)begin
            SCLK_div <= 0;
        end else begin
            if (ld_SCLK)
                SCLK_div <= 5'b10111; //intentional delay before SCLK falls
            else 
                SCLK_div <= SCLK_div+1;
        end
    end

    //Assign sclk to be the 4th bit of the counter
    assign SCLK = SCLK_div[4];

    assign shft = (SCLK_div == 5'b10001) ? 1'b1: 1'b0; //shift signal for shift reg
    assign full = &SCLK_div; //full signal for backporch response

    //16 bit counter 
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            bit_cntr <= 0;
        else if (init)
            bit_cntr <= 5'b00000;
        else if (shft)
            bit_cntr <= bit_cntr + 1;
    end

    //output signal every 16 cycles/bits
    assign done16 = (bit_cntr == 5'b10000);

    //Shift register flip flop
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            shft_reg <= 0;
        end else begin
            if (init) begin
                shft_reg <= cmd; //take input if init is 1
            end else begin
                if (shft) begin
                    shft_reg <= {shft_reg[14:0], MISO}; //take serf output if shft is 1
                end else begin
                    shft_reg <= shft_reg;
                end
            end 
        end
    end

    assign MOSI = shft_reg[15]; //output to serf

    //FSM flip flop
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= nxt_state;
        end
    end

    //FSM combinational logic
    always_comb begin
        //initialize defaults to prevent latches
        nxt_state = IDLE;
        init = 0;
        set_done = 0;
        ld_SCLK = 0;

        case(state)
            IDLE: if (snd) begin
                nxt_state = COUNT;
                init = 1; //send init signal to begin
                ld_SCLK = 1;
            end else nxt_state = IDLE;

            COUNT: if (done16) begin //wait till count is complete
                nxt_state = DONE;
            end else nxt_state = COUNT;
            
            DONE: if (full) begin //backpoch generation
                nxt_state = IDLE;
                set_done = 1;
                ld_SCLK = 1;
            end else nxt_state = DONE;

            default: nxt_state = IDLE;
        endcase      
    end

    //Done signal flip flop
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
        end else begin
            if (init) begin
                done <= 0;
            end else begin
                if (set_done) begin
                    done <= 1;
                end
            end
        end
    end

    //SS_n signal flip flop
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            SS_n <= 1;
        end else begin
            if (init) begin
                SS_n <= 0;
            end else begin
                if (set_done) begin
                    SS_n <= 1;
                end
            end
        end
    end

    assign resp = shft_reg;

    //resp output FF
    //always_ff @(posedge clk, negedge rst_n) begin
      //  if (!rst_n) begin
        //    resp <= 16'b0;
        //end
        //else if (set_done) begin
          //  resp <= shft_reg;
        //end
    //end

endmodule