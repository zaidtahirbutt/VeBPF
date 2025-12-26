	/* Machine-generated using Migen */
module ram_module_v3 #(

	parameter DATA_SIZE = 64,
	parameter ADDRESS_SIZE = 11,
	parameter SIMULATION = 0,
	parameter VEBPF_SIM = 0,
	parameter MEMORY_DEPTH = 2**ADDRESS_SIZE  // 2^11 = 2048 // do not specify this when using module



	)
	
	(
	input clk,
	input rst,

	// address input (read or write)  // by default this module is WRITE_FIRST: the written value is returned. 
	input [ADDRESS_SIZE-1:0] adr1,
	// input strobe for data fetch (or data write), needs to be high for operation
	input stb,

	// output ack req for both read and write operation (this could be optimized for read and write ops having separate acks)
		// for write the fsm goes to write then to read and then ack goes 1.. the fsm shouldnt go to the read part when the
		// function is purely write
			// The above problem has been solved and fsm reads only for read ops and writes only for write ops
	output reg ack,

	// input 64 bit write data bus to this mem  
	input [DATA_SIZE-1:0] dat_w0,

	// input word width? (1 byte word).. 1 for 1 byte being written to this ram,, 8 for 8 bytes being written to this ram
	input [3:0] ww,
		// okay so ww is for write memory operations only... read operations read the full DW.

	// input write enable ... the other internal write enable is used to tell the fsm what write enable is AND to enable the fsm to change that write enable
	input we0,

	// Data read outputs (1 byte r0, halfword r2, word r4, DW r8)
	output reg [7:0] dat_r0,
	output reg [15:0] dat_r2,
	output reg [31:0] dat_r4,
	output reg [63:0] dat_r8
);


// reg stb = 1'd0;

// reg ack = 1'd0;

// reg [7:0] dat_r0 = 8'd0;
// reg [15:0] dat_r2 = 16'd0;
// reg [31:0] dat_r4 = 32'd0;
// reg [63:0] dat_r8 = 64'd0;

// reg we0 = 1'd0;
// reg [3:0] ww = 4'd0;

// reg [63:0] dat_w0 = 64'd0;

reg [3:0] wcnt = 4'd0;
reg [1:0] wait_1 = 2'd0;

// internal read/write address
reg [10:0] adr0 = 11'd0;

// changing to reg for ram_module_v3
reg [7:0] dat_r1;
// wire [7:0] dat_r1;

// internal write enable
reg we1 = 1'd0;

// as name suggests
reg write_complete_flag = 0;

reg [7:0] dat_w1 = 8'd0;

// reg [10:0] adr1 = 11'd0;

// internal input address
reg [10:0] addr_t = 11'd0;

// Uncomment below for DISL simulation vs comment it out for automated testing of VeBPF cpu.v
integer idx2;
integer idx_data_mem;
	 
initial begin
	
	if (SIMULATION) begin  
	 	// #20
	 	$dumpfile("top.fst");
	 	// for (idx = 0; idx < `DUMP_DEPTH; idx = idx + 1) begin
		for (idx2 = 0; idx2 < MEMORY_DEPTH; idx2 = idx2 + 1) begin
			$dumpvars(0, mem[idx2]); // dumping mem data into the output waveform
		end
	end

	if(SIMULATION || VEBPF_SIM) begin
		for(idx_data_mem = 0; idx_data_mem < MEMORY_DEPTH; idx_data_mem = idx_data_mem + 1) begin
			mem[idx_data_mem] <= 0;
		end
	end

 end


// https://m-labs.hk/migen/manual/fhdl.html
	// READ_FIRST: during a write, the previous value is read.
	// WRITE_FIRST: the written value is returned.
	// NO_CHANGE: the data read signal keeps its previous value on a write.
		// so this fsm provides the read value after write value is written..
		// extra clk cycles are used 
