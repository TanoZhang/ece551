module SPI_mnrch (
    input logic clk, 
    input logic rst_n, 
    input logic snd,
    input logic MISO, 
    input logic [15:0] cmd,
    output logic SS_n, 
    output logic done, 
    output logic SCLK, 
    output logic MOSI, 
    output logic [15:0] resp);

    // Control signals
    logic shiftT, already_done, init, bits_16, reload_clock_div, full;

    // Counters
    logic [4:0]bit_counter;
    logic [4:0] clock_div;
    logic [15:0]shift_register;

    // State machine
    typedef enum reg [1:0] {idle_state, counting, finished} state_t;
    state_t state, nxt_state;

    //clock generator
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)begin
             clock_div <= 0;
        end else begin
            if (reload_clock_div)
                 clock_div <= 5'b10111;
            else 
                 clock_div <=  clock_div + 1;
        end
    end

    // Bit counter to 16bit
    assign SCLK =  clock_div[4];
    // shift pulse
    assign shiftT = ( clock_div == 5'b10001) ? 1'b1: 1'b0;
    // divider overflow
    assign full = & clock_div;

    //bit counter
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            bit_counter <= 0;
        else if (init)
            bit_counter <= 5'b00000;
        else if (shiftT)
            bit_counter <= bit_counter + 1;
    end
    assign bits_16 = (bit_counter == 5'b10000);

    // Shift register
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            shift_register <= 0;
        end else begin
            if (init) begin
                shift_register <= cmd;
            end else begin
                if (shiftT) begin
                    shift_register <= {shift_register[14:0], MISO};
                end else begin
                    shift_register <= shift_register;
                end
            end 
        end
    end
    assign MOSI = shift_register[15]; //output MSB to slave

    //flipflop of FSM
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            state <= idle_state;
        end else begin
            state <= nxt_state;
        end
    end

    //combinational logic
    always_comb begin
        nxt_state = idle_state;
        init = 0;
        already_done = 0;
        reload_clock_div = 0;

        case(state)
            idle_state: if (snd) begin
                nxt_state = counting;
                init = 1;
                reload_clock_div = 1;
            end else begin
                nxt_state = idle_state;
                reload_clock_div = 1;  // hold SCLK high while idle
            end

            counting: if (bits_16) begin
                nxt_state = finished;
            end else nxt_state = counting;
            
            finished: if (full) begin
                nxt_state = idle_state;
                already_done = 1;
                reload_clock_div = 1;
            end else nxt_state = finished;

            default: nxt_state = idle_state;
        endcase      
    end

    // Done signal generation
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
        end else begin
            if (init) begin
                done <= 0;
            end else begin
                if (already_done) begin
                    done <= 1;
                end
            end
        end
    end

    // Slave Select control
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            SS_n <= 1;
        end else begin
            if (init) begin
                SS_n <= 0;
            end else begin
                if (already_done) begin
                    SS_n <= 1;
                end
            end
        end
    end
    assign resp = shift_register;
endmodule