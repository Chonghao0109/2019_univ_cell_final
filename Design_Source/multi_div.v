
// File Name:
//  mulit_div.v
//
// Interface:
//  
//  Author:
//    CHONG-HAO XU
//
//  Descritpion:
//    select: multi : 0
//            div   : 1   
//    

module multi_div
#(
  parameter SIZE_A = 128,
  parameter SIZE_B = 64,
  parameter FAST_MODE = 2
)(
  input wire clk,reset_n,
  input wire en,
  input wire select,
  input wire [SIZE_A-1:0] a,
  input wire [SIZE_B-1:0] b,
  output reg [SIZE_A+SIZE_B-1:0] P,
  output reg Valid,
  output reg Busy
);

  parameter READ_IN   = 0,
            CALCULATE = 1,
            DATA_OUT  = 2;


  reg [1:0] state;
  reg [9:0] state_counter;
  
  reg [SIZE_A-1:0] data_b;
  reg [SIZE_A+SIZE_B:0] r;  //a + 1'b0 + SIZE_B'b0

  always@(*)begin
    Valid <= (state == DATA_OUT) ? 1'b1:1'b0;
    Busy  <= (state == CALCULATE) ? 1'b1:1'b0;
  end


  always@(posedge clk or negedge reset_n)begin
    if(~reset_n)begin
      state <= READ_IN;
      state_counter <= 0;
    end else begin
      case(state)
        
        
        READ_IN   :begin
          if(en)begin
            state <= CALCULATE;
            state_counter <= 0;
          end  
        end
        
        
        
        
        CALCULATE :begin
          

          if(state_counter == (SIZE_A/FAST_MODE)-1)begin
            state <= DATA_OUT;
            state_counter <= 0;
          end
          else begin
            state_counter <= state_counter + 1;
          end

        end
        
        
        
        
        DATA_OUT  :begin
          state <= READ_IN;
          state_counter <= 0;
        end
        
        
        default begin
          state <= READ_IN;
          state_counter <= 0;
        end

      endcase
    end
  end



  
  reg in_select;
  integer i;
  always@(posedge clk or negedge reset_n)begin
    if(~reset_n)begin
      r = 0;
      data_b = 0;
      in_select = 0;
			P = 0;
    end else begin


      case(state)
        
        READ_IN   :begin
          if(en)begin
            r = {a,1'b0,{SIZE_B{1'b0}}};
            data_b = b;
            in_select = select;
          end  
        end
        
        
        
        
        CALCULATE :begin

          for(i=0;i<FAST_MODE;i=i+1)begin 
            if(in_select)begin // Div

              r = {r[SIZE_A+SIZE_B-1:0],r[SIZE_A+SIZE_B]};
              if( r[SIZE_B:0] >= data_b)begin
                r[SIZE_B+1] = 1;
                r[SIZE_B:0] = r[SIZE_B:0] - data_b;
              end
              else r[SIZE_B+1] = 0;
              //$display("R:%b",r);
              P = r[ (SIZE_A+SIZE_B) -: SIZE_A];
            end
            else begin //Multi

              r = r[SIZE_A+SIZE_B] ? ((r<<1)+data_b) : (r<<1);
              P = r[SIZE_A+SIZE_B-1:0];

              //$display("r:%b",r);

            end 
          end
        end

      endcase
    end
  end




endmodule
