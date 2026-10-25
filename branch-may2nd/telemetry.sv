//
// telemetry.sv
//
// This module periodically sends out an 8-byte packet via the UART:
//   Byte0: 0xAA (delimiter #1)
//   Byte1: 0x55 (delimiter #2)
//   Byte2: {4'h0, batt_v[11:8]}   // high byte of batt_v
//   Byte3: batt_v[7:0]           // low  byte of batt_v
//   Byte4: {4'h0, avg_curr[11:8]}   // high byte of avg_curr
//   Byte5: avg_curr[7:0]            // low  byte of avg_curr
//   Byte6: {4'h0, avg_torque[11:8]} // high byte of avg_torque
//   Byte7: avg_torque[7:0]         // low  byte of avg_torque
//
// The packet is sent every ~1/48 second (? 20.97ms) by means of
// a down-counter that counts to 1,048,576 with a 50MHz clock.
// (Because 50,000,000 / 1,048,576 ? 47.68 Hz.)
//

module telemetry
(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [11:0] batt_v,
    input  logic [11:0] avg_curr,
    input  logic [11:0] avg_torque,
    output logic        TX
);

   //=========================================================
   // Wires/regs to connect to UART_tx
   //=========================================================
   logic        uart_trmt;       // Asserts for 1 cycle to start a transmit
   logic [7:0]  uart_tx_data;    // Byte to be transmitted
   logic        uart_tx_done;    // Goes high after each byte is done

   // Instantiate the given UART_tx module
   UART_tx uart_transmitter (
       .clk     (clk),
       .rst_n   (rst_n),
       .TX      (TX),
       .trmt    (uart_trmt),
       .tx_data (uart_tx_data),
       .tx_done (uart_tx_done)
   );

   //=========================================================
   // Packet storage
   // We build an array of the 8 bytes that we want to send.
   //=========================================================
   logic [7:0] packet_bytes [0:7];

   always_comb begin
      packet_bytes[0] = 8'hAA;
      packet_bytes[1] = 8'h55;
      packet_bytes[2] = {4'h0, batt_v[11:8]};
      packet_bytes[3] = batt_v[7:0];
      packet_bytes[4] = {4'h0, avg_curr[11:8]};
      packet_bytes[5] = avg_curr[7:0];
      packet_bytes[6] = {4'h0, avg_torque[11:8]};
      packet_bytes[7] = avg_torque[7:0];
   end

   //=========================================================
   // State machine to step through sending the 8 bytes
   //=========================================================
   typedef enum logic [2:0] {
       IDLE,        // Waiting for the next 1/48-second interval
       LOAD_BYTE,   // Load a new byte into UART_tx
       WAIT_DONE,   // Wait for tx_done from UART_tx
       INCREMENT,   // Move to next packet byte
       FINISHED     // Finished sending all 8 bytes
   } state_t;

   state_t current_state, next_state;

   // Byte index (0..7) of the packet
   logic [2:0] packet_index;

   // Next-trigger counter for ~1/48 second
   // could we make it precisely 50MHz
   // We count 1,048,576 cycles at 50 MHz to get ~47.68 Hz
   localparam int PERIOD_COUNT = 1048576;
   logic [19:0] period_counter; // 20 bits can count up to 1,048,575

   //--------------------------------------------------
   // Synchronous state, period counter, and packet index
   //--------------------------------------------------
   always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         current_state   <= IDLE;
         period_counter  <= 20'd0;
         packet_index    <= 3'd0;
      end
      else begin
         current_state   <= next_state;

         // Period counter increments in IDLE until we reach PERIOD_COUNT-1,
         // then we start sending again.
         if (current_state == IDLE) begin
            if (period_counter == (PERIOD_COUNT-1))
               period_counter <= 20'd0;
            else
               period_counter <= period_counter + 20'd1;
         end

         // Packet index increments after each byte is completely sent
         if (current_state == INCREMENT) begin
            packet_index <= packet_index + 3'd1;
         end
         else if (current_state == IDLE) begin
            // Reset to zero each new packet
            packet_index <= 3'd0;
         end
      end
   end

   //--------------------------------------------------
   // Combinational next-state logic
   //--------------------------------------------------
   always_comb begin
      // Default signals
      next_state      = current_state;
      uart_trmt       = 1'b0;
      uart_tx_data    = 8'd0;

      case (current_state)
         //---------------------------------------
         // Wait for period_counter to hit max
         //---------------------------------------
         IDLE: begin
            if (period_counter == (PERIOD_COUNT-1))
               next_state = LOAD_BYTE;
            else
               next_state = IDLE;
         end

         //---------------------------------------
         // Present the next byte to UART_tx
         //---------------------------------------
         LOAD_BYTE: begin
            uart_tx_data = packet_bytes[packet_index];
            // Asserting 'trmt' for one cycle starts the transmission.
            uart_trmt    = 1'b1;
            next_state   = WAIT_DONE;
         end

         //---------------------------------------
         // Wait for this byte's transmission to complete
         //---------------------------------------
         WAIT_DONE: begin
            uart_tx_data = packet_bytes[packet_index]; // hold stable
            if (uart_tx_done)
               next_state = INCREMENT;
            else
               next_state = WAIT_DONE;
         end

         //---------------------------------------
         // Move to next byte or finish
         //---------------------------------------
         INCREMENT: begin
            if (packet_index == 3'd7)
               next_state = FINISHED;
            else
               next_state = LOAD_BYTE;
         end

         //---------------------------------------
         // Done sending all 8 bytes; go back to IDLE
         //---------------------------------------
         FINISHED: begin
            next_state = IDLE;
         end

      endcase
   end

endmodule

