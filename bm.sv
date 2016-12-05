//`include "fifo_i.sv"

//------------------------------------------ this is the memory that is built in the design--------------------------------------
//*********************Code for the memory starts here***************
module mem32x64(input bit clk,input logic [11:0] waddr,
    input logic [99:0] wdata, input bit write,
    input logic [11:0] raddr, output logic [99:0] rdata);

logic [99:0] mem[0:4096];

logic [99:0] rdatax;

logic [99:0] w0,w1,w2,w3,w4,w5,w6,w7;

assign rdata = rdatax;

always @(*) begin
  rdatax <= #2 mem[raddr];
end

always @(posedge(clk)) begin
  if(write) begin
    mem[waddr]<=#2 wdata;
  end
end

endmodule

//*********************Code for the memory ends here***************



//----------------------------------------This is the FIFO for the memory control------------------------------
//**********************FIFO code starts here****************************
   
module FIFO(clk, rst, push, data_in, pop ,data_out , fifo_full, fifo_empty);

input bit clk, rst, push, pop ;        // push = write     // pop = read
input  logic [99:0] data_in;
output logic [99:0] data_out;
output bit fifo_full, fifo_empty;


logic [11:0] write_address;
logic [11:0] read_address;
logic [11:0] fifo_count;

// generate internal write address
always@(posedge clk or posedge rst)

if (rst)
    write_address <= #1 'b0;  // 256 locations
