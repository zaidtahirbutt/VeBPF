module ram64_memory_v3(wr_address, rd_address, data_in, data_out, write_enable, rd_enable, clk, rst);

	// this version of ram64 memory will instantiate pgm memory as BRAM and will introduce 1 clk delay in instruction fetch cycle for VeBPF cpu.v

	parameter DATA_SIZE = 64; 
	parameter ADDRESS_SIZE = 12;
	parameter MEMORY_DEPTH = 2**ADDRESS_SIZE;  // 2**12 = 4096 // do not specify this when using module
	// parameter MEMORY_DEPTH = 20;  // pgm module taking too many LUTs... probably will need to convert mem to BRAM later.. for testing VeBPF right now limiting pgm memory depth to 20 
	parameter SIMULATION = 0;
	parameter VEBPF_SIM = 0;
	// `define DUMP_DEPTH 100
	 
	input [ADDRESS_SIZE-1:0] wr_address;
	input [ADDRESS_SIZE-1:0] rd_address;
	input [DATA_SIZE-1:0] data_in;
	output reg [DATA_SIZE-1:0] data_out;
	input write_enable;
	input rd_enable;
	input clk;
	input rst;

	// looks fine..
	// Addressing is in terms of 64 bit words cx cpu has 64 bit instruction set 
	  // much more detailed comments in ram64.py
	 
	// this statment below infers a BRAM
	(* ramstyle = "no_rw_check" *)
	reg [DATA_SIZE-1:0] mem [0:MEMORY_DEPTH-1];

	// assign data_out = mem [address];

	// Uncomment below for DISL simulation vs comment it out for automated testing of VeBPF cpu.v
	integer i;

	initial begin 
		
		if(SIMULATION || VEBPF_SIM) begin
			for(i = 0; i < MEMORY_DEPTH; i = i + 1) begin
				mem[i] <= 0;
			end
		end

	end


	// Uncomment below for DISL simulation vs comment it out for automated testing of VeBPF cpu.v
	integer idx3;

	initial begin
		if (SIMULATION) begin
			// #20
			$dumpfile("top.fst");
			// for (idx = 0; idx < `DUMP_DEPTH; idx = idx + 1) begin
			for (idx3 = 0; idx3 < 128; idx3 = idx3 + 1) begin
				$dumpvars(0, mem[idx3]); // dumping mem data into the output waveform
			end 
		end
	end

	always @(posedge clk) begin

		if (rst) begin

			// don't need to reset the memories to 0, it causes extra hardware to be used when this loop is unrolled. This initializing to 0
			// of memories was causing synthesis errors due to a lot of extra connections to initialize all memory bins to 0 upon reset, this
			// was causing wires/nets to jumble-up and all these extra connections made it impossible to synthesize the memories in network subsystem

			// if (!SIMULATION) begin
			// 	// generate
			// 		// genvar i;
			// 		// integer i;
			// 		// commenting this out for simulation.. later replace it with generate if not simulation
			// 		for (i = 0; i < MEMORY_DEPTH; i = i + 1) begin
						
			// 			mem[i] <= 0;

			// 		end
			// 	// endgenerate
			// end

		end else begin

			// case (write_enable)
			// 	1: mem [address] <= data_in;
			// endcase

			if (write_enable) begin 

				mem[wr_address] <= data_in;

			end

			if (rd_enable) begin
				
				data_out <= mem[rd_address];

			end

		end 

	end
	

	// integer idx;
	  
	// initial begin
	    
	  // // #20
	  // $dumpfile("pgm.fst");
	  // // for (idx = 0; idx < `DUMP_DEPTH; idx = idx + 1) begin
	  // for (idx = 0; idx < 8; idx = idx + 1) begin
	  //   $dumpvars(0, mem[idx]); 
	  // end
	    
	  
	    // data[0] = 32'hdead_dead;
	    // data[1] = 32'hbeef_beef;
	    
	    // #10;
	    
	    // data[0] = 32'hcccc_cccc;
	    // data[1] = 32'haaaa_aaaa;
	    
	    // #10 $finish;
	// end

	// testing
	// MSB                                                        LSB
    // | Byte 8 | Byte 7  | Byte 5-6       | Byte 1-4               |
    // +--------+----+----+----------------+------------------------+
    // |opcode  | src| dst|          offset|               immediate|
    // +--------+----+----+----------------+------------------------+
    // 63     56   52   48               32                        0
    
	initial begin
    
  	// THESE instructions below seem to be faulty.. testing new ones below this
	    // // jeq-imm_z1.test (editedZ)
	    // // mov32 r6, 0
	    // mem [0] = {8'hb4, 8'h08, 16'h0000, 32'h00000000};
	    // // mov32 r7, 0xa
	    // mem [1] = {8'hb4, 8'h07, 16'h0000, 32'h0000000a};
	    // // jeq r7, 0xb, +4 # Not taken
	    // mem [2] = {8'h15, 8'h07, 16'h0004, 32'h0000000b};
	    // // mov32 r6, 0
	    // mem [3] = {8'hb4, 8'h08, 16'h0000, 32'h00000000};
	    // // mov32 r7, 0xb
	    // mem [4] = {8'hb4, 8'h07, 16'h0000, 32'h0000000b};
	    
	    // // jeq r7, 0xb, +1 # Taken
	    // 	// this machine inst will skip the // mov32 r6, 2 and // exit instructions
	    // // mem [5] = {8'h15, 8'h77, 16'h0001, 32'h0000000b};

	    // // jeq r7, 0xb, +0 # Taken 
	    // 	// this machine inst will skip the // mov32 r6, 2 instruction
	    // mem [5] = {8'h15, 8'h77, 16'h0000, 32'h0000000b};
	    
	    // // mov32 r6, 2 # Skipped
	    // mem [6] = {8'hb4, 8'h08, 16'h0000, 32'h00000002};
	    // // exit
	    // mem [7] = {8'h95, 8'h00, 16'h0000, 32'h00000000}; 

	    // // exit AGAIN
	    // // mem [8] = {8'h95, 8'h00, 16'h0000, 32'h00000000}; 

	    // // zero  // halt becomes 1 here
	    // mem [9] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	    // // zero for idx 8  // hlat is still 0
	    // // mem [8] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	  // ***************************  START data5_DISL_eBPF_test1 *******************************************************
	  // // version-2  
	  // // jeq-imm_z1.test (editedZ)
	  // // mov32 r6, 0
	  // mem [0] = {8'hb4, 8'h06, 16'h0000, 32'h00000000};
	  // // mov32 r7, 0xa
	  // mem [1] = {8'hb4, 8'h07, 16'h0000, 32'h0000000a};
	  // // jeq r7, 0xb, +4 # Not taken  : 0x150704000b000000
	  // mem [2] = {8'h15, 8'h07, 16'h0004, 32'h0000000b};
	  // // mov32 r6, 0
	  // mem [3] = {8'hb4, 8'h06, 16'h0000, 32'h00000000};  // was an error here dstreg was 0x8
	  // // mov32 r7, 0xb
	  // mem [4] = {8'hb4, 8'h07, 16'h0000, 32'h0000000b};
	  
	  // // jeq r7, 0xb, +1 # Taken
	  // 	// this machine inst is skipping the // mov32 r6, 2 and // exit instructions
	  // // mem [5] = {8'h15, 8'h77, 16'h0001, 32'h0000000b};

	  // // jeq r7, 0xb, +0 # Taken 
	  // 	// this machine inst is skipping the // mov32 r6, 2 instruction
	  // mem [5] = {8'h15, 8'h07, 16'h0000, 32'h0000000b};  // was error here.. src reg should be 0, it was 0x7
	  
	  // // mov32 r6, 2 # Skipped
	  // mem [6] = {8'hb4, 8'h06, 16'h0000, 32'h00000002};  // was error here.. des reg should 0x6, was 0x8 
	  // // exit
	  // mem [7] = {8'h95, 8'h00, 16'h0000, 32'h00000000}; 

	  // // exit AGAIN
	  // // mem [8] = {8'h95, 8'h00, 16'h0000, 32'h00000000}; 

	  // // zero  // halt becomes 1 here
	  // mem [8] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 
	  // mem [9] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	  // // zero for idx 8  // hlat is still 0
	  // // mem [8] = {8'h00, 8'h00, 16'h0000, 32'h00000000};

	  // *************************** END data5_DISL_eBPF_test1 *******************************************************

	  // // ***************************  START data6_DISL_eBPF_test2 *******************************************************

	  // mem [0] = {8'hb4, 8'h00, 16'h0000, 32'h00000000};

	  // mem [1] = {8'hb4, 8'h01, 16'h0000, 32'h0000000a};

	  // mem [2] = {8'h35, 8'h01, 16'h0004, 32'h0000000b};

	  // mem [3] = {8'hb4, 8'h00, 16'h0000, 32'h00000001};  

	  // mem [4] = {8'hb4, 8'h01, 16'h0000, 32'h0000000c};
	  
	  // mem [5] = {8'h35, 8'h01, 16'h0001, 32'h0000000b};  

	  // mem [6] = {8'hb4, 8'h00, 16'h0000, 32'h00000002}; 

	  // mem [7] = {8'h95, 8'h00, 16'h0000, 32'h00000000}; 

	  // mem [8] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	  // mem [9] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 


	  // // *************************** END data6_DISL_eBPF_test2 *******************************************************

	  // // ***************************  START data3 *******************************************************

	  // 	// testing
	// 	// MSB                                                        LSB
	  //   // | Byte 8 | Byte 7  | Byte 5-6       | Byte 1-4               |  // these bytes are for the compiled code I believe .. in the hex file
	  //   // +--------+----+----+----------------+------------------------+
	  //   // |opcode  | src| dst|          offset|               immediate|
	  //   // +--------+----+----+----------------+------------------------+
	  //   // 63     56   52   48               32                        0
	    

	// 	// --asm 
	// 		// stdw [r1+2], 0x44332211
	// 	// hex
	// 		// 0x7a01020011223344
	// 	mem [0] = {8'h7a, 8'h01, 16'h0002, 32'h44332211};  // byte 1 - 4 means these bytes are flipped: L.E => 11223344 becomes -> 44332211 // same for other instruction op codes

	// 	// asm
	// 		// ldxdw r0, [r1+2]
	// 	// hex
	// 		// 0x7910020000000000
	// 	mem [1] = {8'h79, 8'h10, 16'h0002, 32'h00000000};

	// 	// asm
	// 		// exit
	// 	// hex
	// 		// 0x9500000000000000
	// 	mem [2] = {8'h95, 8'h00, 16'h0000, 32'h00000000}; 

	// 	mem [3] = {8'h00, 8'h00, 16'h0000, 32'h00000000};   

	// 	mem [4] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	mem [5] = {8'h00, 8'h00, 16'h0000, 32'h00000000};   

	// 	mem [6] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	mem [7] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	mem [8] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	mem [9] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 


	  // // *************************** END data6_DISL_eBPF_test2 *******************************************************

	  // // ***************************  START data7_DISL_eBPF_test3 neg64.test *******************************************************
	  // 	// *************************** PASSED ******************************************************

	  // 	// testing
	// 	// MSB                                                        LSB
	  //   // | Byte 8 | Byte 7  | Byte 5-6       | Byte 1-4               |  // these bytes are for the compiled code I believe .. in the hex file
	  //   // +--------+----+----+----------------+------------------------+
	  //   // |opcode  | src| dst|          offset|               immediate|
	  //   // +--------+----+----+----------------+------------------------+
	  //   // 63     56   52   48               32                        0
	    

	// 	// --asm 
	// 		// mov32 r0, 2
	// 	// hex
	// 		// 0xb400000002000000
	// 	mem [0] = {8'hb4, 8'h00, 16'h0000, 32'h00000002};  // byte 1 - 4 means these bytes are flipped: L.E => 11223344 becomes -> 44332211 // same for other instruction op codes

	// 	// asm
	// 		// neg r0
	// 	// hex
	// 		// 0x8700000000000000
	// 	mem [1] = {8'h87, 8'h00, 16'h0000, 32'h00000000};

	// 	// asm
	// 		// exit
	// 	// hex
	// 		// 0x9500000000000000
	// 	mem [2] = {8'h95, 8'h00, 16'h0000, 32'h00000000}; 

	// 	mem [3] = {8'h00, 8'h00, 16'h0000, 32'h00000000};   

	// 	mem [4] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	mem [5] = {8'h00, 8'h00, 16'h0000, 32'h00000000};   

	// 	mem [6] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	mem [7] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	mem [8] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	mem [9] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 


	// // *************************** END data7_DISL_eBPF_test3 neg64.test *******************************************************

	// // ***************************  START data7_DISL_eBPF_test3 mod64.test *******************************************************
	// 	// *************************** PASSED ******************************************************

	// 	// testing
	// 	// MSB                                                        LSB
	//   // | Byte 8 | Byte 7  | Byte 5-6       | Byte 1-4               |  // these bytes are for the compiled code I believe .. in the hex file
	//   // +--------+----+----+----------------+------------------------+
	//   // |opcode  | src| dst|          offset|               immediate|
	//   // +--------+----+----+----------------+------------------------+
	//   // 63     56   52   48               32                        0
	  

	// 	// --asm 
	// 		// mov32 r0, 0xb1858436
	// 	// hex
	// 		// 0xb4000000368485b1
	// 		// 0xb4 00 0000 368485b1
	// 	mem [0] = {8'hb4, 8'h00, 16'h0000, 32'hb1858436};  // byte 1 - 4 means these bytes are flipped: L.E => 11223344 becomes -> 44332211 // same for other instruction op codes

	// 	// asm
	// 		// lsh r0, 32
	// 	// hex
	// 		// 0x6700000020000000
	// 		// 0x67 00 0000 20000000
	// 	mem [1] = {8'h67, 8'h00, 16'h0000, 32'h00000020};

	// 	// asm
	// 		// or r0, 0x100dc5c8
	// 	// hex
	// 		// 0x47000000c8c50d10
	// 		// 0x47 00 0000 c8c50d10
	// 	mem [2] = {8'h47, 8'h00, 16'h0000, 32'h100dc5c8}; 

	// 	// asm
	// 		// mov32 r1, 0xdde263e
	// 	// hex
	// 		// 0xb40100003e26de0d
	// 		// 0xb4 01 0000 3e26de0d
	// 	mem [3] = {8'hb4, 8'h01, 16'h0000, 32'h0dde263e};   

	// 	// asm
	// 		// lsh r1, 32
	// 	// hex
	// 		// 0x6701000020000000
	// 		// 0x67 01 0000 20000000
	// 	mem [4] = {8'h67, 8'h01, 16'h0000, 32'h00000020}; 

	// 	// asm
	// 		// or r1, 0x3cbef7f3
	// 	// hex
	// 		// 0x47010000f3f7be3c
	// 		// 0x47 01 0000 f3f7be3c
	// 	mem [5] = {8'h47, 8'h01, 16'h0000, 32'h3cbef7f3};   

	// 	// asm
	// 		// mod r0, r1
	// 	// hex
	// 		// 0x9f10000000000000
	// 		// 0x9f 10 0000 00000000
	// 	mem [6] = {8'h9f, 8'h10, 16'h0000, 32'h00000000}; 


	// 	// asm
	// 		// mod r0, 0x658f1778
	// 	// hex
	// 		// 0x9700000078178f65
	// 		// 0x97 00 0000 78178f65
	// 	mem [7] = {8'h97, 8'h00, 16'h0000, 32'h658f1778};

	// 	// asm
	// 		// exit
	// 	// hex
	// 		// 0x9500000000000000
	// 		// 0x95 00 0000 00000000
	// 	mem [8] = {8'h95, 8'h00, 16'h0000, 32'h00000000}; 

	// 	mem [9] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	mem [10] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 


	// // *************************** END data7_DISL_eBPF_test3 mod64.test *******************************************************


	// // ***************************  START data7_DISL_eBPF_test3 div64-imm.test *******************************************************
	// 	// *************************** PASSED ******************************************************

	// 	// testing
	// 	// MSB                                                        LSB
	//   // | Byte 8 | Byte 7  | Byte 5-6       | Byte 1-4               |  // these bytes are for the compiled code I believe .. in the hex file
	//   // +--------+----+----+----------------+------------------------+
	//   // |opcode  | src| dst|          offset|               immediate|
	//   // +--------+----+----+----------------+------------------------+
	//   // 63     56   52   48               32                        0
	  

	// 	// --asm 
	// 		// mov r0, 0xc
	// 	// hex
	// 		// 0xb70000000c000000
	// 		// 0xb7 00 0000 0c000000
	// 	mem [0] = {8'hb7, 8'h00, 16'h0000, 32'h0000000c};  // byte 1 - 4 means these bytes are flipped: L.E => 11223344 becomes -> 44332211 // same for other instruction op codes

	// 	// asm
	// 		// lsh r0, 32
	// 	// hex
	// 		// 0x6700000020000000
	// 		// 0x67 00 0000 20000000
	// 	mem [1] = {8'h67, 8'h00, 16'h0000, 32'h00000020};

	// 	// asm
	// 		// div r0, 4
	// 	// hex
	// 		// 0x3700000004000000
	// 		// 0x37 00 0000 04000000
	// 	mem [2] = {8'h37, 8'h00, 16'h0000, 32'h00000004}; 

	// 	// asm
	// 		// exit
	// 	// hex
	// 		// 0x9500000000000000
	// 		// 0x95 00000000000000
	// 	mem [3] = {8'h95, 8'h00, 16'h0000, 32'h00000000};   

	// 	// asm
	// 		// 
	// 	// hex
	// 		// 
	// 		// 
	// 	mem [4] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	// asm
	// 		// 
	// 	// hex
	// 		// 
	// 		// 
	// 	mem [5] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	// asm
	// 		// 
	// 	// hex
	// 		// 
	// 		// 
	// 	mem [6] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 


	// 	// asm
	// 		// 
	// 	// hex
	// 		// 
	// 		// 
	// 	mem [7] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	// asm
	// 		// 
	// 	// hex
	// 		// 
	// 		// 
	// 	mem [8] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	mem [9] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	mem [10] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 


	// // *************************** END data7_DISL_eBPF_test3 div64-imm.test *******************************************************

	// // ***************************  START data7_DISL_eBPF_test3 mul32-reg-overflow.test *******************************************************
	// 	// *************************** PASSED ******************************************************

	// 	// testing
	// 	// MSB                                                        LSB
	//   // | Byte 8 | Byte 7  | Byte 5-6       | Byte 1-4               |  // these bytes are for the compiled code I believe .. in the hex file
	//   // +--------+----+----+----------------+------------------------+
	//   // |opcode  | src| dst|          offset|               immediate|
	//   // +--------+----+----+----------------+------------------------+
	//   // 63     56   52   48               32                        0
	  

	// 	// --asm 
	// 		// mov r0, 0x40000001
	// 	// hex
	// 		// 0xb700000001000040
	// 		// 0xb7 00 0000 01000040
	// 	mem [0] = {8'hb7, 8'h00, 16'h0000, 32'h40000001};  // byte 1 - 4 means these bytes are flipped: L.E => 11223344 becomes -> 44332211 // same for other instruction op codes

	// 	// asm
	// 		// mov r1, 4
	// 	// hex
	// 		// 0xb701000004000000
	// 		// 0xb7 01 0000 04000000
	// 	mem [1] = {8'hb7, 8'h01, 16'h0000, 32'h00000004};

	// 	// asm
	// 		// mul32 r0, r1
	// 	// hex
	// 		// 0x2c10000000000000
	// 		// 0x2c 10 0000 00000000
	// 	mem [2] = {8'h2c, 8'h10, 16'h0000, 32'h00000000}; 

	// 	// asm
	// 		// exit
	// 	// hex
	// 		// 0x9500000000000000
	// 		// 0x95 00000000000000
	// 	mem [3] = {8'h95, 8'h00, 16'h0000, 32'h00000000};   

	// 	// asm
	// 		// 
	// 	// hex
	// 		// 
	// 		// 
	// 	mem [4] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	// asm
	// 		// 
	// 	// hex
	// 		// 
	// 		// 
	// 	mem [5] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	// asm
	// 		// 
	// 	// hex
	// 		// 
	// 		// 
	// 	mem [6] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 


	// 	// asm
	// 		// 
	// 	// hex
	// 		// 
	// 		// 
	// 	mem [7] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	// asm
	// 		// 
	// 	// hex
	// 		// 
	// 		// 
	// 	mem [8] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	mem [9] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	mem [10] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 


	// // *************************** END data7_DISL_eBPF_test3 mul32-reg-overflow.test *******************************************************


	// // ***************************  START data7_DISL_eBPF_test3 err-endian-size.test *******************************************************
	// 	// *************************** PASSED ******************************************************

	// 	// testing
	// 	// MSB                                                        LSB
	//   // | Byte 8 | Byte 7  | Byte 5-6       | Byte 1-4               |  // these bytes are for the compiled code I believe .. in the hex file
	//   // +--------+----+----+----------------+------------------------+
	//   // |opcode  | src| dst|          offset|               immediate|
	//   // +--------+----+----+----------------+------------------------+
	//   // 63     56   52   48               32                        0
	  

	// 	// --raw 
	// 		// 0xdc01000030000000
	// 	// hex
	// 		// 0xdc01000030000000
	// 		// 0xdc 01 0000 30000000
	// 	mem [0] = {8'hdc, 8'h01, 16'h0000, 32'h00000030};  // byte 1 - 4 means these bytes are flipped: L.E => 11223344 becomes -> 44332211 // same for other instruction op codes

	// 	// raw
	// 		// 0xb710000000000000
	// 	// hex
	// 		// 0xb710000000000000
	// 		// 0xb7 10 0000 00000000
	// 	mem [1] = {8'hb7, 8'h10, 16'h0000, 32'h00000000};

	// 	// raw
	// 		// 0x9500000000000000
	// 	// hex
	// 		// 0x9500000000000000
	// 		// 0x9500000000000000
	// 	mem [2] = {8'h95, 8'h00, 16'h0000, 32'h00000000};

	// 	// asm
	// 		// 
	// 	// hex
	// 		// 
	// 		// 
	// 	mem [3] = {8'h00, 8'h00, 16'h0000, 32'h00000000};   

	// 	// asm
	// 		// 
	// 	// hex
	// 		// 
	// 		// 
	// 	mem [4] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	// asm
	// 		// 
	// 	// hex
	// 		// 
	// 		// 
	// 	mem [5] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	// asm
	// 		// 
	// 	// hex
	// 		// 
	// 		// 
	// 	mem [6] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 


	// 	// asm
	// 		// 
	// 	// hex
	// 		// 
	// 		// 
	// 	mem [7] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	// asm
	// 		// 
	// 	// hex
	// 		// 
	// 		// 
	// 	mem [8] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	mem [9] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	mem [10] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 


	// // *************************** END data7_DISL_eBPF_test3 err-endian-size.test *******************************************************

	// // ***************************  START data20_DISL_test1_RxPkt_Dest_MAC.test *******************************************************
	// 	// *************************** PASSED ******************************************************

	// 	// testing
	// 	// MSB                                                        LSB
	//   // | Byte 8 | Byte 7  | Byte 5-6       | Byte 1-4               |  // these bytes are for the compiled code I believe .. in the hex file
	//   // +--------+----+----+----------------+------------------------+
	//   // |opcode  | src| dst|          offset|               immediate|
	//   // +--------+----+----+----------------+------------------------+
	//   // 63     56   52   48               32                        0
	  

	// 	// --raw 
	// 		// 0xb702000002000000
	// 	// hex
	// 		// 0xb702000002000000
	// 		// 0xb7 02 0000 00000002
	// 	mem [0] = {8'hb7, 8'h02, 16'h0000, 32'h00000002};  // byte 1 - 4 means these bytes are flipped: L.E => 11223344 becomes -> 44332211 // same for other instruction op codes

	// 	// raw
	// 		// 0xb701000000000000
	// 	// hex
	// 		// 0xb701000000000000
	// 		// 0xb7 01 0000 00000000
	// 	mem [1] = {8'hb7, 8'h01, 16'h0000, 32'h00000000};

	// 	// raw
	// 		// 0x7914000000000000
	// 	// hex
	// 		// 0x7914000000000000
	// 		// 0x79 14 0000 00000000
	// 	mem [2] = {8'h79, 8'h14, 16'h0000, 32'h00000000};

	// 	// asm
	// 		// 0x57040000ffffffff
	// 	// hex 
	// 		// 0x57040000ffffffff
	// 		// 0x57 04 0000 ffffffff
	// 	mem [3] = {8'h57, 8'h04, 16'h0000, 32'hffffffff};   

	// 	// asm
	// 		// 
	// 	// hex
	// 		// 0x1d24020000000000
	// 		// 0x1d 24 0002 00000000
	// 	mem [4] = {8'h1d, 8'h24, 16'h0002, 32'h00000000}; 

	// 	// asm
	// 		// 
	// 	// hex
	// 		// 0xb700000001000000
	// 		// 0xb7 00 0000 00000001
	// 	mem [5] = {8'hb7, 8'h00, 16'h0000, 32'h00000001}; 

	// 	// asm
	// 		// 
	// 	// hex
	// 		// 0x9500000000000000
	// 		// 0x95 00 0000 00000000
	// 	mem [6] = {8'h95, 8'h00, 16'h0000, 32'h00000000}; 


	// 	// asm
	// 		// 
	// 	// hex
	// 		// 0xbf40000000000000
	// 		// 0xbf 40 0000 00000000
	// 	mem [7] = {8'hbf, 8'h40, 16'h0000, 32'h00000000}; 

	// 	// asm
	// 		// 
	// 	// hex
	// 		// 0x9500000000000000
	// 		// 0x95 00 0000 00000000
	// 	mem [8] = {8'h95, 8'h00, 16'h0000, 32'h00000000}; 

	// 	mem [9] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 

	// 	mem [10] = {8'h00, 8'h00, 16'h0000, 32'h00000000}; 


	// // *************************** END data20_DISL_test1_RxPkt_Dest_MAC.test *******************************************************

  end


endmodule