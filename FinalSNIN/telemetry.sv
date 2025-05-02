module telemetry(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [11:0] batt_v,
    input  logic [11:0] avg_curr,
    input  logic [11:0] avg_torque,
    output logic        TX
);

    logic [7:0] tx_data;
    logic       tx_done;
    logic       trmt;
    reg   [19:0] counter;

    // State machine encoding
    typedef enum reg[3:0] {
        IDLE, DELIM1, PAYLOAD1, PAYLOAD2, PAYLOAD3, PAYLOAD4, PAYLOAD5, PAYLOAD6, WAIT
    } state_t;

    state_t state, nxt_state;

    // UART transmitter instantiation
    UART_tx UART_tx_inst (
        .clk(clk), .rst_n(rst_n), .TX(TX),
        .trmt(trmt), .tx_data(tx_data), .tx_done(tx_done)
    );

    // State transition logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= nxt_state;
    end

    // Counter for periodic transmission delay
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            counter <= 20'b0;
        else
            counter <= counter + 1;
    end

    // Next-state logic and output assignments
    always_comb begin
        tx_data = 8'b0;  // Default value
        trmt = 0;
        nxt_state = state;

        case (state)
            IDLE: begin
                tx_data = 8'hAA;
                trmt = 1;
                nxt_state = DELIM1;
            end

            DELIM1: if (tx_done) begin
                tx_data = 8'h55;
                trmt = 1;
                nxt_state = PAYLOAD1;
            end

            PAYLOAD1: if (tx_done) begin
                tx_data = {4'b0, batt_v[11:8]};
                trmt = 1;
                nxt_state = PAYLOAD2;
            end

            PAYLOAD2: if (tx_done) begin
                tx_data = batt_v[7:0];
                trmt = 1;
                nxt_state = PAYLOAD3;
            end

            PAYLOAD3: if (tx_done) begin
                tx_data = {4'h0, avg_curr[11:8]};
                trmt = 1;
                nxt_state = PAYLOAD4;
            end

            PAYLOAD4: if (tx_done) begin
                tx_data = avg_curr[7:0];
                trmt = 1;
                nxt_state = PAYLOAD5;
            end

            PAYLOAD5: if (tx_done) begin
                tx_data = {4'h0, avg_torque[11:8]};
                trmt = 1;
                nxt_state = PAYLOAD6;
            end

            PAYLOAD6: if (tx_done) begin
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