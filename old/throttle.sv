module throttle(clk,rst_n,throttle,SS_n,SCLK,MOSI,MISO);

  input clk,rst_n;				// 50MHz clock and active low asynch reset
  input MISO;					// Serial input from A2D (Master In Slave Out)
  output reg [11:0] throttle;	// proportional to battery voltage (channel 0)
  output logic SS_n;					// active low SPI slave select to A2D
  output SCLK,MOSI;				// SPI master signals
  
  typedef enum reg[1:0] {AAA,AAB,AAC,AAD} n001_t;
  n001_t n001, n002;
  
  typedef enum reg[1:0] {AAAA,AAAB,AAAC,AAAD} n003_t;
  
  n003_t n003,n004;	
  
  logic [5:0] n005;
  logic [3:0] n006;
  logic [15:0] n007;	
  logic n008;				
  

  logic [9:0] n009;		
 
  logic [15:0] n010;	
  logic [15:0] n011;
  logic n012,n013;

  logic n014, n015;
  
  logic n016, n017, n018;
  logic n019, n020,n021;
  
  
  always_ff @(posedge clk,negedge rst_n)
    if (!rst_n)
	  n009 <= 10'h000;
	else if (n015)
	  n009 <= 10'h000;
	else
	  n009 <= n009 + 1;
	  
  assign n013 = &n009;
  

  assign n011 = {2'b00,3'b100,11'h000};			// torque on ch4

  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  n001 <= AAA;
	else
	  n001 <= n002;
	  

  always_comb begin
    n015 = 0;
	n014 = 0;
	n002 = AAA;
	
	case (n001)
	  AAA:
	    if (n013) begin
		  n002 = AAB;
		  n014 = 1;
		end
	  AAB: begin
	    if (n012)
		  n002 = AAC;
		else
		  n002 = AAB;
	  end
	  AAC: begin
		n014 = 1;
		n002 = AAD;
	  end
	  AAD: begin
	    if (n012) begin
		  n015 = 1;
		  n002 = AAA;
		end else
		  n002 = AAD;
	  end
	endcase
  end
  

  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  throttle 			<= 12'h000;
	else if (n015)
	  throttle 			<=  n010[11:0];

 
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
      n003 <= AAAA;
    else
      n003 <= n004;

	  
  always_ff @(posedge clk)
    if (n021)
	  n008 <= MISO;
  
 
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  n007 <= 16'h0000;
	else if (n014)
      n007 <= n011;
    else if (n018)
      n007 <= {n007[14:0],n008};


  always_ff @(posedge clk)
    if (n016)
      n006 <= 4'b0000;
    else if (n017)
      n006 <= n006 + 1'b1;


  always_ff @(posedge clk)
    if (n016)
      n005 <= 6'b101100;
    else
      n005 <= n005 + 1'b1;

  assign SCLK = n005[5];
  
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  n012 <= 1'b0;
	else if (n019)
	  n012 <= 1'b1;
	else if (n020)
	  n012 <= 1'b0;
	  
  always_ff @(posedge clk, negedge rst_n)
    if (!rst_n)
	  SS_n <= 1'b1;
	else if (n019)
	  SS_n <= 1'b1;
	else if (n020)
	  SS_n <= 1'b0;
	  

  always_comb
    begin

      n016 = 0; 
      n017 = 0;
      n018 = 0;
	  n021 = 0;
      n019 = 0;
	  n020 = 0;
	  n004 = AAAA;

      case (n003)
        AAAA : begin
          n016 = 1;
          if (n014) 
		    begin
			  n020 = 1;
              n004 = AAAB;
			end
          else 
		    n004 = AAAA;
        end
		AAAB : begin
		  if (&n005) begin
		    n004 = AAAC;
	      end else
		    n004 = AAAB;
		end
        AAAC : begin
          n017 = (&n005) ? 1'b1 : 1'b0;
		  n021 = (n005==6'b011111) ? 1'b1 : 1'b0;	
          n018 = (&n005) ? 1'b1 : 1'b0;	
		  if (n005[5] && (n006==4'hF))
		    n004 = AAAD;
          else
            n004 = AAAC;         
        end
        AAAD : begin
          if (&n005[5:1])
		    begin
			  n004 = AAAA;
			  n018 = 1;
			  n019 = 1;
			end
		  else
		    n004 = AAAD;
        end
      endcase
    end
  
  assign n010 = n007[15:0];
  assign MOSI = n007[15];
   
  
endmodule
  
