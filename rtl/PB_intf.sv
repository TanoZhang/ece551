module PB_intf (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       tgglMd,
    output logic [1:0] setting,
    output logic [2:0] scale,
    output logic [1:0] LED
);

  logic released;

  // Push button is asynch and active low: 3 flops (preset high) and
  // detect the rising edge, i.e. the button being released

  PB_rise iPB_rise (
      .clk(clk),
      .rst_n(rst_n),
      .PB(tgglMd),
      .rise(released)
  );

  // Mode counter

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) setting <= 2'b10;  // default to "normal"

    else if (released) setting <= setting + 2'd1;
  end

  // Output scale based on setting

  always_comb begin
    case (setting)
      2'b00: scale = 3'b000;  // off

      2'b01: scale = 3'b011;  // hard

      2'b10: scale = 3'b101;  // normal

      2'b11: scale = 3'b111;  // easy

    endcase

    // LEDs display the setting directly

    LED = setting;
  end

endmodule