always @(posedge clk) begin
	if (rst) begin

		ack <= 1'd0;
		dat_r0 <= 8'd0;
		dat_r2 <= 16'd0;
		dat_r4 <= 32'd0;
		dat_r8 <= 64'd0;
		// we0 <= 1'd0;
		wcnt <= 4'd0;
		wait_1 <= 2'd0;
		adr0 <= 11'd0;
		we1 <= 1'd0;
		dat_w1 <= 8'd0;
		addr_t <= 11'd0;
		write_complete_flag <= 0;

	end else if (stb) begin
		// if (we0) begin
		if (we0 & (!write_complete_flag)) begin  // writing FSM
			if ((wcnt == 1'd0)) begin  // 2 clk c
				wcnt <= 1'd1;
				addr_t <= adr1;
			end else begin
				adr0 <= addr_t;
				we1 <= 1'd1;
				case (wcnt)  // writing byte by byte
					1'd1: begin
						dat_w1 <= dat_w0[7:0];
					end
					2'd2: begin
						dat_w1 <= dat_w0[15:8];
					end
					2'd3: begin
						dat_w1 <= dat_w0[23:16];
					end
					3'd4: begin
						dat_w1 <= dat_w0[31:24];
					end
					3'd5: begin
						dat_w1 <= dat_w0[39:32];
					end
					3'd6: begin
						dat_w1 <= dat_w0[47:40];
					end
					3'd7: begin
						dat_w1 <= dat_w0[55:48];
					end
					4'd8: begin
						dat_w1 <= dat_w0[63:56];
					end
					default: begin
					end
				endcase
				if ((ww != wcnt)) begin
					addr_t <= (addr_t + 1'd1);
					wcnt <= (wcnt + 1'd1);
					write_complete_flag <= 0;
				end else begin
					// we0 <= 1'd0;
					wcnt <= 1'd0;
					write_complete_flag <= 1;
					ack <= 1'd1;  // uncommented this for v2
						// uncommment this for more optimized writing
				end
			end
		end else begin  // use of write_complete_flag cx if it wasnt present in the if statement and while writing we stayed 1, it wouldnot have entered the else condition to make ack 1
			we1 <= 1'd0;  
			adr0 <= adr1;
			// write_complete_flag <= 0;  // error, caused a forever loop added
			if ((~ack)) begin
				if ((wcnt == 1'd0)) begin
					wcnt <= 1'd1;
					wait_1 <= 1'd1;
				end else begin
					if (wait_1) begin
						wait_1 <= 1'd0;
						adr0 <= (adr0 + 1'd1);
					end else begin
						case (wcnt)
							1'd1: begin
								dat_r0 <= dat_r1;
								dat_r2 <= dat_r1;
								dat_r4 <= dat_r1;
								dat_r8 <= dat_r1;
							end
							2'd2: begin
								dat_r2[15:8] <= dat_r1;
								dat_r4[15:8] <= dat_r1;
								dat_r8[15:8] <= dat_r1;
							end
							2'd3: begin
								dat_r4[23:16] <= dat_r1;
								dat_r8[23:16] <= dat_r1;
							end
							3'd4: begin
								dat_r4[31:24] <= dat_r1;
								dat_r8[31:24] <= dat_r1;
							end
							3'd5: begin
								dat_r8[39:32] <= dat_r1;
							end
							3'd6: begin
								dat_r8[47:40] <= dat_r1;
							end
							3'd7: begin
								dat_r8[55:48] <= dat_r1;
							end
							4'd8: begin
								dat_r8[63:56] <= dat_r1;
							end
							default: begin
							end
						endcase
						if ((wcnt != 4'd8)) begin
							adr0 <= (adr0 + 1'd1);
							wcnt <= (wcnt + 1'd1);
						end else begin
							ack <= 1'd1;  // ack returned for read and write here
						end
					end
				end
			end
		end
	end else begin
		ack <= 1'd0;
		wait_1 <= 1'd1;
		wcnt <= 1'd0;
		write_complete_flag <= 0;  // added
	end
	// if (rst) begin
	// 	ack <= 1'd0;
	// 	dat_r0 <= 8'd0;
	// 	dat_r2 <= 16'd0;
	// 	dat_r4 <= 32'd0;
	// 	dat_r8 <= 64'd0;
	// 	// we0 <= 1'd0;
	// 	wcnt <= 4'd0;
	// 	wait_1 <= 2'd0;
	// 	adr0 <= 11'd0;
	// 	we1 <= 1'd0;
	// 	dat_w1 <= 8'd0;
	// 	addr_t <= 11'd0;
	// 	write_complete_flag <= 0;
	// end
end

reg [7:0] mem[0:MEMORY_DEPTH-1];
// reg [7:0] mem[0:2047];

reg [10:0] memadr;

integer i;

always @(posedge clk) begin
	if (rst) begin

		memadr <= 0;

	end else begin

		// Memory writing
		if (we1)
			mem[adr0] <= dat_w1;
		
		// memadr <= adr0;

		// Memory reading
		// 1 clk delay of memadr has been replaced with 1 clk delay of synchronous memory reading
		// hopefully now the mem will be instantiated as BRAM
		dat_r1 <= mem[adr0];
	end
end

endmodule
