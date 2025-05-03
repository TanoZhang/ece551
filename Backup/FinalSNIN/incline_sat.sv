module incline_sat (
    incline,
    incline_sat
);
  //in n out
  input [12:0] incline;
  output [9:0] incline_sat;

  // pos and neg variable
  logic positive, negative;
  assign positive = (incline[11] | incline[10]) & ~incline[12];
  assign negative = ~(incline[11] & incline[10]) & incline[12];
  assign incline_sat = negative ? 10'b1000000000 : positive ? 10'b0111111111 :  {incline[12], incline[8:0]};

endmodule