else
    if (push == 1'b1 && (!fifo_full))                   // if write = 1 and if fifo is NOT full then perform write operation
        write_address <= #1 write_address + 1'b1;

// generate internal read address pointer
always@(posedge clk or posedge rst)
if (rst)
    read_address <= #1 'b0; // 256 locations
else
    if (pop == 1'b1 && (!fifo_empty))                   // if read = 1 and if fifo is NOT empty then perform read operation
        read_address <= #1 read_address +1'b1;

// generate FIFO count
// increment on push, decrement on pop
always@(posedge clk or posedge rst)
if (rst)
    fifo_count <= #1 'b0;   // 256 locations
else
    if (push== 1'b1 && pop == 1'b0 && (!fifo_full))
        fifo_count <= #1 (fifo_count + 1);        // increment counter if write
else
    if (push== 1'b0 && pop == 1'b1 && (!fifo_empty))               // decrement counter if read
        fifo_count <= #1 (fifo_count - 1);

// generate FIFO signals

assign fifo_full  =  (read_address == write_address+1)? 1'b1:1'b0; //(fifo_count == 8'b11111111)?1'b1:1'b0;
assign fifo_empty =   (read_address == write_address) ? 1'b1:1'b0; //(fifo_count == 8'b00000000)?1'b1:1'b0;

// connect RAM

mem32x64 mem1 (clk,write_address,data_in,push,read_address,data_out);

endmodule

//**********************FIFO code ends here****************************

//-----------------------------------This is the network on chip controller for the CRC block----------------------------------

//****************************Code for NOC starts here*********************

module noc(nocif n, crc_if c);

// These are the states defined in terms of parameter for state machine -1

  parameter idle_st 	    = 4'b0000;  //=0
  parameter src_id_st 	    = 4'b0001;  //=1
  parameter addr_st_1 	    = 4'b0010;  //=2
  parameter addr_st_2 	    = 4'b0011;  //=3
  parameter addr_st_3 	    = 4'b0100;  //=4
  parameter addr_st_4 	    = 4'b0101;  //=5
  parameter len_st          = 4'b0110;  //=6
  parameter write_data_st_1 = 4'b0111;  //=7
  parameter write_data_st_2 = 4'b1000;  //=8
  parameter write_data_st_3 = 4'b1001;  //=9
  parameter write_data_st_4 = 4'b1010;  //=10
  parameter testing_st	    = 4'b1011;  //=11

  //parameter read_data_st  = 4'b1000;  //=8

// These are the states defined in terms of parameter for state machine -2

  parameter idle_st_2 	    		= 6'b000000;  //=0
  parameter read_st_2_1     		= 6'b000001;  //=1
  parameter read_st_2_2     		= 6'b000010;  //=2
  parameter read_st_2_3     		= 6'b000011;  //=3
  parameter read_resp_st2_code      	= 6'b000100;  //=4
  parameter read_resp_st2_returnid  	= 6'b000101;  //=5
  parameter read_resp_st2_temp1_data1  	= 6'b000110;  //=6
  parameter read_resp_st2_temp1_data2  	= 6'b000111;  //=7
  parameter read_resp_st2_temp1_data3  	= 6'b001000;  //=8
  parameter read_resp_st2_temp1_data4  	= 6'b001001;  //=9
  parameter read_resp_st2_temp2_data1	= 6'b001010;  //=10
  parameter read_resp_st2_temp2_data2	= 6'b001011;  //=11
  parameter read_resp_st2_temp2_data3	= 6'b001100;  //=12
  parameter read_resp_st2_temp2_data4	= 6'b001101;  //=13
  parameter read_resp_st2_temp3_data1   = 6'b001110;  //=14
  parameter read_resp_st2_temp3_data2   = 6'b001111;  //=15
  parameter read_resp_st2_temp3_data3   = 6'b010000;  //=16
  parameter read_resp_st2_temp3_data4   = 6'b010001;  //=17
  parameter end_command			= 6'b010010;  //=18
  parameter write_st_2			= 6'b010011;  //=19
  parameter write_resp_st2_code		= 6'b010100;  //=20
  parameter write_resp_st2_returnid	= 6'b010101;  //=21

//----------------------bus_master states-------------------------
  parameter bm_st2_code			= 6'b010110;  //=22
  parameter bm_st2_sourceid		= 6'b010111;  //=23
  parameter bm_st2_addr1		= 6'b011000;  //=24
  parameter bm_st2_addr2		= 6'b011001;  //=25
  parameter bm_st2_addr3		= 6'b011010;  //=26
  parameter bm_st2_addr4		= 6'b011011;  //=27
  parameter bm_st2_len			= 6'b011100;  //=28
  parameter bm_st2_read_sourceid	= 6'b011101;  //=29

  parameter bm_st2_link1		= 6'b011110;  //=30
  parameter bm_st2_link2		= 6'b011111;  //=31
  parameter bm_st2_link3		= 6'b100000;  //=32
  parameter bm_st2_link4		= 6'b100001;  //=33

  parameter bm_st2_seed1		= 6'b100010;  //=34
  parameter bm_st2_seed2		= 6'b100011;  //=35
  parameter bm_st2_seed3		= 6'b100100;  //=36
  parameter bm_st2_seed4		= 6'b100101;  //=37

  parameter bm_st2_ctrl1		= 6'b100110;  //=38
  parameter bm_st2_ctrl2		= 6'b100111;  //=39
  parameter bm_st2_ctrl3		= 6'b101000;  //=40
  parameter bm_st2_ctrl4		= 6'b101001;  //=41

  parameter bm_st2_poly1		= 6'b101010;  //=42
  parameter bm_st2_poly2		= 6'b101011;  //=43
  parameter bm_st2_poly3		= 6'b101100;  //=44
  parameter bm_st2_poly4		= 6'b101101;  //=45

  parameter bm_st2_data1		= 6'b101110;  //=46
  parameter bm_st2_data2		= 6'b101111;  //=47
  parameter bm_st2_data3		= 6'b110000;  //=48
  parameter bm_st2_data4		= 6'b110001;  //=49

  parameter bm_st2_len1 		= 6'b110010;  //=50
  parameter bm_st2_len2 		= 6'b110011;  //=51
  parameter bm_st2_len3 		= 6'b110100;  //=52
  parameter bm_st2_len4 		= 6'b110101;  //=53

  parameter bm_st2_result1 		= 6'b110110;  //=54
  parameter bm_st2_result2 		= 6'b110111;  //=55
  parameter bm_st2_result3 		= 6'b111000;  //=56
  parameter bm_st2_result4 		= 6'b111001;  //=57

  parameter bm_st2_message1 		= 6'b111010;  //=58
  parameter bm_st2_message2 		= 6'b111011;  //=59
  parameter bm_st2_message3 		= 6'b111100;  //=60
  parameter bm_st2_message4 		= 6'b111101;  //=61

  parameter bm_write_crc_ctrl_initial	= 6'b111110;  //=62
  parameter bm_write_crc_seed		= 6'b111111;  //=63
  parameter bm_write_crc_ctrl_second	= 7'b1000000;  //=64
  parameter bm_write_crc_poly		= 7'b1000001;  //=65

//-------------for first 80H code------------

  parameter bm_st2_code_2		= 7'b1000010;  //=66
  parameter bm_st2_sourceid_2		= 7'b1000011;  //=67
  parameter bm_st2_addr1_2		= 7'b1000100;  //=68
  parameter bm_st2_addr2_2		= 7'b1000101;  //=69
  parameter bm_st2_addr3_2		= 7'b1000110;  //=70
  parameter bm_st2_addr4_2		= 7'b1000111;  //=71
  parameter bm_st2_len_2		= 7'b1001000;  //=72

  parameter blank_cycle_code    	= 7'd73;   //=73
  parameter blank_cycle_sourceid	= 7'd74;	//=74
  parameter feed_crc_state_1		= 7'd75;   //=75
  parameter feed_crc_state_2		= 7'd76;   //=76
  parameter feed_crc_state_3		= 7'd77;   //=77
  parameter feed_crc_state_4		= 7'd78;   //=78
  
  parameter bm_st2_check_crc		= 7'd79; 

  parameter bm_st2_send_result1		= 7'd80;
  parameter bm_st2_send_result2		= 7'd81;
  parameter bm_st2_send_result3		= 7'd82;
  parameter bm_st2_send_result4		= 7'd83;
  parameter bm_st2_send_result5		= 7'd84;
  parameter bm_st2_send_result6		= 7'd85;

  parameter bm_st2_send_len		= 7'd86;
  parameter bm_st2_send_check_crc1	= 7'd87;
  parameter bm_st2_send_check_crc2	= 7'd88;
  parameter bm_st2_send_check_crc3	= 7'd89;
  parameter bm_st2_send_check_crc4	= 7'd90;

  parameter bm_st2_check_link		= 7'd91;

  parameter bm_st2_message_code		= 7'd92;
  parameter bm_st2_send_message_1	= 7'd93;
  parameter bm_st2_send_message_2	= 7'd94;
  parameter bm_st2_send_message_3	= 7'd95;
  parameter bm_st2_send_message_4	= 7'd96;

//-------------for second 80H code------------
/*
  parameter bm_st2_code_3		= 7'd80;  //=80
  parameter bm_st2_sourceid_3		= 7'd81;  //=81
  parameter bm_st2_addr1_3		= 7'd82;  //=82
  parameter bm_st2_addr2_3		= 7'd83;  //=83
  parameter bm_st2_addr3_3		= 7'd84;  //=84
  parameter bm_st2_addr4_3		= 7'd85;  //=85
  parameter bm_st2_len_3		= 7'd86;  //=86

  parameter blank_cycle_code_4    	= 7'd87;   //=87
  parameter blank_cycle_sourceid_4	= 7'd88;   //=88
  parameter feed_crc_state_1_4		= 7'd89;   //=89
  parameter feed_crc_state_2_4		= 7'd90;   //=90
  parameter feed_crc_state_3_4		= 7'd91;   //=91
  parameter feed_crc_state_4_4		= 7'd92;   //=92
  parameter magical_state_2		= 7'd93;   //=93

//-----------------for 80H code----------------------

  parameter bm_st2_code_4		= 7'd94;  //=94
  parameter bm_st2_sourceid_4		= 7'd95;  //=95
  parameter bm_st2_addr1_4		= 7'd96;  //=96
  parameter bm_st2_addr2_4		= 7'd97;  //=97
  parameter bm_st2_addr3_4		= 7'd98;  //=98
  parameter bm_st2_addr4_4		= 7'd99;  //=99
  parameter bm_st2_len_4		= 7'd100;  //=100

  parameter blank_cycle_code_5    	= 7'd101;   //=101
  parameter blank_cycle_sourceid_5	= 7'd102;   //=102
  parameter feed_crc_state_1_5		= 7'd103;   //=103
  parameter feed_crc_state_2_5		= 7'd104;   //=104
  parameter feed_crc_state_3_5		= 7'd105;   //=105
  parameter feed_crc_state_4_5		= 7'd106;   //=106
  parameter magical_state_3		= 7'd107;   //=107
*/
//--------------------------------------

  parameter send_data_state		= 7'd108;

// Variable declaration for state machine -1 

  logic [99:0] data_in_fifo, data_out_fifo;
  logic [31:0] addr;
  logic [31:0] wr_data;
  logic [7:0]  length;
  logic [7:0]  DataW;
  logic [7:0]  ctrl_main, ctrl_main_flop;
  logic [7:0]  source_id;
  logic [3:0]  present_state, next_state;		// Number of possible state values is 16.
  bit          len;
  bit 	       push, pop;

/*
  ;
  , addr_flop;
  logic [31:0] wr_data, wr_data_flop;
  
  , return_id;
  
  logic [2:0]  cntr; 					// cntr = counter for address bytes; cntr1 = counter for write bytes.
  
  
  bit 	       flag_exp, flag_src_id, flag_addr;

  bit 	       fifo_full, fifo_empty;
*/

// Variable declaration for state machine -2

  logic [6:0]  present_state_2, next_state_2;
  logic [7:0]  source_id_2, return_id_2;
  logic [7:0]  ctrl_main_2;
  logic [31:0] addr_2, addr_2_flop;
  logic [31:0] data_2;
  logic [7:0]  length_2;
  logic [31:0] temp1, temp2, temp3, temp4;

// Variable declaration for state machine -3
  logic [31:0] chain, start_chain;
  logic [31:0] bm_link, bm_seed, bm_ctrl, bm_poly,bm_data, bm_data_flop, bm_len, bm_len_flop, bm_result, bm_message, crc_write, crc_write_flop;
  logic [7:0] count_crc, count_crc_flop;
  logic [31:0] check_crc;
  bit bm_mode, flag_chain, flag_test;

// Instantiation of a FIFO

  FIFO f1 (n.clk, n.rst, push, data_in_fifo, pop, data_out_fifo, fifo_full, fifo_empty);

  //fifo f1 (data_in_fifo, data_out_fifo, RW, n.clk, n.rst);

  //fifo f2 (data_in_fifo, data_out_fifo, 1'b0, n.clk, n.rst);

//------------------------------------------------------code starts from here----------------------------------------------------------------
  
  //assign DataWs    = n.DataW;					// This is the 8-bit data(common register) that comes from the testbench to NOC.
  //assign CmdW      = n.CmdW;					// This is the 9th bit-> bit[8] of the data that comes to NOC from the testbench. 

// This is always @posedge block for state machine -1

/*********************ISSUE****************
  The major issue in this design is that if CmdW (personal) is used then the state machine does not respond to it. 
*******************************************
*/

  always@(posedge n.clk or posedge n.rst)
    begin
      if(n.rst)
        begin
	  DataW	 	  = 0;
	  //CmdW 	  = 0;
	  ctrl_main_flop  = 0;
	  addr_2_flop     = 0;
	  bm_len_flop	  = 0;
	  bm_data_flop	  = 0;
	  count_crc_flop  = 0;
	  crc_write_flop  = 0;
	  present_state   = idle_st;
	  present_state_2 = idle_st_2;
	end
      else
	begin
	  DataW 	  = n.DataW;
	  //CmdW	  = n.CmdW;
	  ctrl_main_flop  = ctrl_main;
	  addr_2_flop     = addr_2;
	  present_state   = next_state;
	  present_state_2 = next_state_2;
	  return_id_2	  = source_id_2;  // This return_id_2 is used in the read_resp_returnid for returning the ID.
	  bm_len_flop	  = bm_len;
	  bm_data_flop	  = bm_data;
	  count_crc_flop  = count_crc;
  	  crc_write_flop  = crc_write;
	end
    end


// This is the combinational block for state machine -1
//-----------------------------------------------------
  always@(*)
    begin
      case(present_state)
      idle_st:		// This is state = 0
	begin
	  if(n.CmdW == 1)
	    begin
	      ctrl_main = DataW;

	      if	(DataW[7:5] == 3'b000) next_state = idle_st;
	      else 
		begin
		  next_state 	= src_id_st;
		  len	     	= DataW[4];
	      	end
	    end

	  push		= 0;  //-----------this is changed 2
	  //pop			= 1;
	end

      src_id_st:	// This is state = 1
	begin
	  source_id	= DataW;
	  next_state	= addr_st_1;
	end

      addr_st_1:	// This is state = 2
	begin
	  if(ctrl_main[3:0] == 4'b1000)
	    begin
	      addr[7:0] 	= DataW;
	      addr[31:8]	= 24'hffffff;

	      next_state	= len_st;
	    end
	  else
	    begin
	      addr[7:0]		= DataW;
	      next_state	= addr_st_2;
	    end
	end

      addr_st_2:	// This is state = 3
	begin
	  addr[15:8]	= DataW;
	  next_state	= addr_st_3;
	end

      addr_st_3:	// This is state = 4
	begin
	  addr[23:16]	= DataW;
	  next_state	= addr_st_4;
	end

      addr_st_4:	// This is state = 5
	begin
	  addr[31:24]	= DataW;
	  next_state	= len_st;
	end

      len_st:		// This is state = 6
	begin
	  length	= DataW;

	    if      	(ctrl_main_flop[7:5] == 3'b001)		// READ
	      begin
	 	push	        = 1;
		//pop		= 0;  //--------This is changed 3
		data_in_fifo	= {12'b0, ctrl_main, source_id, addr, length, 32'b0};
		next_state     	= idle_st;
	      end
	    else if	(ctrl_main_flop[7:5] == 3'b011)		// WRITE
	      begin
		next_state     = write_data_st_1;
	      end
		else 
		next_state     = idle_st;

	end

      write_data_st_1:		// This is state = 7
	begin
	  if		(addr == 32'hffff_fff0)
	    begin
	      chain[7:0]		= DataW;
	    end
  	  else if	(addr == 32'hffff_fff4)
	    begin
	      start_chain[7:0]		= DataW;
	    end
	  else
	    begin
	      wr_data[7:0]		= DataW;
	    end
	  next_state		= write_data_st_2;
	end

      write_data_st_2:		// This is state = 8
	begin
	  if		(addr == 32'hffff_fff0)
	    begin
	      chain[15:8]		= DataW;
	    end
  	  else if	(addr == 32'hffff_fff4)
	    begin
	      start_chain[15:8]		= DataW;
	    end
	  else
	    begin
	      wr_data[15:8]		= DataW;
	    end

	  next_state		= write_data_st_3;
	end

      write_data_st_3:		// This is state = 9
	begin
	  if		(addr == 32'hffff_fff0)
	    begin
	      chain[23:16]		= DataW;
	    end
  	  else if	(addr == 32'hffff_fff4)
	    begin
	      start_chain[23:16]	= DataW;
	    end
	  else
	    begin
	      wr_data[23:16]		= DataW;
	    end

	  next_state		= write_data_st_4;
	end

      write_data_st_4:		// This is state = 10
	begin
	  if		(addr == 32'hffff_fff0)
	    begin
	      chain[31:24]		= DataW;
	      flag_chain	= 0;
	    end
	  else if	(addr == 32'hffff_fff4)
	    begin
	      start_chain[31:24]	= DataW;
	    end
	  else
	    begin
	      wr_data[31:24]	= DataW;
	      push			= 1;
	      //pop 			= 0;  //---------------this is changed
	      data_in_fifo	  	= {12'b0, ctrl_main, source_id, addr, length, wr_data};
	      //next_state		= testing_st;
	    end

	  next_state		= idle_st;
	end
/*
      testing_st:
	begin
	  push			= 0;
	  pop 			= 1;
	  //RW			= 0;
	  //output1		= data_out_fifo;
	  next_state		= idle_st;
	end
*/

      endcase
    end

//*********This is the third machine for bus master*******************************

//*********This is the end of bus master******************************************

//*********This is the second state machine that takes data from the FIFO and writes in the CRC block depending upon the address*****************
// This state machine will generate signals for the CRC block which was earlier generated by the test-bench.

  always@(*)
    begin
      case(present_state_2)
	idle_st_2:		// This is state = 0;
	  begin
	    //push		= 0;  //---------------this is changed
	    if(start_chain!=0)
	      begin
		
		n.CmdR  	= 1;

	  	n.DataR 	= 8'h00;
		next_state_2 	= bm_st2_check_link;
	      end
	    else
	      begin
		bm_mode = 0;	// to indicate the noc mode.
		if(!fifo_empty) pop			= 1;
	    	else pop = 0;
	    
	    	c.RW		= 0; //////// changed by I.
	    	c.Sel		= 0;  // not necessary

	    	n.CmdR = 1;
	    	n.DataR = 0;

	    	ctrl_main_2    	= data_out_fifo[87:80];		
	    	source_id_2    	= data_out_fifo[79:72];	// This value is flopped and put into the return_id_2 logic variable.	
	    	addr_2         	= data_out_fifo[71:40];
	    	length_2	= data_out_fifo[39:32];
	    	data_2	   	= data_out_fifo[31:0];
	    
	    	if		(ctrl_main_2[7:5] == 3'b001 && fifo_empty == 0) next_state_2 = read_st_2_1;	// This is a read          Ishwakki
	    	else if		(ctrl_main_2[7:5] == 3'b011 && fifo_empty == 0) next_state_2 = write_st_2;	// This is a write 	   Ishwakki
	    	else 				     	     next_state_2 = idle_st_2;		// This is an idle

	    	//temp4		= c.data_rd;
	      	end
	    
	  end
	bm_st2_check_link:			// this is state = 91;
	  begin
	    if((flag_chain==0)?chain : bm_link !=0) begin
	      next_state_2	= bm_st2_code;
	    end
	    else  if((flag_chain==0)?chain : bm_link ==0) begin
	      start_chain	= 0;
	      next_state_2	= idle_st_2;
	    end
	
	  end

	bm_st2_code:
	  begin
	    bm_mode 	= 1;	// to indicate bus master mode.

	    n.CmdR 		= 1;
	    n.DataR  		= 8'h23;

	    next_state_2  	= bm_st2_sourceid;
	  end

	bm_st2_sourceid:
	  begin
	    n.CmdR		= 0;
	    n.DataR		= 8'h01;

	    next_state_2	= bm_st2_addr1;
	  end

	bm_st2_addr1:
	  begin
	    n.DataR		= (flag_chain==0)?chain[7:0] : bm_link[7:0];

	    next_state_2	= bm_st2_addr2;
	  end

	bm_st2_addr2:
	  begin
	    n.DataR		= (flag_chain==0)?chain[15:8] : bm_link[15:8];

	    next_state_2	= bm_st2_addr3;
	  end

	bm_st2_addr3:
	  begin
	    n.DataR		= (flag_chain==0)?chain[23:16] : bm_link[23:16];

	    next_state_2	= bm_st2_addr4;
	  end

	bm_st2_addr4:
	  begin
	    n.DataR		= (flag_chain==0)?chain[31:24] : bm_link[31:24];

	    next_state_2	= bm_st2_len;
	  end

	bm_st2_len:		// This is state = 28;
	  begin
	    n.DataR		= 8'h20;

	    next_state_2	= bm_st2_read_sourceid;
	  end

	bm_st2_read_sourceid:	// This is state = 29; This is to check the return id that matches with your sent sourceid in the read response generated by TB
	  begin
	    n.CmdR		= 1;
	    n.DataR		= 8'h00;

	    if(DataW == 8'h01)
	      begin
		next_state_2	= bm_st2_link1;
	      end
	    else
	      begin
		next_state_2	= bm_st2_read_sourceid;
	      end
	  end

	bm_st2_link1:		// This is state = 30;
	  begin
	    bm_link[7:0]	= DataW;

	    next_state_2	= bm_st2_link2;
	  end

	bm_st2_link2:		// This is state = 31;
	  begin
	    bm_link[15:8]	= DataW;

	    next_state_2	= bm_st2_link3;
	  end

	bm_st2_link3:		// This is state = 32;
	  begin
	    bm_link[23:16]	= DataW;

	    next_state_2	= bm_st2_link4;
	  end

	bm_st2_link4:		// This is state = 33;
	  begin
	    bm_link[31:24]	= DataW;
	    flag_chain	= 1;
	    next_state_2	= bm_st2_seed1;
	  end

	bm_st2_seed1:		// This is state = 34;
	  begin
	    bm_seed[7:0]	= DataW;

	    next_state_2	= bm_st2_seed2;
	  end

	bm_st2_seed2:		// This is state = 35;
	  begin
	    bm_seed[15:8]	= DataW;

	    next_state_2	= bm_st2_seed3;
	  end

	bm_st2_seed3:		// This is state = 36;
	  begin
	    bm_seed[23:16]	= DataW;

	    next_state_2	= bm_st2_seed4;
	  end

	bm_st2_seed4:		// This is state = 37;
	  begin
	    bm_seed[31:24]	= DataW;

	    next_state_2	= bm_st2_ctrl1;
	  end

	bm_st2_ctrl1:
	  begin
	    bm_ctrl[7:0]	= DataW;

	    next_state_2	= bm_st2_ctrl2;
	  end

	bm_st2_ctrl2:
	  begin
	    bm_ctrl[15:8]	= DataW;

	    next_state_2	= bm_st2_ctrl3;
	  end

	bm_st2_ctrl3:
	  begin
	    bm_ctrl[23:16]	= DataW;

	    next_state_2	= bm_st2_ctrl4;
	  end

	bm_st2_ctrl4:
	  begin
	    bm_ctrl[31:24]	= DataW;

	    next_state_2	= bm_st2_poly1;
	  end

	bm_st2_poly1:
	  begin
	    bm_poly[7:0]	= DataW;

	    next_state_2	= bm_st2_poly2;
	  end

	bm_st2_poly2:
	  begin
	    bm_poly[15:8]	= DataW;

	    next_state_2	= bm_st2_poly3;
	  end

	bm_st2_poly3:
	  begin
	    bm_poly[23:16]	= DataW;

	    next_state_2	= bm_st2_poly4;
	  end

	bm_st2_poly4:
	  begin
	    bm_poly[31:24]	= DataW;

	    next_state_2	= bm_st2_data1;
	  end

	bm_st2_data1:
	  begin
	    bm_data[7:0]	= DataW;

	    next_state_2	= bm_st2_data2;
	  end

	bm_st2_data2:
	  begin
	    bm_data[15:8]	= DataW;

	    next_state_2	= bm_st2_data3;
	  end

	bm_st2_data3:
	  begin
	    bm_data[23:16]	= DataW;

	    next_state_2	= bm_st2_data4;
	  end

	bm_st2_data4:
	  begin
	    bm_data[31:24]	= DataW;

	    next_state_2	= bm_st2_len1;
	  end

	bm_st2_len1:
	  begin
	    bm_len[7:0]		= DataW;

	    next_state_2	= bm_st2_len2;
	  end

	bm_st2_len2:
	  begin
	    bm_len[15:8]	= DataW;

	    next_state_2	= bm_st2_len3;
	  end

	bm_st2_len3:
	  begin
	    bm_len[23:16]	= DataW;

	    next_state_2	= bm_st2_len4;
	  end

	bm_st2_len4:
	  begin
	    bm_len[31:24]	= DataW;

	    next_state_2	= bm_st2_result1;
	    //next_state_2	= idle_st_2;
	  end

	bm_st2_result1:
	  begin
	    bm_result[7:0]	= DataW;

	    next_state_2	= bm_st2_result2;
	  end

	bm_st2_result2:
	  begin
	    bm_result[15:8]	= DataW;

	    next_state_2	= bm_st2_result3;
	  end

	bm_st2_result3:
	  begin
	    bm_result[23:16]	= DataW;

	    next_state_2	= bm_st2_result4;
	  end

	bm_st2_result4:
	  begin
	    bm_result[31:24]	= DataW;

	    next_state_2	= bm_st2_message1;
	  end

	bm_st2_message1:
	  begin
	    bm_message[7:0]	= DataW;

	    next_state_2	= bm_st2_message2;
	  end

	bm_st2_message2:
	  begin
	    bm_message[15:8]	= DataW;

	    next_state_2	= bm_st2_message3;
	  end

	bm_st2_message3:
	  begin
	    bm_message[23:16]	= DataW;

	    next_state_2	= bm_st2_message4;
	  end

	bm_st2_message4:
	  begin
	    bm_message[31:24]	= DataW;

	    next_state_2	= bm_write_crc_ctrl_initial;
	  end

	bm_write_crc_ctrl_initial:
	  begin
	    c.addr		= 32'h4003_2008;
	    c.Sel		= 1;
	    c.RW		= 1;
	    c.data_wr		= (bm_ctrl | 32'h0200_0000);
	    
	    next_state_2	= bm_write_crc_seed;
	  end

	bm_write_crc_seed:
	  begin
	    c.addr		= 32'h4003_2000;
	    c.data_wr		= bm_seed;

	    next_state_2	= bm_write_crc_ctrl_second;
	  end

	bm_write_crc_ctrl_second:
	  begin
	    c.addr		= 32'h4003_2008;
	    c.data_wr		= bm_ctrl & 32'hfdff_ffff;

	    next_state_2	= bm_write_crc_poly;
	  end

	bm_write_crc_poly:		// this is state = 65
	  begin
	    c.addr		= 32'h4003_2004;
	    c.data_wr		= bm_poly;

	    //next_state_2	= idle_st_2;
	    next_state_2	= bm_st2_code_2;
	    
	  end

//------------------------read command to read first 80H data to send.

	bm_st2_code_2:
	  begin
	    n.CmdR		= 1;
	    n.DataR		= 8'h23;

	    c.Sel		= 0;
	    c.RW		= 0;

	    
	   
	     
	    next_state_2	= bm_st2_sourceid_2;
	  end	

	bm_st2_sourceid_2:		// This is 67
	  begin
	    n.CmdR		= 0;
	    n.DataR		= 8'h01;

	    next_state_2	= bm_st2_addr1_2;
	  end


	bm_st2_addr1_2:
	begin
	    n.CmdR		= 0;
	    n.DataR		= bm_data[7:0];

	    next_state_2	= bm_st2_addr2_2;
	end

	bm_st2_addr2_2:
	  begin
	    n.DataR		= bm_data[15:8];

	    next_state_2	= bm_st2_addr3_2;
	  end

	bm_st2_addr3_2:
	  begin
	    n.DataR		= bm_data[23:16];

	    next_state_2	= bm_st2_addr4_2;
	  end

	bm_st2_addr4_2:
	  begin
	    n.DataR		= bm_data[31:24];

	    next_state_2	= bm_st2_len_2;
	  end

	bm_st2_len_2:				// This is state = 72
	  begin
	    if(bm_len_flop>8'h80)
	      begin
		count_crc	= 8'h80;
		//bm_len  	= bm_len_flop - 8'h80;
		
		n.DataR      	= 8'h80;
	      end
	    else
	      begin
	        count_crc	= bm_len_flop;
	        n.DataR		= bm_len_flop;
	      end

	    next_state_2	= blank_cycle_code;
	  end

	blank_cycle_code: 		// This is state = 73
	  begin
	    n.CmdR		= 1;
	    n.DataR		= 8'h00;
	    next_state_2	= blank_cycle_sourceid;
	  end

	blank_cycle_sourceid:			// This is state = 74
	  begin
	    next_state_2    	= feed_crc_state_1;
	  end

	feed_crc_state_1:			// This is state = 75
	  begin
	    n.CmdR = 1;
	    n.DataR = 8'h0;

	    c.Sel		= 0;
	    c.RW		= 0;

	    crc_write[7:0]	= DataW; //n.DataW;
	    next_state_2	= feed_crc_state_2; 
	  end

	feed_crc_state_2:		// This is state = 76
	  begin
	    n.CmdR = 1;
	    n.DataR = 8'h0;

	    crc_write[15:8]	= DataW; //n.DataW;
	    next_state_2	= feed_crc_state_3; 
	  end

	feed_crc_state_3:		// This is state = 77
	  begin
	    n.CmdR = 1;
	    n.DataR = 8'h0;

	    crc_write[23:16]	= DataW; //n.DataW;
	    next_state_2	= feed_crc_state_4; 
	  end

	feed_crc_state_4:		// This is state = 78
	  begin
	    n.CmdR = 1;
	    n.DataR = 8'h0;
	    flag_test = 1;

	    c.Sel		= 1;
	    c.RW		= 1;

	    crc_write[31:24]	= DataW; //n.DataW;

	    c.addr		= 32'h4003_2000;
	    c.data_wr		= crc_write;	// This has been changed.

	    count_crc		= count_crc_flop - 8'h04;
	    bm_len		= bm_len_flop - 8'h04;

	    if(bm_len != 32'h0)
	      begin
	        if(count_crc !=0)
	          begin
		    next_state_2	= feed_crc_state_1;
	          end
	        else if(count_crc ==0)
	          begin
		     bm_data = bm_data_flop + 8'h80;
		    next_state_2	= bm_st2_code_2;
	          end
	      end
	    else if(bm_len == 32'h0)
	      begin
		next_state_2		= bm_st2_check_crc;
	      end
	  end

	bm_st2_check_crc:			// this is state = 79
	  begin
	    c.Sel 			= 1;
	    c.RW 			= 0;
	    c.addr			= 32'h4003_2000;

	    check_crc 			= c.data_rd;

	    next_state_2		= bm_st2_send_result1;
	  end

	bm_st2_send_result1:   // -=80
	  begin
	    c.Sel			= 0;
     	    c.RW			= 0;

	    n.CmdR			= 1;
	    n.DataR			= 8'h63;

	    next_state_2		= bm_st2_send_result2;
	  end

	bm_st2_send_result2:		//81
	  begin
	    n.CmdR			= 0;
	    n.DataR			= 8'h01;

	    next_state_2	= bm_st2_send_result3;
	  end

	bm_st2_send_result3:		//82
	  begin
	    n.CmdR			= 0;
	    n.DataR			= bm_result[7:0];

	    next_state_2	= bm_st2_send_result4;
	  end

	bm_st2_send_result4:		//83
	  begin
	    n.CmdR			= 0;
	    n.DataR			= bm_result[15:8];

	    next_state_2	= bm_st2_send_result5;
	  end

	bm_st2_send_result5:		//84
	  begin
	    n.CmdR			= 0;
	    n.DataR			= bm_result[23:16];

	    next_state_2	= bm_st2_send_result6;
       	  end

	bm_st2_send_result6:		//85
	  begin
	    n.CmdR			= 0;
	    n.DataR			= bm_result[31:24];

	    next_state_2		= bm_st2_send_len;
       	  end

	bm_st2_send_len:		//86
	  begin
	    n.CmdR			= 0;
	    n.DataR			= 8'h04; 		// to edit

	    next_state_2	= bm_st2_send_check_crc1;
       	  end

	bm_st2_send_check_crc1:		//87
	  begin
	    n.CmdR			= 0;
	    n.DataR			= check_crc[7:0]; 		// to edit

	    next_state_2		= bm_st2_send_check_crc2;
       	  end

	bm_st2_send_check_crc2:		//88
	  begin
	    n.CmdR			= 0;
	    n.DataR			= check_crc[15:8]; 		// to edit

	    next_state_2		= bm_st2_send_check_crc3;
       	  end

	bm_st2_send_check_crc3:		//89
	  begin
	    n.CmdR			= 0;
	    n.DataR			= check_crc[23:16]; 		// to edit

	    next_state_2		= bm_st2_send_check_crc4;
       	  end

	bm_st2_send_check_crc4:		//90
	  begin
	    n.CmdR			= 0;
	    n.DataR			= check_crc[31:24]; 		// to edit

	    //next_state_2		= idle_st_2;
	    next_state_2		= bm_st2_message_code;
       	  end

	bm_st2_message_code:		//=92  This is not 91
	  begin
	    n.CmdR			= 1;
	    n.DataR			= 8'hc4;

	    next_state_2		= bm_st2_send_message_1;
	  end

	bm_st2_send_message_1:
	  begin
	    n.CmdR			= 0;
	    n.DataR			= bm_message[7:0];

	    next_state_2		= bm_st2_send_message_2;
	  end

	bm_st2_send_message_2:
	  begin
	    n.CmdR			= 0;
	    n.DataR			= bm_message[15:8];

	    next_state_2		= bm_st2_send_message_3;
	  end

	bm_st2_send_message_3:
	  begin
	    n.CmdR			= 0;
	    n.DataR			= bm_message[23:16];

	    next_state_2		= bm_st2_send_message_4;
	  end

	bm_st2_send_message_4:
	  begin
	    n.CmdR			= 0;
	    n.DataR			= bm_message[31:24];

	    next_state_2		= idle_st_2;
	  end


//-------------------------second 80 H data
/*
	bm_st2_code_3:	//This is state = 80
	  begin
	    n.CmdR		= 1;
	    n.DataR		= 8'h23;

	    next_state_2	= bm_st2_sourceid_3;
	  end

	bm_st2_sourceid_3:
	  begin
	    n.CmdR		= 0;
	    n.DataR		= 8'h01;

	    next_state_2	= bm_st2_addr1_3;
	  end

	
	bm_st2_addr1_3:
	begin
	    n.CmdR		= 0;
	    n.DataR		= bm_data[7:0];

	    next_state_2	= bm_st2_addr2_3;
	end
	
	bm_st2_addr2_3:
	  begin
	    n.DataR		= bm_data[15:8];

	    next_state_2	= bm_st2_addr3_3;
	  end

	bm_st2_addr3_3:
	  begin
	    n.DataR		= bm_data[23:16];

	    next_state_2	= bm_st2_addr4_3;
	  end

	bm_st2_addr4_3:
	  begin
	    n.DataR		= bm_data[31:24];

	    next_state_2	= bm_st2_len_3;
	  end

	bm_st2_len_3:
	  begin
	    if(bm_len_flop>8'h80)
	      begin
		bm_len  	= bm_len_flop - 8'h80;
		bm_data 	= bm_data_flop + 8'h80;
		n.DataR      	= 8'h80;
	      end
	    else
	      begin
	        n.DataR		= bm_len_flop;
	      end
	   
	    next_state_2	= blank_cycle_code_4;
	  end

	blank_cycle_code_4:
	  begin
	    n.CmdR		= 1;
	    n.DataR		= 8'h00;
	    next_state_2	= blank_cycle_sourceid_4;
	  end

	blank_cycle_sourceid_4:
	  begin
	    next_state_2	= feed_crc_state_1_4;
	  end

	feed_crc_state_1_4:
	  begin
	    n.CmdR = 1;
	    n.DataR = 8'h0;

	    crc_write[7:0]	= n.DataW;
	    next_state_2	= feed_crc_state_2_4;
	  end

	feed_crc_state_2_4:
	  begin
	    n.CmdR = 1;
	    n.DataR = 8'h0;

	    crc_write[15:8]	= n.DataW;
	    next_state_2	= feed_crc_state_3_4;
	  end

	feed_crc_state_3_4:
	  begin
	    n.CmdR = 1;
	    n.DataR = 8'h0;

	    crc_write[23:16]	= n.DataW;
	    next_state_2	= feed_crc_state_4_4; 
	  end

	feed_crc_state_4_4:
	  begin
	    n.CmdR = 1;
	    n.DataR = 8'h0;

	    crc_write[31:24]	= n.DataW;
	    next_state_2	= magical_state_2;
	  end

	magical_state_2: 
	  begin
	    c.data_wr	= crc_write;

	    if(n.DataW == 8'he0)
	      begin
		next_state_2 = bm_st2_code_4;
	      end
	    else
	      begin
		crc_write[7:0] 	= n.DataW;
		next_state_2    = feed_crc_state_1_4;
	      end
	  end

//-----------------------------This is for 38H code
	bm_st2_code_4:
	  begin
	    n.CmdR		= 1;
	    n.DataR		= 8'h23;

	    next_state_2	= bm_st2_sourceid_4;
	  end

	bm_st2_sourceid_4:
	  begin
	    n.CmdR		= 0;
	    n.DataR		= 8'h01;

	    next_state_2	= bm_st2_addr1_4;
	  end

	bm_st2_addr1_4:
	begin
	    n.CmdR		= 0;
	    n.DataR		= bm_data[7:0];

	    next_state_2	= bm_st2_addr2_4;
	end

	bm_st2_addr2_4:
	  begin
	    n.DataR		= bm_data[15:8];

	    next_state_2	= bm_st2_addr3_4;
	  end

	bm_st2_addr3_4:
	  begin
	    n.DataR		= bm_data[23:16];

	    next_state_2	= bm_st2_addr4_4;
	  end

	bm_st2_addr4_4:
	  begin
	    n.DataR		= bm_data[31:24];

	    next_state_2	= bm_st2_len_4;
	  end

	bm_st2_len_4:		// This is to be changed
	  begin
	    if(bm_len_flop>8'h80)
	      begin
		bm_len  	= bm_len_flop - 8'h80;
		bm_data 	= bm_data_flop + 8'h80;
		n.DataR      	= 8'h80;
	      end
	    else
	      begin
	        n.DataR		= bm_len_flop;
	      end
	   
	    next_state_2	= blank_cycle_code_5;
	  end

	blank_cycle_code_5:
	  begin
	    n.CmdR		= 1;
	    n.DataR		= 8'h00;
	    next_state_2	= blank_cycle_sourceid_5;
	  end

	blank_cycle_sourceid_5:
	  begin
	    next_state_2	= feed_crc_state_1_5;
	  end

	feed_crc_state_1_5:
	  begin
	    n.CmdR = 1;
	    n.DataR = 8'h0;

	    crc_write[7:0]	= n.DataW;
	    next_state_2	= feed_crc_state_2_5;
	  end

	feed_crc_state_2_5:
	  begin
	    n.CmdR = 1;
	    n.DataR = 8'h0;

	    crc_write[15:8]	= n.DataW;
	    next_state_2	= feed_crc_state_3_5;
	  end

	feed_crc_state_3_5:
	  begin
	    n.CmdR = 1;
	    n.DataR = 8'h0;

	    crc_write[23:16]	= n.DataW;
	    next_state_2	= feed_crc_state_4_5; 
	  end

	feed_crc_state_4_5:
	  begin
	    n.CmdR = 1;
	    n.DataR = 8'h0;

	    crc_write[31:24]	= n.DataW;
	    next_state_2	= magical_state_3;
	  end

	magical_state_3: 
	  begin
	    c.data_wr	= crc_write;

	    if(n.DataW == 8'he0)
	      begin
		next_state_2 = send_data_state;
	      end
	    else
	      begin
		crc_write[7:0] 	= n.DataW;
		next_state_2    = feed_crc_state_1_5;
	      end
	  end

	send_data_state:  // this state needs to be completed.
	  begin
	  end
*/

//-------------------
/*
	bm_end_command:
	  begin
	    n.CmdR		= 1;
	    n.DataR		= 8'b11100000; //=E0

	    next_state_2	= idle_st_2;
	  end
*/

	read_st_2_1:			// This is state = 1;
	  begin
	    pop			= 0;
	    c.RW		= 0;
	    c.Sel		= 1;
	    c.addr 		= addr_2_flop;
	    temp1		= c.data_rd;

	    //if (length_2 == 8'h04)	next_state_2 = idle_st_2;
	    if (length_2 == 8'h04)	next_state_2 = read_resp_st2_code;
	    else
	      begin
		addr_2		= addr_2_flop + 4;
	 	next_state_2 	= read_st_2_2;
	      end
	  end

	read_st_2_2:			// This is state = 2;
	  begin
	    c.addr		= addr_2_flop;
	    temp2		= c.data_rd;

	    //if (length_2 == 8'h08)	next_state_2 = idle_st_2;
	    if (length_2 == 8'h08)	next_state_2 = read_resp_st2_code;
	    else
	      begin
		addr_2		= addr_2_flop + 4;
		next_state_2	= read_st_2_3;
	      end
	  end

	read_st_2_3:			// This is state = 3;
	  begin
	    c.addr		= addr_2_flop;
	    temp3		= c.data_rd;
	
	    //next_state_2	= idle_st_2;
	    next_state_2	= read_resp_st2_code;
	  end


	read_resp_st2_code:		// This is state = 4; This is the first state that is used to pass the read response code out of the NOC.
	  begin
	    c.Sel 	 	= 1'b0; 

	    n.CmdR  		= 1'b1;
	    n.DataR 		= 8'h40;
            
	    //next_state_2	= idle_st_2;
   	    next_state_2 	= read_resp_st2_returnid;
	  end

	read_resp_st2_returnid:		// This is state = 5; This state will give the return ID to the ouput of the NOc block.
	  begin
	    n.CmdR 		= 1'b0;
	    n.DataR		= return_id_2;
	
	    next_state_2	= read_resp_st2_temp1_data1;
	  end

	read_resp_st2_temp1_data1:	// This is state = 6; This state will return the lower 8 bits of the first data read (temp1) to the 						   output DataR of the NOC block.
	  begin
	    //n.CmdR		= 1'b0;    // not necessary
	    n.DataR		= temp1[7:0];

	    next_state_2	= read_resp_st2_temp1_data2;
	  end

	read_resp_st2_temp1_data2:	// This is state = 7;
	  begin
	    //n.CmdR		= 1'b0;	   // not necessary
	    n.DataR		= temp1[15:8];

	    next_state_2	= read_resp_st2_temp1_data3;
	  end

	read_resp_st2_temp1_data3:	// This is state = 8;
	  begin
	    //n.CmdR		= 1'b0;   // not necessary
	    n.DataR		= temp1[23:16];

	    next_state_2	= read_resp_st2_temp1_data4;
	  end

	read_resp_st2_temp1_data4:	// This is state = 9;
	  begin
	    //n.CmdR		= 1'b0;	  // not necessary
	    n.DataR		= temp1[31:24];

	    if(length_2 == 8'h04)  next_state_2 =  end_command;	// This mean that all the data of temp1 register has been read.
	    else
	      begin
		next_state_2	= read_resp_st2_temp2_data1;	// This means that after reading temp1 it will read temp2 reg content.
	      end
	  end

	read_resp_st2_temp2_data1:	// This is state = 10;
	  begin
	    //n.CmdR		= 1'b0;	// not necessary
	    n.DataR		= temp2[7:0];

	    next_state_2	= read_resp_st2_temp2_data2;
	  end

	read_resp_st2_temp2_data2:	// This is state = 11;
	  begin
	    //n.CmdR		= 1'b0;	// not necessary
	    n.DataR		= temp2[15:8];

	    next_state_2	= read_resp_st2_temp2_data3;
	  end

	read_resp_st2_temp2_data3:	// This is state = 12;
	  begin
	    //n.CmdR		= 1'b0;	// not necessary
	    n.DataR		= temp2[23:16];

	    next_state_2	= read_resp_st2_temp2_data4;
	  end

	read_resp_st2_temp2_data4:	// This is state = 13;
	  begin
	    //n.CmdR		= 1'b0;	// not necessary
	    n.DataR		= temp2[31:24];

	    if(length_2 == 8'h08)  next_state_2 =  end_command;	// This mean that all the data of temp2 register has been read.
	    else
	      begin
		next_state_2	= read_resp_st2_temp3_data1;	// This means that after reading temp2 it will read temp3 reg content.
	      end
	  end

	read_resp_st2_temp3_data1:	// This is state = 14;
	  begin
	    //n.CmdR		= 1'b0;	// not necessary
	    n.DataR		= temp3[7:0];

	    next_state_2	= read_resp_st2_temp3_data2;
	  end

	read_resp_st2_temp3_data2:	// This is state = 15;
	  begin
	    //n.CmdR		= 1'b0;	// not necessary
	    n.DataR		= temp3[15:8];

	    next_state_2	= read_resp_st2_temp3_data3;
	  end

	read_resp_st2_temp3_data3:	// This is state = 16;
	  begin
	    //n.CmdR		= 1'b0;	// not necessary
	    n.DataR		= temp3[23:16];

	    next_state_2	= read_resp_st2_temp3_data4;
	  end

	read_resp_st2_temp3_data4:	// This is state = 17;
	  begin
	    //n.CmdR		= 1'b0;	// not necessary
	    n.DataR		= temp3[31:24];

	    //next_state_2	= idle_st_2;
	    next_state_2	= end_command;
	  end

	end_command:    		// This is state = 18;
	  begin
	    //c.Sel		= 0; 
	    n.CmdR		= 1'b1;
	    n.DataR		= 8'b11100000;    //=E0

	    next_state_2	= idle_st_2;
	  end

	write_st_2:			// This is state = 19; This state is for writing data and address into the CRC block from state machine -2 
  	  begin
	    pop		   = 0; 
	    c.addr	   = addr_2_flop;
	    c.RW	   = 1;
	    c.Sel	   = 1;
	    c.data_wr	   = data_2;

	    next_state_2   = write_resp_st2_code;
	  end

	write_resp_st2_code:		// This is state = 20;
	  begin
	    c.Sel	   	= 0;
	    c.RW 	   	= 0;

	    n.CmdR  		= 1'b1;
	    n.DataR 		= 8'h80;

	    next_state_2	= write_resp_st2_returnid;
	  end

	write_resp_st2_returnid:	// This is state = 21;
	  begin
	    n.CmdR 		= 1'b0;
	    n.DataR		= return_id_2;
	
	    next_state_2	= idle_st_2;
	  end

      endcase
    end

endmodule

//****************************Code for NOC ends here*********************
