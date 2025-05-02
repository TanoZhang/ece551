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
    output logic [ 1:0] selGrn,
    output logic [ 1:0] selYlw,
    output logic [ 1:0] selBlu
);

  //metastability local variable
  logic hallGrn1, hallGrn2, hallYLW1, hallYLW2, hallBlu1, hallBlu2;
  logic SyncGREEN, SynchYELLOW, SyncBLUE;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      hallGrn1 <= 1'b0;
      hallGrn2 <= 1'b0;
      hallYLW1 <= 1'b0;
      hallYLW2 <= 1'b0;
      hallBlu1 <= 1'b0;
      hallBlu2 <= 1'b0;
    end else begin
      hallGrn1 <= hallGrn;
      hallGrn2 <= hallGrn1;
      hallYLW1 <= hallYlw;
      hallYLW2 <= hallYLW1;
      hallBlu1 <= hallBlu;
      hallBlu2 <= hallBlu1;
    end
  end

  //sync Hall sensors to PWM_synch and latch Hall state only when PWM_synch=1
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      SynchGREEN <= 1'b0;
      SynchYELLOW <= 1'b0;
      SyncBLUE <= 1'b0;
    end else if (PWM_synch) begin
      SynchGREEN <= hallGrn2;
      SynchYELLOW <= hallYLW2;
      SyncBLUE <= hallBlu2;
    end
  end

  //check rotation state
  logic [2:0] rotation_state;
  assign rotation_state = {SynchGREEN, SynchYELLOW, SyncBLUE};

  //driving state
  typedef enum logic [1:0] {
    highZ = 2'b00,
    reverse = 2'b01,
    drive = 2'b10,
    regenerate = 2'b11
  } drive_state_t;

  //communication logic
  always_comb begin
    //initialization
    selGrn = highZ;
    selYlw = highZ;
    selBlu = highZ;
    duty   = 11'h000;

    if (!brake_n) begin
      selGrn = regenerate;
      selYlw = regenerate;
      selBlu = regenerate;
      duty   = 11'h600;
    end else begin
      //0x400 + (drv_mag >> 2), so if drv_mag=full(12'b1111_1111_1111), 0x400 + 0xFFF>>2 = 0x400 + 0x3FF = 0x7FF
      duty = 11'h400 + {1'b0, drv_mag[11:2]};

      // Set coil states based on the hall rotation_state
      case (rotation_state)
        3'b001: begin
          selGrn = highZ;
          selYlw = reverse;
          selBlu = drive;
        end
        3'b011: begin
          selGrn = reverse;
          selYlw = highZ;
          selBlu = drive;
        end
        3'b010: begin
          selGrn = reverse;
          selYlw = drive;
          selBlu = highZ;
        end
        3'b100: begin
          selGrn = drive;
          selYlw = highZ;
          selBlu = reverse;
        end
        3'b101: begin
          selGrn = drive;
          selYlw = reverse;
          selBlu = highZ;
        end
        3'b110: begin
          selGrn = highZ;
          selYlw = drive;
          selBlu = reverse;
        end
        default: begin
          // turn off in invalid all coils off
          selGrn = highZ;
          selYlw = highZ;
          selBlu = highZ;
        end
      endcase
    end
  end
endmodule