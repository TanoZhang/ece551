module incline_sat(incline, incline_sat);
//This module saturates a 13 bit signed value into a 10 bit signed value

    //set input and output
    input [12:0] incline;
    output [9:0] incline_sat;

    logic pos, neg;

    assign pos = (incline[11] | incline[10]) & ~incline[12]; 
    assign neg = ~(incline[11] & incline[10]) & incline[12]; 

   	
    	assign incline_sat = neg ? 10'b1000000000 : 
                       pos ? 10'b0111111111 : 
                       {incline[12], incline[8:0]};

endmodule