
// - - - - - - - - - - - - - -
// Author : ChongHao Xu
// cescription:
//
//
//





module GPSDC(clk, reset_n, DEN, LON_IN, LAT_IN, COS_ADDR, COS_DATA, ASIN_ADDR, ASIN_DATA, Valid, a, D);

	input              clk;
	input              reset_n;
	input              DEN;
	input      [23:0]  LON_IN;//8+16
	input      [23:0]  LAT_IN;//8+16
	input      [95:0]  COS_DATA;//[95:48] input 16+32  [47:0] output 16+32
	output reg [6:0]   COS_ADDR;
	input      [127:0] ASIN_DATA;//[127:64] input 0+64 [63:0] 0+64
	output reg [5:0]   ASIN_ADDR;
	output reg         Valid;
	output reg [39:0]  D;// [39:32] integer [31:0] float
	output reg [63:0]  a; // 64bit float



	localparam RAD = 16'h477;
	localparam R = 12756274;


	//////// test ///////
	//real 			fra_part [0:10];
	/////////////////////


	// A B Position
	reg [23:0] A [1:0];//1:LON 0:LAT
	reg [23:0] B [1:0];//1:LON 0:LAT


	//Linear interpolation
	reg [63:0] X0,X1,Y0,Y1,X;
	reg [63:0] CAL_REG_0;
	reg [127:0] CAL_REG_1;
	reg [63:0] CAL_REG_2;

	reg [63:0] cos_a_lat,cos_b_lat;
	reg [63:0] function_0,function_1;




	
	reg [1:0] wait_ip_counter; 

	reg [127:0] ca;
	reg [63:0] 	cb;
	reg cs;
	reg ce;
	wire [128+64-1:0] rco;
	reg [127:0] co;
	wire cv;




	multi_div#(
	  .SIZE_A(128),
	  .SIZE_B(64),
	  .FAST_MODE(2)
	)
	multi_div(
	  .clk(clk),.reset_n(reset_n),
	  .en(ce),
	  .select(cs),
	  .a(ca),
	  .b(cb),
	  .P(rco),
	  .Valid(cv),
	  .Busy()
	);


	always@(*) co <= rco[127:0];




	// FSM 
	reg [3:0] state; // size uncheck
	reg [3:0]	state_counter;

	reg first,select;	

	parameter	READ_A 					= 0,
						COS_A_LAT				= 1,
						READ_B					=	2,
						COS_B_LAT				= 3,
						COS_FUNCTION_0 	= 4,
						COS_FUNCTION_1	= 5,
						CAL_A 					=	6,
						CAL_D						= 7,
						DATA_OUT				=	8;

	always@(posedge clk or negedge reset_n)begin
		if(!reset_n)begin
			state <= READ_A;
			state_counter <= 0;
			COS_ADDR <= 1;
			first <= 1;
			select <= 0;
			wait_ip_counter <= 0;
			{ca,cb,ce,cs} <= 0;
		end
		else begin
			case(state)





				READ_A 					:begin
					if(DEN)begin
						// READ A position
						state <= COS_A_LAT;
						A[0]	<= LAT_IN;
						A[1] 	<= LON_IN;
					end
				end











				COS_A_LAT				:begin
					case(state_counter)
						

						0:begin
							//Find COS 
							if( COS_DATA[95:48] /*16+32*/ > {8'd0,A[0]/*8+16*/,16'b0})begin
								X1 	<= 	COS_DATA[95:48];//16+32
								Y1	<=	COS_DATA[47:0];	//16+32
								
								COS_ADDR <= COS_ADDR - 1;
								state_counter <= state_counter + 1;
							end
							else 
								COS_ADDR <= COS_ADDR + 1;
						end
						

						1:begin
							X0	<=	COS_DATA[95:48];//16+32
							Y0 	<= 	COS_DATA[47:0];	//16+32
							
							CAL_REG_0 	<= 	X1 - COS_DATA[95:48]; //16+32
							CAL_REG_1 	<= 	{8'd0,A[0]/*8+16*/,16'd0} - COS_DATA[95:48]; //16+32
							CAL_REG_2	<=	Y1 - COS_DATA[47:0];

							COS_ADDR		<= 	0;
							state_counter <= state_counter + 1;
							

						end
						


						2:begin
							
							if(wait_ip_counter == 0)begin
								ca <= CAL_REG_1;
								cb <=CAL_REG_2;
								ce <= 1;
								cs <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							else if(cv)begin
								CAL_REG_1 <= co;
								wait_ip_counter <= 0;
								state_counter <= state_counter + 1;
							end
							else begin
								ce <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end

							//CAL_REG_1 <= CAL_REG_1*CAL_REG_2/*type:32+64*/ ; 
							//state_counter <= state_counter + 1;

						end


						3:begin

							if(wait_ip_counter == 0)begin
								ca <= Y0;
								cb <= CAL_REG_0;
								ce <= 1;
								cs <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							else if(cv)begin
								CAL_REG_1 <= co+CAL_REG_1;
								wait_ip_counter <= 0;
								state_counter <= state_counter + 1;
							end
							else begin
								ce <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end

							//CAL_REG_1 <= (Y0*CAL_REG_0 + CAL_REG_1)/*type:32+64*/ ; 
							//state_counter <= state_counter + 1;
						end

						4:begin
							
							if(wait_ip_counter == 0)begin
								ca <= CAL_REG_1<<32;
								cb <= CAL_REG_0;
								ce <= 1;
								cs <= 1;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							else if(cv)begin
								cos_a_lat <= co[63:0];
								wait_ip_counter <= 0;
								state_counter <=0;
								if(first) state <= READ_B;
								else state <= COS_FUNCTION_0;
								//#1
								//$display("%h\n%h", ( (CAL_REG_1/*32+64*/<< 32) / CAL_REG_0/*16+32*/) ,cos_a_lat);
							end
							else begin
								ce <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							
						end

					endcase
				end








				READ_B					:begin
					if(DEN)begin
						// READ B position
						state <= COS_B_LAT;
						B[0]	<= LAT_IN;
						B[1] 	<= LON_IN;
						COS_ADDR		<= 	0;
					end
				end
				








				COS_B_LAT				:begin
					case(state_counter)
						

						0:begin
							//Find COS 
							if( COS_DATA[95:48] /*16+32*/ > {8'd0,B[0]/*8+16*/,16'b0})begin
								X1 	<= 	COS_DATA[95:48];//16+32
								Y1	<=	COS_DATA[47:0];	//16+32
								
								COS_ADDR <= COS_ADDR - 1;
								state_counter <= state_counter + 1;
							end
							else 
								COS_ADDR <= COS_ADDR + 1;
						end
						

						1:begin
							X0	<=	COS_DATA[95:48];//16+32
							Y0 	<= 	COS_DATA[47:0];	//16+32
							
							CAL_REG_0 	<= 	X1 - COS_DATA[95:48]; //16+32
							CAL_REG_1 	<= 	{8'd0,B[0]/*8+16*/,16'd0} - COS_DATA[95:48]; //16+32
							CAL_REG_2	<=	Y1 - COS_DATA[47:0];

							COS_ADDR		<= 	0;
							state_counter <= state_counter + 1;
						end
						


						2:begin
							
							if(wait_ip_counter == 0)begin
								ca <= CAL_REG_1;
								cb <= CAL_REG_2;
								ce <= 1;
								cs <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							else if(cv)begin
								CAL_REG_1 <= co;
								wait_ip_counter <= 0;
								state_counter <= state_counter + 1;
							end
							else begin
								ce <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							
							
							//CAL_REG_1 <=  CAL_REG_1*CAL_REG_2 /*type:32+64*/ ; 
							
							//state_counter <= state_counter + 1;
						end

						
						3:begin
							
							if(wait_ip_counter == 0)begin
								ca <= Y0;
								cb <= CAL_REG_0;
								ce <= 1;
								cs <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							else if(cv)begin
								CAL_REG_1 <= co+CAL_REG_1;
								wait_ip_counter <= 0;
								state_counter <= state_counter + 1;
							end
							else begin
								ce <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							//CAL_REG_1 <= (Y0*CAL_REG_0 + CAL_REG_1)/*type:32+64*/ ; 
							//state_counter <= state_counter + 1;
						end


						4:begin
							
							if(wait_ip_counter == 0)begin
								ca <= CAL_REG_1<<32;
								cb <= CAL_REG_0;
								ce <= 1;
								cs <= 1;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							else if(cv)begin
								cos_b_lat <= co[63:0];
								wait_ip_counter <= 0;
								state_counter <=0;
								state <= COS_FUNCTION_0;
								//#1
								//$display("%h\n%h", ( (CAL_REG_1/*32+64*/<< 32) / CAL_REG_0/*16+32*/) ,cos_a_lat);
							end
							else begin
								ce <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							
							//cos_b_lat <= ( (CAL_REG_1/*32+64*/<<32) / CAL_REG_0/*16+32*/);//0+64
							//state_counter <= 0;
							//state <= COS_FUNCTION_0;
							//state_counter <= 0;
						end

					endcase
				end
				







				COS_FUNCTION_0 	:begin
					case(state_counter)
						
						0:begin
							CAL_REG_1 <= B[1]>A[1] ? B[1]-A[1] : A[1]-B[1];
							state_counter <= state_counter + 1;
						end
						

						1:begin
							
							if(wait_ip_counter == 0)begin
								ca <= CAL_REG_1;
								cb <= RAD;
								ce <= 1;
								cs <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							else if(cv)begin
								CAL_REG_1 <= co>>1;
								wait_ip_counter <= 0;
								state_counter <= state_counter + 1;
								COS_ADDR <= 1;
							end
							else begin
								ce <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							
							//CAL_REG_1 <= (CAL_REG_1*RAD)/*8+16 0+16*/ / 2; //8+32
							//state_counter <= state_counter + 1;
							//COS_ADDR <= 1;
							//#1
								//fra_part[0] = CAL_REG_1;
								//fra_part[0] = fra_part[0] /$pow(2,32);
								//$display("FUN_0 sin(%0.10f) ~= %0.10f",fra_part[0],fra_part[0]);
						end


						2:begin

							if(wait_ip_counter == 0)begin
								ca <= CAL_REG_1;
								cb <= CAL_REG_1;
								ce <= 1;
								cs <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							else if(cv)begin
								function_0 <= co;
								wait_ip_counter <= 0;
								state <= COS_FUNCTION_1;
								state_counter <= 0;
								ASIN_ADDR <= 0;
							end
							else begin
								ce <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end

							//function_0 <= CAL_REG_1*CAL_REG_1;//+64
							
							//state <= COS_FUNCTION_1;
							//state_counter <= 0;
							//ASIN_ADDR <= 0;
							//#1
								//fra_part[0] = CAL_REG_1;
								//fra_part[0] = fra_part[0] /$pow(2,64);
								//$display("FUN_0 sin^2(%0.10f) ~= %0.10f",fra_part[0],fra_part[0]);
								//$display("FUN_0 sin^2:%h",CAL_REG_1);
						end



						
						//3:begin
						//	a <= (function_0 * a) >> 64 ;//0+64 * 0+64	
						//	
						//	//#1	
						//	//$display("a:%h\n\n",a);
						//	state <= COS_FUNCTION_1;
						//	state_counter <= 0;
						//	ASIN_ADDR <= 0;
						//end

					
					
					endcase
				end
				











				COS_FUNCTION_1 	:begin
					case(state_counter)
						
						0:begin
							CAL_REG_1 <= B[0]>A[0] ? B[0]-A[0] : A[0]-B[0];
							state_counter <= state_counter + 1;
						end
						

						1:begin
							
							if(wait_ip_counter == 0)begin
								ca <= CAL_REG_1;
								cb <= RAD;
								ce <= 1;
								cs <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							else if(cv)begin
								CAL_REG_1 <= co>>1;
								wait_ip_counter <= 0;
								state_counter <= state_counter + 1;
								COS_ADDR <= 1;
							end
							else begin
								ce <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							
							//CAL_REG_1 <= (CAL_REG_1*RAD)/2/*8+16 0+16*/; //8+32
							//state_counter <= state_counter + 1;
							//COS_ADDR <= 1;
							//#1
							//fra_part[0] = CAL_REG_1;
							//fra_part[0] = fra_part[0] /$pow(2,32);
							//$display("FUN_1 sin(%0.10f) ~= %0.10f",fra_part[0],fra_part[0]);
						end



						2:begin

							if(wait_ip_counter == 0)begin
								ca <= CAL_REG_1;
								cb <= CAL_REG_1;
								ce <= 1;
								cs <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							else if(cv)begin
								function_1 <= co;
								wait_ip_counter <= 0;
								state <= CAL_A;
								state_counter <= 0;
								ASIN_ADDR <= 0;
							end
							else begin
								ce <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end

							//function_1 <= CAL_REG_1*CAL_REG_1;//0+64
					
							//state <= CAL_A;
							//state_counter <= 0;
							
						end

					
					
					endcase
				end
				




				CAL_A 					:begin
					

					case(state_counter)
						0:begin
							//$display("function_1:%h",function_1);
							//$display("cos_a_lat :%h",cos_a_lat);
							//$display("cos_b_lat :%h",cos_b_lat);
							//$display("function_0:%h",function_0);
							CAL_REG_1 <= cos_a_lat*cos_b_lat;
							//#1 $display("step 1.  a:%h",CAL_REG_1);
							state_counter <= state_counter + 1 ; 
						end


						1:begin
							
							if(wait_ip_counter == 0)begin
								ca <= CAL_REG_1[127-:64];
								cb <= function_0;
								ce <= 1;
								cs <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							else if(cv)begin
								CAL_REG_1 <= co;
								wait_ip_counter <= 0;
								state_counter <= state_counter+1;
							end
							else begin
								ce <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end

							//CAL_REG_1 <= ( (CAL_REG_1>>64) * function_0 )  ;//0+64 * 0+64	result +128

							////#1 $display("step 2.  a:%h",CAL_REG_1);
							//state_counter <= state_counter + 1 ; 
						end


						2:begin				
							CAL_REG_1 <= (function_1<<64) + CAL_REG_1  ; 
							
							//#1 $display("step 3.  a:%h",CAL_REG_1);

							state_counter <= state_counter + 1;
							
						end

						3:begin
							a <= CAL_REG_1[127:64];
							//#1 $display("step 4.  a:%h",a);
							state <= CAL_D;
							state_counter <= 0;
							ASIN_ADDR <= 1;
						end
					endcase
				end




				CAL_D						:begin
					case(state_counter)	
						0:begin
							//Find COS 
							if( ASIN_DATA[127:64] > a )begin
								X1 	<= ASIN_DATA[127:64];
								Y1	<= ASIN_DATA[63:0];	
									
								ASIN_ADDR <= ASIN_ADDR - 1 ;
								state_counter <= state_counter + 1;
							end
							else
								if(&ASIN_ADDR)begin
									ASIN_ADDR <= ASIN_ADDR - 1;
									state_counter <= state_counter +1 ;
								end
								else begin
									ASIN_ADDR <= ASIN_ADDR + 1;
								end
						end
						

						1:begin
							X0	<=	ASIN_DATA[127:64];
							Y0 	<= 	ASIN_DATA[63:0];	

							CAL_REG_0 	<= 	X1 - ASIN_DATA[127:64]; 
							CAL_REG_1 	<= 	a - ASIN_DATA[127:64]; 
							CAL_REG_2		<=	Y1 - ASIN_DATA[63:0];

							state_counter <= state_counter + 1;
						end
						


						2:begin


							if(wait_ip_counter == 0)begin
								ca <= CAL_REG_1;
								cb <= CAL_REG_2;
								ce <= 1;
								cs <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							else if(cv)begin
								CAL_REG_1 <= co;
								wait_ip_counter <= 0;
								state_counter <= state_counter+1;
							end
							else begin
								ce <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end

							//CAL_REG_1 <=  CAL_REG_1*CAL_REG_2 ;//128 
							//state_counter <= state_counter + 1;
						end



						3:begin


							if(wait_ip_counter == 0)begin
								ca <= Y0;
								cb <= CAL_REG_0;
								ce <= 1;
								cs <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							else if(cv)begin
								CAL_REG_1 <= co+CAL_REG_1;
								wait_ip_counter <= 0;
								state_counter <= state_counter+1;
							end
							else begin
								ce <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end

							//CAL_REG_1 <= Y0*CAL_REG_0 +CAL_REG_1;						
							//state_counter <= state_counter + 1;
						end


						4:begin


							if(wait_ip_counter == 0)begin
								ca <= CAL_REG_1;
								cb <= CAL_REG_0;
								ce <= 1;
								cs <= 1;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							else if(cv)begin
								CAL_REG_1 <= co;
								wait_ip_counter <= 0;
								state_counter <= state_counter+1;
							end
							else begin
								ce <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end

							//CAL_REG_1  <= (CAL_REG_1 / CAL_REG_0);
							//state_counter <= state_counter + 1;
							//#1
							//$display("X0:%h Y0:%h",X0,Y0);
							//$display("X1:%h Y1:%h",X1,Y1);
							//$display("X	:%h  Y:%h",a,CAL_REG_1);
						end



						5:begin
							
							if(wait_ip_counter == 0)begin
								ca <= CAL_REG_1;
								cb <= R;
								ce <= 1;
								cs <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end
							else if(cv)begin
								D <= co>>32;
								wait_ip_counter <= 0;
								state <= DATA_OUT;
								state_counter <= 0;
							end
							else begin
								ce <= 0;
								wait_ip_counter <= wait_ip_counter + 1;
							end

							//D = (CAL_REG_1*R) >>32;//+64 
							//state <= DATA_OUT;
							//state_counter <= 0;
						end
						

					endcase
				end

				DATA_OUT:begin
					state_counter <= 0;
					COS_ADDR <= 1;
					first <= 0;
					select <= ~select;
					if(select == 0) state <= READ_A;
					else state <= READ_B;
					//$display("cata_Out\n\n");
				end

				default begin
					state <= READ_A;
					state_counter <= 0;
					COS_ADDR <= 1;
				end




			endcase
		end
	end

	always@(*)begin
		Valid = (state==DATA_OUT)?1:0;
	end


endmodule


