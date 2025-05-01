///////////////////////////////////////////////////////////////
// File: brushless.sv
// Description: Brushless motor commutation controller
//              - Synchronizes raw Hall sensor inputs to a PWM cycle
//              - Determines coil drive states (HIGHZ, REVERSE, FORWARD, REGEN)
//              - Computes an output duty cycle
//
// Inputs:
//    clk       : 50 MHz clock
//    rst_n     : Active-low reset
//    drv_mag   : 12-bit input from PID control (motor assist power)
//    hallGrn   : Raw Hall sensor input (green phase)
//    hallYlw   : Raw Hall sensor input (yellow phase)
//    hallBlu   : Raw Hall sensor input (blue phase)
//    brake_n   : Active-low brake signal (0 => braking mode)
//    PWM_synch : High during a special window in the PWM cycle, used to latch
//
// Outputs:
//    duty      : 11-bit duty cycle for the PWM
//    selGrn    : 2-bit drive select for green coil
//    selYlw    : 2-bit drive select for yellow coil
//    selBlu    : 2-bit drive select for blue coil
///////////////////////////////////////////////////////////////

module brushless (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [11:0] drv_mag,
    input  logic        hallGrn,
    input  logic        hallYlw,
    input  logic        hallBlu,
    input  logic        brake_n,
    input  logic        PWM_synch,
    output logic [10:0] duty,
    output logic [1:0]  selGrn,
    output logic [1:0]  selYlw,
    output logic [1:0]  selBlu
);

  //-----------------------------------------------------------
  // 1) Metastability Filters (Double-Flop Synchronizers)
  //    Here we synchronize the raw Hall sensor signals
  //    into our clk domain to avoid metastability.
  //-----------------------------------------------------------
  logic hallGrn_d1, hallGrn_d2;
  logic hallYlw_d1, hallYlw_d2;
  logic hallBlu_d1, hallBlu_d2;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      hallGrn_d1 <= 1'b0;
      hallGrn_d2 <= 1'b0;
      hallYlw_d1 <= 1'b0;
      hallYlw_d2 <= 1'b0;
      hallBlu_d1 <= 1'b0;
      hallBlu_d2 <= 1'b0;
    end 
    else begin
      hallGrn_d1 <= hallGrn;
      hallGrn_d2 <= hallGrn_d1;

      hallYlw_d1 <= hallYlw;
      hallYlw_d2 <= hallYlw_d1;

      hallBlu_d1 <= hallBlu;
      hallBlu_d2 <= hallBlu_d1;
    end
  end

  //-----------------------------------------------------------
  // 2) Synchronizing Hall Sensors to PWM_synch
  //    We only latch the final Hall state when PWM_synch=1,
  //    ensuring commutation changes align with PWM deadtime.
  //-----------------------------------------------------------
  logic synchGrn, synchYlw, synchBlu;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      synchGrn <= 1'b0;
      synchYlw <= 1'b0;
      synchBlu <= 1'b0;
    end
    else if (PWM_synch) begin
      synchGrn <= hallGrn_d2;
      synchYlw <= hallYlw_d2;
      synchBlu <= hallBlu_d2;
    end
  end

  //-----------------------------------------------------------
  // 3) Determine Rotation State (3 bits)
  //    rotation_state = {Green, Yellow, Blue}
  //-----------------------------------------------------------
  logic [2:0] rotation_state;
  assign rotation_state = {synchGrn, synchYlw, synchBlu};

  //-----------------------------------------------------------
  // 4) Drive States
  //    00 = HIGHZ (both transistors off)
  //    01 = REVERSE (low side on, high side PWM, or vice versa)
  //    10 = FORWARD (high side on, low side PWM, or vice versa)
  //    11 = REGEN (regenerative braking)
  //-----------------------------------------------------------
  typedef enum logic [1:0] {
    HIGHZ   = 2'b00,
    REVERSE = 2'b01,
    FORWARD = 2'b10,
    REGEN   = 2'b11
  } drive_state_t;

  //-----------------------------------------------------------
  // 5) Commutation & Duty Logic
  //    - If brake_n is low => apply REGEN to all coils, duty=0x600
  //    - Else use rotation_state to assign coil states 
  //    - Default duty = 0x400 + (drv_mag >> 2)
  //-----------------------------------------------------------
  always_comb begin
    // Default values
    selGrn = HIGHZ;
    selYlw = HIGHZ;
    selBlu = HIGHZ;
    duty   = 11'h000;  

    if (!brake_n) begin
      // Brake mode => all coils in REGEN, duty=0x600
      selGrn = REGEN;
      selYlw = REGEN;
      selBlu = REGEN;
      duty   = 11'h600;
    end 
    else begin
      // Normal mode => duty depends on drv_mag
      // We do 0x400 + (drv_mag >> 2), so if drv_mag=full(12'b1111_1111_1111),
      // that yields 0x400 + 0xFFF>>2 = 0x400 + 0x3FF = 0x7FF
      duty = 11'h400 + {1'b0, drv_mag[11:2]};

      // Set coil states based on the hall rotation_state
      case (rotation_state)
        3'b001: begin
          selGrn = HIGHZ;
          selYlw = REVERSE;
          selBlu = FORWARD;
        end
        3'b011: begin
          selGrn = REVERSE;
          selYlw = HIGHZ;
          selBlu = FORWARD;
        end
        3'b010: begin
          selGrn = REVERSE;
          selYlw = FORWARD;
          selBlu = HIGHZ;
        end
        3'b100: begin
          selGrn = FORWARD;
          selYlw = HIGHZ;
          selBlu = REVERSE;
        end
        3'b101: begin
          selGrn = FORWARD;
          selYlw = REVERSE;
          selBlu = HIGHZ;
        end
        3'b110: begin
          selGrn = HIGHZ;
          selYlw = FORWARD;
          selBlu = REVERSE;
        end
        default: begin
          // Invalid or unknown hall pattern => all coils off
          selGrn = HIGHZ;
          selYlw = HIGHZ;
          selBlu = HIGHZ;
        end
      endcase
    end
  end

endmodule
