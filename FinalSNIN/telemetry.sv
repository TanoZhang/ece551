module telemetry(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [11:0] batt_v,
    input  logic [11:0] avg_curr,
    input  logic [11:0] avg_torque,
    output logic        TX
);
    
    reg   [19:0] counter;
    logic [7:0] tx_data;
    logic       tx_done;
    logic       trmt;
    
    // UART transmitter instantiation
    UART_tx UART_tx_inst ( .clk(clk), .rst_n(rst_n), .TX(TX), .trmt(trmt), .tx_data(tx_data), .tx_done(tx_done));
    // state machine
    typedef enum reg[3:0] {
        IDLE, full_stop, payload1, payload2, payload3, payload4, payload5, payload6, WAIT
    } state_t;
    state_t state, nxt_state;

    // logic of state transition
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= nxt_state;
    end

    // Delay counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            counter <= 20'b0;
        else
            counter <= counter + 1;
    end

    // logic of next state
    always_comb begin
        // Default value
        tx_data = 8'b0;  
        trmt = 0;
        nxt_state = state;

        case (state)
            IDLE: begin
                tx_data = 8'hAA;
                trmt = 1;
                nxt_state = full_stop;
            end

            full_stop: if (tx_done) begin
                tx_data = 8'h55;
                trmt = 1;
                nxt_state = payload1;
            end

            payload1: if (tx_done) begin
                tx_data = {4'b0, batt_v[11:8]};
                trmt = 1;
                nxt_state = payload2;
            end

            payload2: if (tx_done) begin
                tx_data = batt_v[7:0];
                trmt = 1;
                nxt_state = payload3;
            end

            payload3: if (tx_done) begin
                tx_data = {4'h0, avg_curr[11:8]};
                trmt = 1;
                nxt_state = payload4;
            end

            payload4: if (tx_done) begin
                tx_data = avg_curr[7:0];
                trmt = 1;
                nxt_state = payload5;
            end

            payload5: if (tx_done) begin
                tx_data = {4'h0, avg_torque[11:8]};
                trmt = 1;
                nxt_state = payload6;
            end

            payload6: if (tx_done) begin
                tx_data = avg_torque[7:0];
                trmt = 1;
                nxt_state = WAIT;
            end

            WAIT: begin
                if (&counter)
                    nxt_state = IDLE;
            end

            default: nxt_state = IDLE;
        endcase
    end
endmodule