`timescale 1 ns/10 ps

module cpu(clk, reset_n, csr_ctl, csr_status, r0, r1, r2, r3, r4, r5, r6, 
    r7, r8, r9, r10, ticks, data_mem_ack_output_port, 
    data_mem_write_64bit_input_port, data_mem_dataBytesWrittenWidth_ww_input_port,
    data_mem_we_input_port,data_mem_adr_input_port, data_mem_stb_input_port,
    halt, error,
    
    // VeBPF prog mem ports
    VeBPF_prog_addr_in,
    VeBPF_prog_data_in,
    VeBPF_prog_write_enable_in,
    VeBPF_prog_reset_in,              // separate reset for the prog mem of VeBPF
    // VeBPF_prog_busy_in,            // the progloader is busy writing to VeBPF prog mem
    // VeBPF_prog_done_in             // VeBPF prog has been completed 
    
    // Running next selected RULE
    run_next_selected_rule_en,        // en signal to run the next selected rule, will make this HIGH when halt = 1, ALSO need to assert reset to VeBPF core while selecting and enabling next rule
    ip_next_rule                      // instruction pointer for next selected rule

    );

// -------------Parameters----------------
parameter SIMULATION = 0;  // This is for DISL sim testing with VeBPF included
parameter VEBPF_SIM = 0; // This is for automatic sim testing of VeBPF CPU

parameter MAX_REGS = 11;
parameter MAX_PGM_WORDS = 4096;
parameter MAX_DATA_WORDS = 2048;
parameter MAX_STACK = 512;

// Max values for unsigned int
parameter MAX_UINT8  = 8'hff;
parameter MAX_UINT16 = 16'hffff;
parameter MAX_UINT32 = 32'hffffffff;
parameter MAX_UINT64 = 64'hffffffffffffffff;

// CPU States
parameter STATE_OP_FETCH = 0;
parameter STATE_OP_FETCH_DELAY = 6;  // 1 clk delay for fetching pgm memory
parameter STATE_DECODE = 1;
parameter STATE_DATA_FETCH = 2;
parameter STATE_DIV_PENDING = 3;
parameter STATE_CALL_PENDING = 4;
parameter STATE_HALT = 5;

//  +----------------+--------+--------------------+
//  |   4 bits       |  1 bit |   3 bits           |
//  | operation code | source | instruction class  |
//  +----------------+--------+--------------------+
//  (MSB)                                      (LSB)

// OpCode Classes
parameter OPC_LD    = 8'h00;    // load from immediate
parameter OPC_LDX   = 8'h01;    // load from register
parameter OPC_ST    = 8'h02;    // store immediate
parameter OPC_STX   = 8'h03;    // store value from register
parameter OPC_ALU   = 8'h04;    // 32 bits arithmetic operation
parameter OPC_JMP   = 8'h05;    // jump
parameter OPC_RES   = 8'h06;    // unused, reserved for future use
parameter OPC_ALU64 = 8'h07;    // 64 bits arithmetic operation

// Operation codes (OPC_ALU or OPC_ALU64).
parameter ALU_ADD  = 8'h00;     // addition
parameter ALU_SUB  = 8'h01;     // subtraction
parameter ALU_MUL  = 8'h02;     // multiplication
parameter ALU_DIV  = 8'h03;     // division
parameter ALU_OR   = 8'h04;     // or
parameter ALU_AND  = 8'h05;     // and
parameter ALU_LSH  = 8'h06;     // left shift
parameter ALU_RSH  = 8'h07;     // right shift
parameter ALU_NEG  = 8'h08;     // negation
parameter ALU_MOD  = 8'h09;     // modulus
parameter ALU_XOR  = 8'h0a;     // exclusive or
parameter ALU_MOV  = 8'h0b;     // move
parameter ALU_ARSH = 8'h0c;     // sign extending right shift
parameter ALU_ENDC = 8'h0d;     // endianess conversion

//  +--------+--------+-------------------+
//  | 3 bits | 2 bits |   3 bits          |
//  |  mode  |  size  | instruction class |
//  +--------+--------+-------------------+
//  (MSB)                             (LSB)

// Load/Store Modes
parameter LDST_IMM  = 8'h00;    // immediate value
parameter LDST_ABS  = 8'h01;    // absolute
parameter LDST_IND  = 8'h02;    // indirect
parameter LDST_MEM  = 8'h03;    // load from / store to memory
                   // 8'h04;    // reserved
                   // 8'h05;    // reserved
parameter LDST_XADD = 8'h06;    // exclusive add

// Sizes
parameter LEN_W   = 8'h00;      // word (4 bytes)
parameter LEN_H   = 8'h01;      // half-word (2 bytes)
parameter LEN_B   = 8'h02;      // byte (1 byte)
parameter LEN_DW  = 8'h03;      // double word (8 bytes)

parameter EBPF_SIZE_W    = LEN_W  << 3; // 0x00
parameter EBPF_SIZE_H    = LEN_H  << 3; // 0x08
parameter EBPF_SIZE_B    = LEN_B  << 3; // 0x10
parameter EBPF_SIZE_DW   = LEN_DW << 3; // 0x18

// Operation codes (OPC_JMP)
parameter JMP_JA   = 8'h00;     // jump
parameter JMP_JEQ  = 8'h01;     // jump if equal
parameter JMP_JGT  = 8'h02;     // jump if greater than
parameter JMP_JGE  = 8'h03;     // jump if greater or equal
parameter JMP_JSET = 8'h04;     // jump if `src`& `reg`
parameter JMP_JNE  = 8'h05;     // jump if not equal
parameter JMP_JSGT = 8'h06;     // jump if greater than (signed)
parameter JMP_JSGE = 8'h07;     // jump if greater or equal (signed)
parameter JMP_CALL = 8'h08;     // helper function call
parameter JMP_EXIT = 8'h09;     // return from program
parameter JMP_JLT  = 8'h0a;     // jump if lower than
parameter JMP_JLE  = 8'h0b;     // jump if lower ir equal
parameter JMP_JSLT = 8'h0c;     // jump if lower than (signed)
parameter JMP_JSLE = 8'h0d;     // jump if lower or equal (signed)

// Sources
parameter JMP_K    = 8'h00;     // 32-bit immediate value
parameter JMP_X    = 8'h01;     // `src` register

parameter EBPF_SRC_IMM       = 8'h00;
parameter EBPF_SRC_REG       = 8'h08;

parameter EBPF_MODE_IMM      = 8'h00;
parameter EBPF_MODE_MEM      = 8'h60;

parameter EBPF_OP_ADD        = ALU_ADD << 4;
parameter EBPF_OP_SUB        = ALU_SUB << 4;
parameter EBPF_OP_MUL        = ALU_MUL << 4;
parameter EBPF_OP_DIV        = ALU_DIV << 4;
parameter EBPF_OP_OR         = ALU_OR << 4;
parameter EBPF_OP_AND        = ALU_AND << 4;
parameter EBPF_OP_LSH        = ALU_LSH << 4;
parameter EBPF_OP_RSH        = ALU_RSH << 4;
parameter EBPF_OP_MOD        = ALU_MOD << 4;
parameter EBPF_OP_XOR        = ALU_XOR << 4;
parameter EBPF_OP_MOV        = ALU_MOV << 4;
parameter EBPF_OP_ARSH       = ALU_ARSH << 4;

parameter EBPF_OP_ADD_IMM    = (OPC_ALU|EBPF_SRC_IMM|EBPF_OP_ADD);
parameter EBPF_OP_ADD_REG    = (OPC_ALU|EBPF_SRC_REG|EBPF_OP_ADD);
parameter EBPF_OP_SUB_IMM    = (OPC_ALU|EBPF_SRC_IMM|EBPF_OP_SUB);
parameter EBPF_OP_SUB_REG    = (OPC_ALU|EBPF_SRC_REG|EBPF_OP_SUB);
parameter EBPF_OP_MUL_IMM    = (OPC_ALU|EBPF_SRC_IMM|EBPF_OP_MUL);
parameter EBPF_OP_MUL_REG    = (OPC_ALU|EBPF_SRC_REG|EBPF_OP_MUL);
parameter EBPF_OP_DIV_IMM    = (OPC_ALU|EBPF_SRC_IMM|EBPF_OP_DIV);
parameter EBPF_OP_DIV_REG    = (OPC_ALU|EBPF_SRC_REG|EBPF_OP_DIV);
parameter EBPF_OP_OR_IMM     = (OPC_ALU|EBPF_SRC_IMM|EBPF_OP_OR);
parameter EBPF_OP_OR_REG     = (OPC_ALU|EBPF_SRC_REG|EBPF_OP_OR);
parameter EBPF_OP_AND_IMM    = (OPC_ALU|EBPF_SRC_IMM|EBPF_OP_AND);
parameter EBPF_OP_AND_REG    = (OPC_ALU|EBPF_SRC_REG|EBPF_OP_AND);
parameter EBPF_OP_LSH_IMM    = (OPC_ALU|EBPF_SRC_IMM|EBPF_OP_LSH);
parameter EBPF_OP_LSH_REG    = (OPC_ALU|EBPF_SRC_REG|EBPF_OP_LSH);
parameter EBPF_OP_RSH_IMM    = (OPC_ALU|EBPF_SRC_IMM|EBPF_OP_RSH);
parameter EBPF_OP_RSH_REG    = (OPC_ALU|EBPF_SRC_REG|EBPF_OP_RSH);
parameter EBPF_OP_NEG        = (OPC_ALU|8'h80);
parameter EBPF_OP_MOD_IMM    = (OPC_ALU|EBPF_SRC_IMM|EBPF_OP_MOD);
parameter EBPF_OP_MOD_REG    = (OPC_ALU|EBPF_SRC_REG|EBPF_OP_MOD);
parameter EBPF_OP_XOR_IMM    = (OPC_ALU|EBPF_SRC_IMM|EBPF_OP_XOR);
parameter EBPF_OP_XOR_REG    = (OPC_ALU|EBPF_SRC_REG|EBPF_OP_XOR);
parameter EBPF_OP_MOV_IMM    = (OPC_ALU|EBPF_SRC_IMM|EBPF_OP_MOV);
parameter EBPF_OP_MOV_REG    = (OPC_ALU|EBPF_SRC_REG|EBPF_OP_MOV);
parameter EBPF_OP_ARSH_IMM   = (OPC_ALU|EBPF_SRC_IMM|EBPF_OP_ARSH);
parameter EBPF_OP_ARSH_REG   = (OPC_ALU|EBPF_SRC_REG|EBPF_OP_ARSH);
parameter EBPF_OP_LE         = (OPC_ALU|EBPF_SRC_IMM|8'hd0);
parameter EBPF_OP_BE         = (OPC_ALU|EBPF_SRC_REG|8'hd0);

parameter EBPF_OP_ADD64_IMM  = (OPC_ALU64|EBPF_SRC_IMM|EBPF_OP_ADD);
parameter EBPF_OP_ADD64_REG  = (OPC_ALU64|EBPF_SRC_REG|EBPF_OP_ADD);
parameter EBPF_OP_SUB64_IMM  = (OPC_ALU64|EBPF_SRC_IMM|EBPF_OP_SUB);
parameter EBPF_OP_SUB64_REG  = (OPC_ALU64|EBPF_SRC_REG|EBPF_OP_SUB);
parameter EBPF_OP_MUL64_IMM  = (OPC_ALU64|EBPF_SRC_IMM|EBPF_OP_MUL);
parameter EBPF_OP_MUL64_REG  = (OPC_ALU64|EBPF_SRC_REG|EBPF_OP_MUL);
parameter EBPF_OP_DIV64_IMM  = (OPC_ALU64|EBPF_SRC_IMM|EBPF_OP_DIV);
parameter EBPF_OP_DIV64_REG  = (OPC_ALU64|EBPF_SRC_REG|EBPF_OP_DIV);
parameter EBPF_OP_OR64_IMM   = (OPC_ALU64|EBPF_SRC_IMM|EBPF_OP_OR);
parameter EBPF_OP_OR64_REG   = (OPC_ALU64|EBPF_SRC_REG|EBPF_OP_OR);
parameter EBPF_OP_AND64_IMM  = (OPC_ALU64|EBPF_SRC_IMM|EBPF_OP_AND);
parameter EBPF_OP_AND64_REG  = (OPC_ALU64|EBPF_SRC_REG|EBPF_OP_AND);
parameter EBPF_OP_LSH64_IMM  = (OPC_ALU64|EBPF_SRC_IMM|EBPF_OP_LSH);
parameter EBPF_OP_LSH64_REG  = (OPC_ALU64|EBPF_SRC_REG|EBPF_OP_LSH);
parameter EBPF_OP_RSH64_IMM  = (OPC_ALU64|EBPF_SRC_IMM|EBPF_OP_RSH);
parameter EBPF_OP_RSH64_REG  = (OPC_ALU64|EBPF_SRC_REG|EBPF_OP_RSH);
parameter EBPF_OP_NEG64      = (OPC_ALU64|8'h80);
parameter EBPF_OP_MOD64_IMM  = (OPC_ALU64|EBPF_SRC_IMM|EBPF_OP_MOD);
parameter EBPF_OP_MOD64_REG  = (OPC_ALU64|EBPF_SRC_REG|EBPF_OP_MOD);
parameter EBPF_OP_XOR64_IMM  = (OPC_ALU64|EBPF_SRC_IMM|EBPF_OP_XOR);
parameter EBPF_OP_XOR64_REG  = (OPC_ALU64|EBPF_SRC_REG|EBPF_OP_XOR);
parameter EBPF_OP_MOV64_IMM  = (OPC_ALU64|EBPF_SRC_IMM|EBPF_OP_MOV);
parameter EBPF_OP_MOV64_REG  = (OPC_ALU64|EBPF_SRC_REG|EBPF_OP_MOV);
parameter EBPF_OP_ARSH64_IMM = (OPC_ALU64|EBPF_SRC_IMM|EBPF_OP_ARSH);
parameter EBPF_OP_ARSH64_REG = (OPC_ALU64|EBPF_SRC_REG|EBPF_OP_ARSH);

parameter EBPF_OP_LDXW       = (OPC_LDX|EBPF_MODE_MEM|EBPF_SIZE_W);
parameter EBPF_OP_LDXH       = (OPC_LDX|EBPF_MODE_MEM|EBPF_SIZE_H);
parameter EBPF_OP_LDXB       = (OPC_LDX|EBPF_MODE_MEM|EBPF_SIZE_B);
parameter EBPF_OP_LDXDW      = (OPC_LDX|EBPF_MODE_MEM|EBPF_SIZE_DW);
parameter EBPF_OP_STW        = (OPC_ST|EBPF_MODE_MEM|EBPF_SIZE_W);
parameter EBPF_OP_STH        = (OPC_ST|EBPF_MODE_MEM|EBPF_SIZE_H);
parameter EBPF_OP_STB        = (OPC_ST|EBPF_MODE_MEM|EBPF_SIZE_B);
parameter EBPF_OP_STDW       = (OPC_ST|EBPF_MODE_MEM|EBPF_SIZE_DW);
parameter EBPF_OP_STXW       = (OPC_STX|EBPF_MODE_MEM|EBPF_SIZE_W);
parameter EBPF_OP_STXH       = (OPC_STX|EBPF_MODE_MEM|EBPF_SIZE_H);
parameter EBPF_OP_STXB       = (OPC_STX|EBPF_MODE_MEM|EBPF_SIZE_B);
parameter EBPF_OP_STXDW      = (OPC_STX|EBPF_MODE_MEM|EBPF_SIZE_DW);
parameter EBPF_OP_LDDW       = (OPC_LD|EBPF_MODE_IMM|EBPF_SIZE_DW);

parameter EBPF_OP_JEQ        = JMP_JEQ << 4;
parameter EBPF_OP_JGT        = JMP_JGT << 4;
parameter EBPF_OP_JGE        = JMP_JGE << 4;
parameter EBPF_OP_JSET       = JMP_JSET << 4;
parameter EBPF_OP_JNE        = JMP_JNE << 4;
parameter EBPF_OP_JSGT       = JMP_JSGT << 4;
parameter EBPF_OP_JSGE       = JMP_JSGE << 4;
parameter EBPF_OP_JLT        = JMP_JLT << 4;
parameter EBPF_OP_JLE        = JMP_JLE << 4;
parameter EBPF_OP_JSLT       = JMP_JSLT << 4;
parameter EBPF_OP_JSLE       = JMP_JSLE << 4;

parameter EBPF_OP_JA         = (OPC_JMP|8'h00);
parameter EBPF_OP_JEQ_IMM    = (OPC_JMP|EBPF_SRC_IMM|EBPF_OP_JEQ);
parameter EBPF_OP_JEQ_REG    = (OPC_JMP|EBPF_SRC_REG|EBPF_OP_JEQ);
parameter EBPF_OP_JGT_IMM    = (OPC_JMP|EBPF_SRC_IMM|EBPF_OP_JGT);
parameter EBPF_OP_JGT_REG    = (OPC_JMP|EBPF_SRC_REG|EBPF_OP_JGT);
parameter EBPF_OP_JGE_IMM    = (OPC_JMP|EBPF_SRC_IMM|EBPF_OP_JGE);
parameter EBPF_OP_JGE_REG    = (OPC_JMP|EBPF_SRC_REG|EBPF_OP_JGE);
parameter EBPF_OP_JSET_IMM   = (OPC_JMP|EBPF_SRC_IMM|EBPF_OP_JSET);
parameter EBPF_OP_JSET_REG   = (OPC_JMP|EBPF_SRC_REG|EBPF_OP_JSET);
parameter EBPF_OP_JNE_IMM    = (OPC_JMP|EBPF_SRC_IMM|EBPF_OP_JNE);
parameter EBPF_OP_JNE_REG    = (OPC_JMP|EBPF_SRC_REG|EBPF_OP_JNE);
parameter EBPF_OP_JSGT_IMM   = (OPC_JMP|EBPF_SRC_IMM|EBPF_OP_JSGT);
parameter EBPF_OP_JSGT_REG   = (OPC_JMP|EBPF_SRC_REG|EBPF_OP_JSGT);
parameter EBPF_OP_JSGE_IMM   = (OPC_JMP|EBPF_SRC_IMM|EBPF_OP_JSGE);
parameter EBPF_OP_JSGE_REG   = (OPC_JMP|EBPF_SRC_REG|EBPF_OP_JSGE);
parameter EBPF_OP_CALL       = (OPC_JMP|8'h80);
parameter EBPF_OP_EXIT       = (OPC_JMP|8'h90);
parameter EBPF_OP_JLT_IMM    = (OPC_JMP|EBPF_SRC_IMM|EBPF_OP_JLT);
parameter EBPF_OP_JLT_REG    = (OPC_JMP|EBPF_SRC_REG|EBPF_OP_JLT);
parameter EBPF_OP_JLE_IMM    = (OPC_JMP|EBPF_SRC_IMM|EBPF_OP_JLE);
parameter EBPF_OP_JLE_REG    = (OPC_JMP|EBPF_SRC_REG|EBPF_OP_JLE);
parameter EBPF_OP_JSLT_IMM   = (OPC_JMP|EBPF_SRC_IMM|EBPF_OP_JSLT);
parameter EBPF_OP_JSLT_REG   = (OPC_JMP|EBPF_SRC_REG|EBPF_OP_JSLT);
parameter EBPF_OP_JSLE_IMM   = (OPC_JMP|EBPF_SRC_IMM|EBPF_OP_JSLE);
parameter EBPF_OP_JSLE_REG   = (OPC_JMP|EBPF_SRC_REG|EBPF_OP_JSLE);

// VeBPF params
parameter VEBPF_PROG_ADDRESS_WIDTH = 10; // 12;  
    // 10 bit wide means 1024 in depth // for VeBPF depth parameter MEMORY_DEPTH = 2**ADDRESS_SIZE;  // 2**12 = 4096
    // the pgm data width is 64 bits, so we do not need 4096 depth of 64 bits per VeBPF rule.. I can either subtract that 
    // from the address width while instantiating the ram64 module here or outside the VeBPF CPU... how much depth for pgm mem
    // do I need? ... 2 ^ 8 = 256? I think 256 should be fine but I should write that here then.. 

// parameter VEBPF_PROG_ADDRESS_WIDTH_REDUCED = 8;
    // this constant is used to instantiate ram64 bram so that its depth is 256 while its width is 64 bits
    // so total lines of all eBPF rules should be less than 256 for the set of experiments I am doing
    // sim stikk works after reduced pgm mem depth
parameter VEBPF_PROG_ADDRESS_WIDTH_REDUCED = 9;
    // 256 pgm depth wasn't enough for 303 instr words of all firewall rules.. So I incremented it to 512

parameter VEBPF_PROG_DATA_WIDTH = 64;
parameter VEBPF_PROG_DATA_BYTES = 8;
parameter VEBPF_DATA_MEM_ADDRESS_WIDTH = 11;
    // 11 bit means = inside ram_module_v3.v parameter MEMORY_DEPTH = 2**ADDRESS_SIZE  // 2^11 = 2048 
        // need to optimize this memory ram module later
        // so data mem depth is fine

parameter VEBPF_DATA_MEM_WIDTH = 64;



// -------------Direct CPU Status and Control Signals----------------

input clk;
input reset_n;
output reg error;
// reg error;
output reg halt;
// reg halt;
reg debug;


// --------CSR (MMIO) Registers--------

// Control register for CPU
// bits: 0-reset_n
input [7:0] csr_ctl;
wire reset_n_int; // = (reset_n | csr_ctl[0]);
assign reset_n_int = (reset_n | csr_ctl[0]);

// CPU Status register including all status flags
// bits: 0-reset_n, 1-halt, 2-error, 7-debug
output [7:0] csr_status;
assign csr_status[0] = reset_n_int;
assign csr_status[1] = halt;
assign csr_status[2] = error;
assign csr_status[3] = 0;		// reserved
assign csr_status[4] = 0;		// reserved
assign csr_status[5] = 0;		// reserved
assign csr_status[6] = 0; 		// reserved
assign csr_status[7] = debug;

// Create register bank with direct accessors for each register in bank.
reg [63:0] regs [MAX_REGS-1:0];

// Result Register R0
output [63:0] r0;
assign r0 = regs[0];

// Input Registers (r1 - r5 are in sync block)
input [63:0] r1;
input [63:0] r2;
input [63:0] r3;
input [63:0] r4;
input [63:0] r5;

// Output Registers
output [63:0] r6;
assign r6 = regs[6];
output [63:0] r7;
assign r7 = regs[7];
output [63:0] r8;
assign r8 = regs[8];
output [63:0] r9;
assign r9 = regs[9];
output [63:0] r10;
assign r10 = regs[10];

// clk ticks between resest going high and halt going high
output reg [63:0] ticks;

// data memory ports
output data_mem_ack_output_port;
// input [63:0] data_mem_write_64bit_input_port;
input [VEBPF_DATA_MEM_WIDTH-1:0] data_mem_write_64bit_input_port;
input [3:0] data_mem_dataBytesWrittenWidth_ww_input_port;
input data_mem_we_input_port;
// input [10:0] data_mem_adr_input_port;
input [VEBPF_DATA_MEM_ADDRESS_WIDTH-1:0] data_mem_adr_input_port;
input data_mem_stb_input_port;

// VeBPF prog mem ports
input  [VEBPF_PROG_ADDRESS_WIDTH-1:0]               VeBPF_prog_addr_in;
input  [VEBPF_PROG_DATA_WIDTH-1:0]                  VeBPF_prog_data_in;
input                                               VeBPF_prog_write_enable_in;
input                                               VeBPF_prog_reset_in;               // separate reset for the prog mem of VeBPF
// input                                               VeBPF_prog_busy_in;                // the progloader is busy writing to VeBPF prog mem
// input                                               VeBPF_prog_done_in;                // VeBPF prog has been completed 

// Running next selected RULE
input                    run_next_selected_rule_en;             // en signal to run the next selected rule, will make this HIGH when halt = 1
input [VEBPF_PROG_ADDRESS_WIDTH-1:0]             ip_next_rule;                          // instruction pointer for next selected rule

// ------------FSM------------

reg [2:0] state;	// 6 possible state, so 3 bits required
reg [2:0] state_next;
reg [2:0] state_next_temp;
reg cpu_data_ack, cpu_div64_ack;


// Represents an ebpf instruction.
// See https://www.kernel.org/doc/Documentation/networking/filter.txt
// for more information.

// Layout of an ebpf instruction. VM internally works with
// little-endian byte-order.

// MSB                                                        LSB
// | Byte 8 | Byte 7  | Byte 5-6       | Byte 1-4               |
// +--------+----+----+----------------+------------------------+
// |opcode  | src| dst|          offset|               immediate|
// +--------+----+----+----------------+------------------------+
// 63     56   52   48               32                        0
        
reg [63:0] instruction;

reg [7:0] keep_op;
reg [3:0] keep_dst;

reg [VEBPF_PROG_ADDRESS_WIDTH-1:0] ip;
reg [VEBPF_PROG_ADDRESS_WIDTH-1:0] ip_next;


// Continuous Assignment
// Byte 8
wire [7:0] opcode;          // = ((keep_op == 0) ? (instruction[63:56]) : (keep_op)) ;
assign opcode = ((keep_op == 0) ? (instruction[63:56]) : (keep_op)) ;

wire [2:0] opclass;         // = opcode[2:0];
assign opclass = opcode[2:0];

// Byte 7
wire [3:0] src;             // = instruction[55:52];
assign src = instruction[55:52];

wire [3:0] dst;             // = ((keep_dst == 0) ? (instruction[51:48]) : (keep_dst));
// assign dst = ((keep_dst == 0) ? (instruction[51:48]) : (keep_dst));
// error above .. keep_dst insplace of keep_op
assign dst = ((keep_op == 0) ? (instruction[51:48]) : (keep_dst));

// Byte 5-6
wire [15:0] offset;         // = {instruction[47:40], instruction[39:32]};
assign offset = {instruction[47:40], instruction[39:32]};
    // error most prob? Maybe no cx we have already flipped the instruction bytes to what we required
        // same can be seen below in assignment of immediate

wire signed [15:0] offset_s;    // = offset;
assign offset_s = offset;  // signed offset :3

// Byte 1-4
wire [31:0] immediate;      // = {instruction[31:24], instruction[23:16], instruction[15:8], instruction[7:0]};
assign immediate = {instruction[31:24], instruction[23:16], instruction[15:8], instruction[7:0]};
    // immediate.eq(Cat(instruction[24:32],
    //                      instruction[16:24],
    //                      instruction[8:16],
    //                      instruction[0:8])),

wire signed [31:0] immediate_s;         // = immediate;
assign immediate_s = immediate;  // signed offset


wire [63:0] src_reg;            // = regs[src];
assign src_reg = regs[src];

wire signed [63:0] src_reg_s;       // = regs[src];
assign src_reg_s = regs[src];

wire [31:0] src_reg_32;     // = regs[src];
assign src_reg_32 = regs[src];

wire signed [31:0] src_reg_32_s;        // = regs[src];
assign src_reg_32_s = regs[src];

wire [63:0] dst_reg;        // = regs[dst];
assign dst_reg = regs[dst];


wire signed [63:0] dst_reg_s;       // = regs[dst];
assign dst_reg_s = regs[dst];


wire [31:0] dst_reg_32;         // = regs[dst];
assign dst_reg_32 = regs[dst];


wire signed [31:0] dst_reg_32_s;        // = regs[dst];
assign dst_reg_32_s = regs[dst];


// --------Program Memory--------
// max program memory words is 4096 = 2^12
// pgm_adr = 12 bits long and ip = 32 bits long
// wire [11:0] pgm_adr = ip[11:0];	// input  // error here ? ip_next in cpu.py
// wire [11:0] pgm_adr;        // = ip_next[11:0]; // input
wire [VEBPF_PROG_ADDRESS_WIDTH-1:0] pgm_adr;        // = ip_next[11:0]; // input
// assign pgm_adr = ip_next[11:0]; // input
assign pgm_adr = ip_next; // input

wire [63:0] pgm_dat_r;			// output

// wire [11:0] VeBPF_pgm_adr;
// assign VeBPF_pgm_adr = VeBPF_prog_addr_in;
// assign VeBPF_pgm_adr = (VeBPF_prog_write_enable_in) ?  VeBPF_prog_addr_in : pgm_adr;

// // Add DISL simulation parameter in SIMULATION parameter here
// // Program Instructions module, read-only
// ram64_memory_v1 #(
//     .DATA_SIZE(64), 
//     .ADDRESS_SIZE(12),
//     // .SIMULATION(1)
//     .SIMULATION(SIMULATION)
// ) 
// pgm(
//     .clk(clk),
//     // .rst(!reset_n_int),
//     .rst(VeBPF_prog_reset_in),  // separate reset for program memory
//     // .address(pgm_adr), 
//     .address(VeBPF_pgm_adr), 
//     .data_in(VeBPF_prog_data_in), 
//     .data_out(pgm_dat_r), 
//     // .write_enable(1'b0)
//     .write_enable(VeBPF_prog_write_enable_in)
// );

// Add DISL simulation parameter in SIMULATION parameter here
// Program Instructions module, read-only
ram64_memory_v3 #(
    // .DATA_SIZE(64), 
    .DATA_SIZE(VEBPF_PROG_DATA_WIDTH), 
    // .ADDRESS_SIZE(VEBPF_PROG_ADDRESS_WIDTH),  // 10
    .ADDRESS_SIZE(VEBPF_PROG_ADDRESS_WIDTH_REDUCED),  // 9
    // .ADDRESS_SIZE(5),  // extra reduced 
    // .SIMULATION(1)
    .SIMULATION(SIMULATION),
    .VEBPF_SIM(VEBPF_SIM)
) 
pgm(
    .clk(clk),
    .rst(VeBPF_prog_reset_in),  // separate reset for program memory
    .wr_address(VeBPF_prog_addr_in), // Writing pgm memory is only availble to VeBPF pgm/Rules uploader
    // .wr_address(VeBPF_pgm_adr), 
    .rd_address(pgm_adr), 
    .data_in(VeBPF_prog_data_in), // Writing pgm memory is only availble to VeBPF pgm/Rules uploader
    .data_out(pgm_dat_r), 
    .write_enable(VeBPF_prog_write_enable_in),
    .rd_enable(1) // always ready to be read since BRAMs are always initialized as dual port memories in case of Xilinx devices
);

// iverilog_dump iverilog_dump();

// ******** VIP ******* Comment or uncomment stuff below w.r.t configuration of simulation, either DISL or automated VeBPF testing
`ifndef SYNTHESIS
iverilog_dump_sv #(.VEBPF_SIM(VEBPF_SIM)) dump_file_module();
`endif
// uncomment this dump module below for simulation for automated testing of VeBPF cpu
// generate

//     // if (VEBPF_SIM == 1) begin
//         // iverilog_dump_sv dump_file_module(.clk(clk));
//     // end

// endgenerate

// uncomment when testing in DISL simulation
integer idx4;

initial begin

    if (SIMULATION) begin
        // #20
        $dumpfile("top.fst");
        // for (idx = 0; idx < `DUMP_DEPTH; idx = idx + 1) begin
        for (idx4 = 0; idx4 < 11; idx4 = idx4 + 1) begin
            $dumpvars(0, regs[idx4]); // dumping mem data into the output waveform
        end  
    end

end


// -------Data Memory (e.g Packet Data)------- (WIP)
// max data memory words is 2048 = 2^11
// data_adr = 11 bits long
// inputs
reg data_stb;
wire data_stb_wire;     // = data_stb;
assign data_stb_wire = data_stb;

reg [10:0] data_adr;
wire [10:0] data_adr_wire;      // = data_adr;
assign data_adr_wire = data_adr;

reg data_we;
wire data_we_wire;      // = data_we;
assign data_we_wire = data_we;


reg [3:0] data_ww;
wire [3:0] data_ww_wire;        // = data_ww;
assign data_ww_wire = data_ww;


reg [63:0] data_dat_w;
wire [63:0] data_dat_w_wire;        // = data_dat_w;
assign data_dat_w_wire = data_dat_w;

// commentedout connections below 
// outputs  
// wire [63:0] data_dat_r8;
// wire [7:0] data_dat_r0 = data_dat_r8[7:0];
// wire [15:0] data_dat_r2 = data_dat_r8[15:0];
// wire [31:0] data_dat_r4 = data_dat_r8[31:0];

// outputs redefined
wire [63:0] data_dat_r8;
wire [7:0] data_dat_r0;
wire [15:0] data_dat_r2;
wire [31:0] data_dat_r4;
wire data_ack;

// data_memory #(.data_size(64), .address_size(11)) data_mem(.stb(data_stb_wire), .adr(data_adr_wire), .we(data_we_wire),
//  .ww(data_ww_wire), .dat_w(data_dat_w_wire), .clk(clk), .dat_r(data_dat_r8), .data_ack(data_ack));

// data_memory replaced by ram_module_v1

// Data memory module, read/write both. Currently write first policy

// ram_module_v1 replaced with ram_module_v2 which gives ack after write instead of going into read state after right and then giving ack
// ram_module_v1 #(

// replacing ram inputs and few outputs with muxes and demuxes  
// ram_module_v2 #(
//     .DATA_SIZE(64), 
//     .ADDRESS_SIZE(11),
//     .SIMULATION(1)
// )  
// data_mem(
//     .clk(clk), 
//     .rst(!reset_n_int), 
//     .stb(data_stb_wire), 
//     .adr1(data_adr_wire), 
//     .we0(data_we_wire), 
//     .ww(data_ww_wire), 
//     .dat_w0(data_dat_w_wire), 
//     .dat_r8(data_dat_r8), 
//     .dat_r4(data_dat_r4), 
//     .dat_r2(data_dat_r2), 
//     .dat_r0(data_dat_r0), 
//     .ack(data_ack)
// );

wire data_mem_ack_out;

// if VeBPF is in reset state (reset_n is 0), data_ack is equal to 0
// assign data_ack = reset_n_int ? data_mem_ack_out : 0;
assign data_ack = (!csr_ctl[1]) ? data_mem_ack_out : 0;

// if VeBPF is in reset state (reset_n is 0), data_mem_ack_output_port is connected to data memory ack port
// assign data_mem_ack_output_port = reset_n_int ? 0 : data_mem_ack_out;
assign data_mem_ack_output_port = (!csr_ctl[1]) ? 0 : data_mem_ack_out;

wire [63:0] data_mem_write_64bit_w0_port;
// if VeBPF is in reset state (reset_n is 0), data_mem_write_64bit_w0_port is connected to  input port data_mem_write_64bit_input_port, otherwise it is connected to data_dat_w_wire
// assign data_mem_write_64bit_w0_port = reset_n_int ? data_dat_w_wire : data_mem_write_64bit_input_port;
assign data_mem_write_64bit_w0_port = (!csr_ctl[1]) ? data_dat_w_wire : data_mem_write_64bit_input_port;

wire [3:0] data_mem_dataBytesWrittenWidth_ww_port;
// if VeBPF is in reset state (reset_n is 0), data_mem_dataBytesWrittenWidth_ww_port = data_mem_dataBytesWrittenWidth_ww_input_port
// assign data_mem_dataBytesWrittenWidth_ww_port = reset_n_int ? data_ww_wire : data_mem_dataBytesWrittenWidth_ww_input_port;
assign data_mem_dataBytesWrittenWidth_ww_port =  (!csr_ctl[1]) ? data_ww_wire : data_mem_dataBytesWrittenWidth_ww_input_port;

wire data_mem_we_port;
// assign data_mem_we_port = reset_n_int ? data_we_wire : data_mem_we_input_port;
assign data_mem_we_port = (!csr_ctl[1]) ? data_we_wire : data_mem_we_input_port;


wire [10:0] data_mem_adr_port;
// assign data_mem_adr_port = reset_n_int ? data_adr_wire : data_mem_adr_input_port;
assign data_mem_adr_port = (!csr_ctl[1]) ? data_adr_wire : data_mem_adr_input_port;


wire data_mem_stb_port;
assign data_mem_stb_port =  (!csr_ctl[1]) ? data_stb_wire : data_mem_stb_input_port;


// Add DISL simulation parameter in SIMULATION parameter here
ram_module_v3 #(
    //.DATA_SIZE(64), 
    .DATA_SIZE(VEBPF_DATA_MEM_WIDTH), 
    // .ADDRESS_SIZE(11),
    .ADDRESS_SIZE(VEBPF_DATA_MEM_ADDRESS_WIDTH),
    // .ADDRESS_SIZE(7),  // extra reduced 
    // .SIMULATION(1)
    .SIMULATION(SIMULATION),
    .VEBPF_SIM(VEBPF_SIM)
)  
data_mem(
    .clk(clk), 
    .rst((!reset_n_int) ^ (csr_ctl[1])), 
        // VeBPF_csr_ctl_next[1] = 1 to get access to VeBPF data memory and overwite its reset and 0 to give access back to VeBPF
        // while VeBPF_reset_n_next = 0; // reset is active (can load data memory in VeBPF now)
            // rst(1 ^ 1) = rst(0)  // rst is deactivated
        // when running VeBPF cpu VeBPF_reset_n_next = 1 and VeBPF_csr_ctl_next[1] = 0 which means:
            // rst(0 ^ 0) = rst(0)  // rst is deactivated
        // what happens on rst(1 ^ 0) = rst(1) // rst activated .. value of VeBPF rst is used
        // what happens on rst(0 ^ 1) = rst(1) // rst activated .. value of VeBPF rst is 
        // not used but is still active even though csr_ctl[1] = 1.. so for using csr_ctl[1]
        // VeBPF rst should be active (reset_n_int = 0)



    .stb(data_mem_stb_port), //
    .adr1(data_mem_adr_port), //
    .we0(data_mem_we_port), //
    .ww(data_mem_dataBytesWrittenWidth_ww_port), //
    .dat_w0(data_mem_write_64bit_w0_port), //
    .dat_r8(data_dat_r8), 
    .dat_r4(data_dat_r4), 
    .dat_r2(data_dat_r2), 
    .dat_r0(data_dat_r0), 
    .ack(data_mem_ack_out) //
);


// -------64 Bit Logic and Arithmetic Shifter -------
// input
reg arsh64_stb;
wire arsh64_stb_wire;       // = arsh64_stb;
assign arsh64_stb_wire = arsh64_stb;


reg arsh64_arith;
wire arsh64_arith_wire;     // = arsh64_arith;
assign arsh64_arith_wire = arsh64_arith;


reg arsh64_left;
wire arsh64_left_wire;      // = arsh64_left;
assign arsh64_left_wire = arsh64_left;


reg [63:0] arsh64_value;
wire [63:0] arsh64_value_wire;      // = arsh64_value;
assign arsh64_value_wire = arsh64_value;


reg [63:0] arsh64_shift;
wire [63:0] arsh64_shift_wire;      // = arsh64_shift;
assign arsh64_shift_wire = arsh64_shift;

// output
wire [63:0] arsh64_out;
wire arsh64_ack;

shifter #(
    .data_width(64)
) 
arsh64(
    .clk(clk),
    .rst(!reset_n_int),
    .stb(arsh64_stb_wire), 
    .arith(arsh64_arith_wire), 
    .left(arsh64_left_wire), 
    .value(arsh64_value_wire), 
    .shift(arsh64_shift_wire), 
    .out(arsh64_out), 
    .ack(arsh64_ack)
);


// -------64 Bit Math Divider-------
// input
reg [63:0] div64_dividend;
wire [63:0] div64_dividend_wire;        // = div64_dividend;
assign div64_dividend_wire = div64_dividend;


reg [63:0] div64_divisor;
wire [63:0] div64_divisor_wire;     // = div64_divisor;
assign div64_divisor_wire = div64_divisor;


reg div64_stb;
wire div64_stb_wire;        // = div64_stb;
assign div64_stb_wire = div64_stb;

// output
wire [63:0] div64_quotient;
wire [63:0] div64_remainder;
wire div64_ack, div64_err;

divider #(
    .data_width(64)
) 
div64(
    .clk(clk), 
    .reset_n(reset_n_int), 
    .dividend(div64_dividend_wire), 
    .divisor(div64_divisor_wire), 
    .stb(div64_stb_wire), 
    .quotient(div64_quotient), 
    .remainder(div64_remainder), 
    .ack(div64_ack), 
    .err(div64_err)
);

// MSB                                                        LSB
// | Byte 8 | Byte 7  | Byte 5-6       | Byte 1-4               |
// +--------+----+----+----------------+------------------------+
// |opcode  | src| dst|          offset|               immediate|
// +--------+----+----+----------------+------------------------+
// 63     56   52   48               32                        0

// -------Call Handler-------
// input
reg [63:0] call_handler_func;
wire [63:0] call_handler_func_wire;     // = call_handler_func;
assign call_handler_func_wire = call_handler_func;


reg call_handler_stb;
wire call_handler_stb_wire;         // = call_handler_stb;
assign call_handler_stb_wire = call_handler_stb;


reg [63:0] call_handler_r1;
wire [63:0] call_handler_r1_wire;       // = call_handler_r1;
assign call_handler_r1_wire = call_handler_r1;


reg [63:0] call_handler_r2; 
wire [63:0] call_handler_r2_wire;       // = call_handler_r2; 
assign call_handler_r2_wire = call_handler_r2; 


reg [63:0] call_handler_r3; 
wire [63:0] call_handler_r3_wire;       // = call_handler_r3;
assign call_handler_r3_wire = call_handler_r3;


reg [63:0] call_handler_r4; 
wire [63:0] call_handler_r4_wire;       // = call_handler_r4;
assign call_handler_r4_wire = call_handler_r4;


reg [63:0] call_handler_r5;
wire [63:0] call_handler_r5_wire;       // = call_handler_r5;
assign call_handler_r5_wire = call_handler_r5;

// output
wire [63:0] call_handler_ret;
wire call_handler_IP4_led, call_handler_IPv6_led, call_handler_pkt_err_led; 
wire call_handler_ack, call_handler_err;

// atm not using call function in the synthesized version that's why limiting it to SIMULATION
generate
        
    if (SIMULATION || VEBPF_SIM) begin
        call_handler call_handler(
            .clk(clk), 
            .rst(!reset_n_int),
            .func(call_handler_func_wire), 
            .stb(call_handler_stb_wire), 
            .r1(call_handler_r1_wire), 
            .r2(call_handler_r2_wire), 
            .r3(call_handler_r3_wire), 
            .r4(call_handler_r4_wire), 
            .r5(call_handler_r5_wire), 
            .ret(call_handler_ret), 
            .IP4_led(call_handler_IP4_led), 
            .IPv6_led(call_handler_IPv6_led), 
            .pkt_err_led(call_handler_pkt_err_led), 
            .ack(call_handler_ack), 
            .err(call_handler_err)
        );
    end

endgenerate

// debugging signals
reg [7:0] debug_byte1; 
reg [7:0] debug_byte2; 


// -------Sync Logic-------

// always @(posedge clk or posedge reset_n) begin
always @(posedge clk) begin
	if (~reset_n_int) begin

		ticks <= 0;
		error <= 0;
		halt  <= 0;

        // if you wnat to change ip_next while VeBPF cpu is in reset state,
        // you need to keep "run_next_selected_rule_en" HIGH throughout the 
        // duration that reset is ACTIVE 
        if (run_next_selected_rule_en) begin

            ip_next <= ip_next_rule;
            ip <= ip_next_rule;

        end else begin 

            ip_next <= 0;
            ip <= 0;

        end 
		
		instruction <= pgm_dat_r;
        // instruction <= 0;
		// state <= STATE_OP_FETCH;
		state_next <= STATE_OP_FETCH;
        state_next_temp <= STATE_OP_FETCH;

		keep_op <= 0;
		keep_dst <= 0;

		regs[0] <= 0;

		// r1 - r5 are used as input arguments and thus are not cleared
        // but set from CSR
		regs[1] <= r1;
		regs[2] <= r2;
		regs[3] <= r3;
		regs[4] <= r4;
		regs[5] <= r5;

		regs[6] <= 0;
		regs[7] <= 0;
		regs[8] <= 0;
		regs[9] <= 0;
		regs[10] <= 0;

        // regs initialization
        data_ww <= 0;
        cpu_data_ack <= 0;
        cpu_div64_ack <= 0;
        data_stb <= 0;
        data_adr <= 0;
        data_we <= 0;
        data_dat_w <= 0;
        arsh64_stb <= 0;
        arsh64_arith <= 0;
        arsh64_left <= 0;
        arsh64_value <= 0;
        arsh64_shift <= 0;
        div64_dividend <= 0;
        div64_divisor <= 0;
        div64_stb <= 0;
        call_handler_func <= 0;
        call_handler_stb <= 0;
        call_handler_r1 <= 0;
        call_handler_r2 <= 0;
        call_handler_r3 <= 0;
        call_handler_r4 <= 0;
        call_handler_r5 <= 0;

        
        // debug
        debug_byte1 <= 0;
        debug_byte2 <= 0;
        debug <= 0;
	end 

	// // If halt signal high, stop CPU
	// else if (halt) begin
	// 	state_next <= STATE_HALT;  // nothing happens in STATE_HALT in cpu.py as well
	// end 

	// // Check invalid source register
	// else if (src >= MAX_REGS) begin
	// 	error <= 1;
	// 	halt <= 1;
	// end 

	// // Check invalid destination register
	// else if (src >= MAX_REGS) begin
	// 	error <= 1;
	// 	halt <= 1;
	// end 

	// // Check for incomplete LDDW instruction
	// else if ((keep_op & instruction[63:56]) != 0) begin
	// 	error <= 1;
	// 	halt <= 1;
	// end 

	// Process opcodes
	else begin

        // when state_next not assigned a value, then default to the previous assigned value
        state_next <= state_next;
        state_next_temp <= state_next_temp;

        // If halt signal high, stop CPU
        if (halt) begin
            state_next <= STATE_HALT;  // nothing happens in STATE_HALT in cpu.py as well

            // for running multiple VeBPF Rules:
                // 1) As soon as halt goes HIGH and error signals are 0, the FSM will send a 
                //    run_next_selected_rule_en
                // 2) Reset should be low (reset_n = 1) 
                // 3) Send the value of ip_next from outside, to point to where the next selected
                //    rule is located in pgm mem.
                //    3b) When run_next_selected_rule_en is HIGH, ip_next will be able to changed according 
                //        to the value of ip_next from outside.
                // 4) When run_next_selected_rule_en is HIGH, make halt signal LOW and go to OP_FETCH state

            // don't need to reprogram the VeBPF when it is in HALT state.. We need to give it a reset first and then
            // reprogram the VeBPF while it is in RESET state and then deactivate the reset so VeBPF runs the rule
            // that was updated during reprog (remember to keep the reprogram enable bit HIGH during reset if you 
            // want to run the selected VeBPF reprogrammed rule})
                // TODO: test this update in VeBPF automatic testing framework
                
            // if (run_next_selected_rule_en) begin
                
            //     // reassign the instruction pointer of VeBPF pgm mem
            //     ip_next <= ip_next_rule;
            //     ip <= ip_next_rule;

            //     // pull-down halt signal so next selected VeBPF rule can be run
            //     // also setting all signals to reset condition except for instruction <= pgm_dat_r (that will be set in op_fetch)

            //     ticks <= 0;
            //     error <= 0;
            //     // halt  <= 0;
            //         // do not reset halt if reset is not activated and then deactivated again since
            //         // we don't want to run the VeBPF after it receives run_next_selected_rule_en
            //         // in halt state :/

            //     state_next <= STATE_OP_FETCH;
            //     state_next_temp <= STATE_OP_FETCH;

            //     keep_op <= 0;
            //     keep_dst <= 0;

            //     // setting output register to 0
            //     regs[0] <= 0;

            //     // r1 - r5 are used as input arguments and thus are not cleared
            //     // but set from CSR
            //     regs[1] <= r1;
            //     regs[2] <= r2;
            //     regs[3] <= r3;
            //     regs[4] <= r4;
            //     regs[5] <= r5;

            //     regs[6] <= 0;
            //     regs[7] <= 0;
            //     regs[8] <= 0;
            //     regs[9] <= 0;
            //     regs[10] <= 0;

            //     // regs initialization
            //     data_ww <= 0;
            //     cpu_data_ack <= 0;
            //     cpu_div64_ack <= 0;
            //     data_stb <= 0;
            //     data_adr <= 0;
            //     data_we <= 0;
            //     data_dat_w <= 0;
            //     arsh64_stb <= 0;
            //     arsh64_arith <= 0;
            //     arsh64_left <= 0;
            //     arsh64_value <= 0;
            //     arsh64_shift <= 0;
            //     div64_dividend <= 0;
            //     div64_divisor <= 0;
            //     div64_stb <= 0;
            //     call_handler_func <= 0;
            //     call_handler_stb <= 0;
            //     call_handler_r1 <= 0;
            //     call_handler_r2 <= 0;
            //     call_handler_r3 <= 0;
            //     call_handler_r4 <= 0;
            //     call_handler_r5 <= 0;


            // end

        end 

        // Check invalid source register
        else if (src >= MAX_REGS) begin
            error <= 1;
            halt <= 1;
            debug_byte2 <= 1;
        end 

        // Check invalid destination register
        // else if (src >= MAX_REGS) begin  // error
        else if (dst >= MAX_REGS) begin
            error <= 1;
            halt <= 1;
            debug_byte2 <= 2;
        end 

        // Check for incomplete LDDW instruction
        else if ((keep_op & instruction[63:56]) != 0) begin
            error <= 1;
            halt <= 1;
            debug_byte2 <= 3;
        end else begin 

    		ticks <= ticks + 1;

            // commenting these out cx this resets the values of regs[1-5] to 0 if r1-r5 inputs are 0.
            // the python code blow this is just writing the values of r1-r5 to the csr_rX.storage
    		// regs[1] <= r1;
    		// regs[2] <= r2;
    		// regs[3] <= r3;
    		// regs[4] <= r4;
    		// regs[5] <= r5;

            // csr_r1.storage.eq(self.r1),  # writing the register values from r1-r5 to csr_r1-5.storage
            // csr_r2.storage.eq(self.r2),
            // csr_r3.storage.eq(self.r3),
            // csr_r4.storage.eq(self.r4),
            // csr_r5.storage.eq(self.r5),


    		// case(state)
            case(state_next)

    			// STATE_OP_FETCH
    			STATE_OP_FETCH: begin
    				ip_next <= ip_next + 1;
    				ip <= ip_next;
    				instruction <= pgm_dat_r;
    				// state_next <= STATE_DECODE;
                    state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                    state_next_temp <= STATE_DECODE;
    			end // STATE_OP_FETCH

                // STATE_OP_FETCH_DELAY
                STATE_OP_FETCH_DELAY: begin  // 1 clk delay for fetching pgm memory
                    ip_next <= ip_next;
                    ip <= ip;
                    instruction <= pgm_dat_r;
                    state_next <= state_next_temp;  // state_next_temp reg to store the next state that was the next incoming state before op fetch delay
                end 

    			// STATE_DECODE
    			STATE_DECODE: begin
    				keep_op <= 0;

    				case(opclass)

    					// OPC_LD
    					OPC_LD: begin
    						case(opcode)

    							// EBPF_OP_LDDW
    							EBPF_OP_LDDW: begin
    								if (keep_op == 0) begin
    									regs[dst] <= immediate;
                                		keep_op <= opcode;
                                		keep_dst <= dst;
    								end
    								else begin
    									regs[dst][63:32] <= immediate;
    								end
    								ip_next <= ip_next + 1;
                            		ip <= ip_next;
                            		instruction <= pgm_dat_r;
                                    state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                    state_next_temp <= state_next;
    							end // EBPF_OP_LDDW

    							// default
    							default: begin
    								error <= 1;
    								halt <= 1;
                                    debug_byte2 <= 4;
    							end // default
    						endcase // opcode
    					end


    					// OPC_LDX
    					OPC_LDX: begin  // no ww here.. or rw (read width) .. full DW is always read by cpu and whatever portion of the DW is needed is transferred here
    						if (~cpu_data_ack) begin
    							data_adr <= regs[src] + offset; // this isnt correct with current data_memory.v implementation cx it is addressing memory w.r.t 
                                // DW addressing .. so address 0x02 means the byte starting at bit number 2 x 64 + 1 .. since each bin of memory in data_memory.v
                                // has 64 bits.. whereas eBPF data memory has to be byte addressable
                                    //comments from cpu.py 
                                        // data.adr.eq(regs[src] + offset),  # this addresses byte by byte.. e.g., load DW at mem addr loc 0x09 (this is the byte addr not word address for DATA mem of eBPF)
    							state_next <= STATE_DATA_FETCH;
    						end
    						else begin

    							case (opcode)

    								// EBPF_OP_LDXB
    								EBPF_OP_LDXB: begin
    									regs[dst] <= data_dat_r0;
    								end // EBPF_OP_LDXB

    								// EBPF_OP_LDXH
    								EBPF_OP_LDXH: begin
    									regs[dst] <= data_dat_r2;
    								end // EBPF_OP_LDXH

    								// EBPF_OP_LDXW
    								EBPF_OP_LDXW: begin  // here for stxw.test
    									regs[dst] <= data_dat_r4;
    								end // EBPF_OP_LDXW

    								// EBPF_OP_LDXDW
    								EBPF_OP_LDXDW: begin
    									regs[dst] <= data_dat_r8;
    								end // EBPF_OP_LDXDW

    								// default
    								default: begin
    									error <= 1;
    									halt <= 1;
                                        debug_byte2 <= 5;
    								end // default
    							endcase // opcode
    							ip_next <= ip_next + 1;
    							ip <= ip_next;
    							instruction <= pgm_dat_r;
                                state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                state_next_temp <= state_next;
    						end
    					end // OPC_LDX


    					// OPC_ST
    					OPC_ST: begin
    						if (~cpu_data_ack) begin
    							data_adr <= regs[dst] + offset;
    							data_we <= 1;

    							case (opcode)

    								// EBPF_OP_STB
    								EBPF_OP_STB: begin
    									data_ww <= 1;
    									data_dat_w <= immediate[7:0];
    								end // EBPF_OP_STB

    								// EBPF_OP_STH
    								EBPF_OP_STH: begin
    									data_ww <= 2;
    									data_dat_w <= immediate[15:0];
    								end // EBPF_OP_STH

    								// EBPF_OP_STW
    								EBPF_OP_STW: begin
    									data_ww <= 4;
    									data_dat_w <= immediate[31:0];
    								end // EBPF_OP_STW

    								// EBPF_OP_STDW
    								EBPF_OP_STDW: begin
    									data_ww <= 8;
    									data_dat_w <= immediate;
                                        debug_byte1 <= 8;
    								end // EBPF_OP_STDW

    								// default
    								default: begin
    									error <= 1;
    									halt <= 1;
                                        debug_byte2 <= 6;
    								end // default
    							endcase // opcode
    							state_next <= STATE_DATA_FETCH;
    						end
    						else begin
    							ip_next <= ip_next + 1;
                                ip <= ip_next;
                                instruction <= pgm_dat_r;
                                state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                state_next_temp <= state_next;
    						end
    					end // OPC_ST


    					// OPC_STX
    					OPC_STX: begin
    						if (~cpu_data_ack) begin
    							data_adr <= regs[dst] + offset;
    							data_we <= 1;

    							case (opcode)

    								// EBPF_OP_STXB
    								EBPF_OP_STXB: begin
    									data_ww <= 1;
    									data_dat_w <= regs[src][7:0];
    								end // EBPF_OP_STXB

    								// EBPF_OP_STXH
    								EBPF_OP_STXH: begin
    									data_ww <= 2;
    									data_dat_w <= regs[src][15:0];
    								end // EBPF_OP_STXH

    								// EBPF_OP_STXW
    								EBPF_OP_STXW: begin
    									data_ww <= 4;
    									data_dat_w <= regs[src][31:0];
    								end // EBPF_OP_STXW

    								// EBPF_OP_STXDW
    								EBPF_OP_STXDW: begin
    									data_ww <= 8;
    									data_dat_w <= regs[src];
    								end // EBPF_OP_STXDW

    								// default
    								default: begin
    									error <= 1;
    									halt <= 1;
                                        debug_byte2 <= 7;
    								end // default
    							endcase // opcode
    							state_next <= STATE_DATA_FETCH;
    						end
    						else begin
    							ip_next <= ip_next + 1;
    							ip <= ip_next;
    							instruction <= pgm_dat_r;
                                state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                state_next_temp <= state_next;
    						end
    					end // OPC_STX


    					// OPC_ALU
    					OPC_ALU: begin
    						cpu_div64_ack <= 0;

    						case (opcode)

    							// EBPF_OP_DIV_IMM
    							EBPF_OP_DIV_IMM: begin
    								if (~cpu_div64_ack) begin
    									div64_dividend <= (regs[dst] & 32'hffffffff);
    									div64_divisor <= (immediate & 32'hffffffff);
    									state_next <= STATE_DIV_PENDING;
    									div64_stb <= 1;
    								end
    								else begin
    									regs[dst] <= div64_quotient;
    									ip_next <= ip_next + 1;
    									ip <= ip_next;
    									instruction <= pgm_dat_r;
                                        state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                        state_next_temp <= state_next;
    								end
    							end // EBPF_OP_DIV_IMM
    						
    							// EBPF_OP_DIV_REG
    							EBPF_OP_DIV_REG: begin
    								// if (~div64_ack) begin  // error
                                    if (~cpu_div64_ack) begin
    									div64_dividend <= (regs[dst] & 32'hffffffff);
    									div64_divisor <= (regs[src] & 32'hffffffff);
    									state_next <= STATE_DIV_PENDING;
    									div64_stb <= 1;
    								end
    								else begin
    									regs[dst] <= div64_quotient;
    									ip_next <= ip_next + 1;
    									ip <= ip_next;
    									instruction <= pgm_dat_r;
                                        state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                        state_next_temp <= state_next;
    								end
    							end // EBPF_OP_DIV_REG

    							// EBPF_OP_MOD_IMM
    							EBPF_OP_MOD_IMM: begin
    								// if (~div64_ack) begin // error
                                    if (~cpu_div64_ack) begin
    									div64_dividend <= (regs[dst] & 32'hffffffff);
    									div64_divisor <= (immediate & 32'hffffffff);
    									state_next <= STATE_DIV_PENDING;
    									div64_stb <= 1;
    								end
    								else begin
    									regs[dst] <= div64_remainder;
    									ip_next <= ip_next + 1;
    									ip <= ip_next;
    									instruction <= pgm_dat_r;
                                        state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                        state_next_temp <= state_next;
    								end
    							end // EBPF_OP_MOD_IMM

    							// EBPF_OP_MOD_REG
    							EBPF_OP_MOD_REG: begin
    								// if (~div64_ack) begin  // error
                                    if (~cpu_div64_ack) begin
    									div64_dividend <= (regs[dst] & 32'hffffffff);
    									div64_divisor <= (regs[src] & 32'hffffffff);
    									state_next <= STATE_DIV_PENDING;
    									div64_stb <= 1;
    								end
    								else begin
    									regs[dst] <= div64_remainder;
    									ip_next <= ip_next + 1;
    									ip <= ip_next;
    									instruction <= pgm_dat_r;
                                        state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                        state_next_temp <= state_next;
    								end
    							end // EBPF_OP_MOD_REG

    							// EBPF_OP_ARSH_IMM
    							EBPF_OP_ARSH_IMM: begin
    								if (~arsh64_ack) begin
    									// arsh64_value <= { regs[dst][31:0], {32{regs[dst][31]}}};
                                            // error most prob
                                        arsh64_value <= {{32{regs[dst][31]}}, regs[dst][31:0]};
    									arsh64_shift <= immediate;
    									arsh64_arith <= 1;
    									arsh64_left <= 0;
    									arsh64_stb <= 1;
    								end
    								else begin
    									regs[dst] <= (arsh64_out  & 32'hffffffff);
    									arsh64_stb <= 0;
    									ip_next <= ip_next + 1;
    									ip <= ip_next;
    									instruction <= pgm_dat_r;
                                        state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                        state_next_temp <= state_next;
    								end
    							end // EBPF_OP_ARSH_IMM

                                    //https://github.com/m-labs/migen/blob/ccaee68e14d3636e1d8fb2e0864dd89b1b1f7384/migen/fhdl/structure.py#L244
                                    // Replicate a value
                                    //     An input value is replicated (repeated) several times
                                    //     to be used on the RHS of assignments::
                                    //         len(Replicate(s, n)) == len(s)*n
                                    //     Parameters
                                    //     ----------
                                    //     v : _Value, in
                                    //         Input value to be replicated.
                                    //     n : int
                                    //         Number of replications.
                                    //     Returns
                                    //     -------
                                    //     Replicate, out
                                    //         Replicated value.

    							// EBPF_OP_ARSH_REG
                                    // https://github.com/iovisor/bpf-docs/blob/master/eBPF.md
                                        // 32 bit
                                        // These instructions use only the lower 32 bits of their operands and zero the upper 32 bits of the destination register.
    							EBPF_OP_ARSH_REG: begin
    								if (~arsh64_ack) begin
    									// arsh64_value <= { regs[dst][31:0], {32{regs[dst][31]}}};
                                            // error most prob
                                        arsh64_value <= {{32{regs[dst][31]}}, regs[dst][31:0]};
    									arsh64_shift <= (regs[src] & 32'hffffffff);
    									arsh64_arith <= 1;
    									arsh64_left <= 0;
    									arsh64_stb <= 1;
    								end
    								else begin
    									regs[dst] <= (arsh64_out  & 32'hffffffff);
    									arsh64_stb <= 0;
    									ip_next <= ip_next + 1;
    									ip <= ip_next;
    									instruction <= pgm_dat_r;
                                        state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                        state_next_temp <= state_next;
    								end
    							end // EBPF_OP_ARSH_REG

    							// EBPF_OP_LSH_IMM
    							EBPF_OP_LSH_IMM: begin
    								if (~arsh64_ack) begin
    									arsh64_value <= (regs[dst] & 32'hffffffff);
    									arsh64_shift <= immediate;
    									arsh64_arith <= 0;
    									arsh64_left <= 1;
    									arsh64_stb <= 1;
    								end
    								else begin
    									regs[dst] <= (arsh64_out  & 32'hffffffff);
    									arsh64_stb <= 0;
    									ip_next <= ip_next + 1;
    									ip <= ip_next;
    									instruction <= pgm_dat_r;
                                        state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                        state_next_temp <= state_next;
    								end
    							end // EBPF_OP_LSH_IMM

    							// EBPF_OP_LSH_REG
    							EBPF_OP_LSH_REG: begin
    								if (~arsh64_ack) begin
    									arsh64_value <= (regs[dst] & 32'hffffffff);
    									arsh64_shift <= (regs[src] & 32'hffffffff);
    									arsh64_arith <= 0;
    									arsh64_left <= 1;
    									arsh64_stb <= 1;
    								end
    								else begin
    									regs[dst] <= (arsh64_out  & 32'hffffffff);
    									arsh64_stb <= 0;
    									ip_next <= ip_next + 1;
    									ip <= ip_next;
    									instruction <= pgm_dat_r;
                                        state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                        state_next_temp <= state_next;
    								end
    							end // EBPF_OP_LSH_REG

    							// EBPF_OP_RSH_IMM
    							EBPF_OP_RSH_IMM: begin
    								if (~arsh64_ack) begin
    									arsh64_value <= (regs[dst] & 32'hffffffff);
    									arsh64_shift <= immediate;
    									arsh64_arith <= 0;
    									arsh64_left <= 0;
    									arsh64_stb <= 1;
    								end
    								else begin
    									regs[dst] <= (arsh64_out  & 32'hffffffff);
    									arsh64_stb <= 0;
    									ip_next <= ip_next + 1;
    									ip <= ip_next;
    									instruction <= pgm_dat_r;
                                        state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                        state_next_temp <= STATE_DECODE;
    								end
    							end // EBPF_OP_RSH_IMM

    							// EBPF_OP_RSH_REG
    							EBPF_OP_RSH_REG: begin
    								if (~arsh64_ack) begin
    									arsh64_value <= (regs[dst] & 32'hffffffff);
    									arsh64_shift <= (regs[src] & 32'hffffffff);
    									arsh64_arith <= 0;
    									arsh64_left <= 0;
    									arsh64_stb <= 1;
    								end
    								else begin
    									regs[dst] <= (arsh64_out  & 32'hffffffff);
    									arsh64_stb <= 0;
    									ip_next <= ip_next + 1;
    									ip <= ip_next;
    									instruction <= pgm_dat_r;
                                        state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                        state_next_temp <= state_next;
    								end
    							end // EBPF_OP_RSH_REG

    							// default
    							default: begin

    								case (opcode)

    									// EBPF_OP_ADD_IMM
    									EBPF_OP_ADD_IMM: begin
    										regs[dst] <= ((regs[dst] + immediate) & 32'hffffffff);
    									end // EBPF_OP_ADD_IMM

    									// EBPF_OP_ADD_REG
    									EBPF_OP_ADD_REG: begin
    										regs[dst] <= ((regs[dst] + regs[src]) & 32'hffffffff);
    									end // EBPF_OP_ADD_REG

    									// EBPF_OP_SUB_IMM
    									EBPF_OP_SUB_IMM: begin
    										// regs[dst] <= ((regs[dst] + immediate) & 32'hffffffff);
                                                // error 
                                                // https://stackoverflow.com/questions/12399991/how-does-verilog-behave-with-negative-numbers
                                                    // rv_axi.v does this ==> alu_add_sub <= instr_sub ? reg_op1 - reg_op2 : reg_op1 + reg_op2;
                                                    // rv_axi.v does this ==> alu_lts <= $signed(reg_op1) < $signed(reg_op2);
                                            regs[dst] <= ((regs[dst] - immediate) & 32'hffffffff);
    									end // EBPF_OP_SUB_IMM

    									// EBPF_OP_SUB_REG
    									EBPF_OP_SUB_REG: begin
    										regs[dst] <= ((regs[dst] - regs[src]) & 32'hffffffff);
    									end // EBPF_OP_SUB_REG

    									// EBPF_OP_MUL_IMM
    									EBPF_OP_MUL_IMM: begin
    										regs[dst] <= ((regs[dst] * immediate) & 32'hffffffff);
    									end // EBPF_OP_MUL_IMM

    									// EBPF_OP_MUL_REG
    									EBPF_OP_MUL_REG: begin
    										regs[dst] <= ((regs[dst] * regs[src]) & 32'hffffffff);
    									end // EBPF_OP_MUL_REG

    									// EBPF_OP_OR_IMM
    									EBPF_OP_OR_IMM: begin
    										regs[dst] <= ((regs[dst] | immediate) & 32'hffffffff);
    									end // EBPF_OP_OR_IMM

    									// EBPF_OP_OR_REG
    									EBPF_OP_OR_REG: begin
    										regs[dst] <= ((regs[dst] | regs[src]) & 32'hffffffff);
    									end // EBPF_OP_OR_REG

    									// EBPF_OP_AND_IMM
    									EBPF_OP_AND_IMM: begin
    										regs[dst] <= ((regs[dst] & immediate) & 32'hffffffff);
    									end // EBPF_OP_AND_IMM

    									// EBPF_OP_AND_REG
    									EBPF_OP_AND_REG: begin
    										regs[dst] <= ((regs[dst] & regs[src]) & 32'hffffffff);
    									end // EBPF_OP_AND_REG

    									// EBPF_OP_NEG
    									EBPF_OP_NEG: begin
    										regs[dst] <= ((-regs[dst]) & 32'hffffffff);
    									end // EBPF_OP_NEG

    									// EBPF_OP_XOR_IMM
    									EBPF_OP_XOR_IMM: begin
    										regs[dst] <= ((regs[dst] ^ immediate) & 32'hffffffff);
    									end // EBPF_OP_XOR_IMM

    									// EBPF_OP_XOR_REG
    									EBPF_OP_XOR_REG: begin
    										regs[dst] <= ((regs[dst] ^ regs[src]) & 32'hffffffff);
    									end // EBPF_OP_XOR_REG

    									// EBPF_OP_MOV_IMM
    									EBPF_OP_MOV_IMM: begin  // 0xB4
    										regs[dst] <= immediate;
    									end // EBPF_OP_MOV_IMM

    									// EBPF_OP_MOV_REG
    									EBPF_OP_MOV_REG: begin
    										regs[dst] <= regs[src];
    									end // EBPF_OP_MOV_REG

    									// EBPF_OP_LE
    									EBPF_OP_LE: begin
                                            
                                            // https://linux.die.net/man/3/htobe16
                                                // so since this program is running on a little endian system,
                                                // hence htole shouldn't swap the bytes cx the memory is read and written
                                                // in L.E anyways
                                            // https://github.com/iovisor/bpf-docs/blob/master/eBPF.md

    										case (immediate)

    											// 16 bits EBPF_OP_LE
    											16: begin
    												// regs[dst] <= {regs[dst][7:0], regs[dst][15:8]};  // error? indexing correct?
                                                        // error most prob
                                                    regs[dst] <= {regs[dst][15:8], regs[dst][7:0]};  
    											end // 16 bits EBPF_OP_LE

    											// 32 bits EBPF_OP_LE
    											32: begin
    												// regs[dst] <= {regs[dst][7:0], regs[dst][15:8], regs[dst][23:16], regs[dst][31:24]};
                                                        // error most prob
                                                    regs[dst] <= {regs[dst][31:24], regs[dst][23:16],  regs[dst][15:8], regs[dst][7:0]};
    											end // 32 bits EBPF_OP_LE

    											// 64 bits EBPF_OP_LE
    											64: begin
    												// regs[dst] <= {regs[dst][7:0], regs[dst][15:8], regs[dst][23:16], regs[dst][31:24], regs[dst][39:32], regs[dst][47:40], regs[dst][55:48], regs[dst][63:56]};
                                                        // error most prob
                                                    regs[dst] <= {regs[dst][63:56], regs[dst][55:48], regs[dst][47:40], regs[dst][39:32], regs[dst][31:24], regs[dst][23:16], regs[dst][15:8], regs[dst][7:0]};
    											end // 64 bits EBPF_OP_LE

    											// default
    											default: begin
    												error <= 1;
    												halt <= 1;
                                                    debug_byte2 <= 8;
    											end // default
    											
    										endcase			
    									end // EBPF_OP_LE

    									// EBPF_OP_BE
                                        /*  Imp comments from cpu.py ..
                                             Hence error below was the Cat place the first argument in the LOWER bits, the code for BE
                                             here is placing first argument in the HIGHER bits.

                                        # https://github.com/m-labs/migen/blob/master/migen/fhdl/structure.py
                                            """Concatenate values
                                               Form a compound `_Value` from several smaller ones by concatenation.
                                               The first argument occupies the lower bits of the result.
                                               The return value can be used on either side of an assignment, that
                                               is, the concatenated value can be used as an argument on the RHS or
                                               as a target on the LHS. If it is used on the LHS, it must solely
                                               consist of `Signal` s, slices of `Signal` s, and other concatenations
                                               meeting these properties. The bit length of the return value is the sum of
                                               the bit lengths of the arguments::
                                                   len(Cat(args)) == sum(len(arg) for arg in args)
                                               Parameters
                                               ----------
                                               *args : _Values or iterables of _Values, inout
                                                   `_Value` s to be concatenated.
                                               Returns
                                               -------
                                               Cat, inout
                                                   Resulting `_Value` obtained by concatentation.

                                                Summary: So Cat puts the first argument on the lower bits of the result!!!!!
                                            """
                                            */
    									EBPF_OP_BE: begin

                                            // comments from EBPF_OP_LE:
                                                // https://linux.die.net/man/3/htobe16
                                                    // so since this program is running on a little endian system,
                                                    // hence htole shouldn't swap the bytes cx the memory is read and written
                                                    // in L.E anyways
                                                // https://github.com/iovisor/bpf-docs/blob/master/eBPF.md

    										case (immediate)

    											// 16 bits EBPF_OP_BE
    											16: begin
    												// regs[dst] <= {regs[dst][15:8], regs[dst][7:0]};
                                                        // error above
                                                    regs[dst] <= {regs[dst][7:0], regs[dst][15:8]};
    											end // 16 bits EBPF_OP_BE

    											// 32 bits EBPF_OP_BE
    											32: begin
    												// regs[dst] <= {regs[dst][31:24], regs[dst][23:16], regs[dst][15:8], regs[dst][7:0]};
                                                        // error above? Most prob, shifting the bytes for LE to BE
                                                    regs[dst] <= {regs[dst][7:0], regs[dst][15:8], regs[dst][23:16],  regs[dst][31:24]};
    											end // 32 bits EBPF_OP_BE

    											// 64 bits EBPF_OP_BE
    											64: begin
    												// regs[dst] <= {regs[dst][63:56], regs[dst][55:48], regs[dst][47:40], regs[dst][39:32], regs[dst][31:24], regs[dst][23:16], regs[dst][15:8], regs[dst][7:0]};
                                                        // error above? Most prob, shifting the bytes for LE to BE
                                                    regs[dst] <= {regs[dst][7:0], regs[dst][15:8], regs[dst][23:16], regs[dst][31:24], regs[dst][39:32], regs[dst][47:40], regs[dst][55:48], regs[dst][63:56]};
    											end // 64 bits EBPF_OP_BE

    											// default
    											default: begin
    												error <= 1;
    												halt <= 1;
                                                    debug_byte2 <= 9;
    											end // default
    											
    										endcase // immediate
    									end // EBPF_OP_BE

    									// default
    									default: begin
    										error <= 1;
    										halt <= 1;
                                            debug_byte2 <= 10;
    									end // default
    								endcase // opcode
    								ip_next <= ip_next + 1;
    								ip <= ip_next;
    								instruction <= pgm_dat_r;
                                    state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                    state_next_temp <= state_next;
    							end // default
    						endcase // opcode
    					end // OPC_ALU


    					// OPC_JMP
    					OPC_JMP: begin
    						case (opcode)

    							// EBPF_OP_CALL
    							EBPF_OP_CALL: begin
    								// call_handler_r1 <= r1;
    								// call_handler_r2 <= r2;
    								// call_handler_r3 <= r3;
    								// call_handler_r4 <= r4;
    								// call_handler_r5 <= r5;
                                        // error explained above before the if case(state) statement

                                    call_handler_r1 <= regs[1];
                                    call_handler_r2 <= regs[2];
                                    call_handler_r3 <= regs[3];
                                    call_handler_r4 <= regs[4];
                                    call_handler_r5 <= regs[5];

                                    
    								call_handler_func <= immediate;
    								call_handler_stb <= 1;
    								state_next <= STATE_CALL_PENDING;
    							end // EBPF_OP_CALL

    							// default
    							default: begin
    								state_next <= STATE_OP_FETCH;
    								case (opcode)

    									// EBPF_OP_JA
    									EBPF_OP_JA: begin
    										ip_next <= (ip_next + offset_s);
    									end // EBPF_OP_JA

    									// EBPF_OP_JEQ_IMM
    									EBPF_OP_JEQ_IMM: begin
    										if (regs[dst] == immediate) begin
    											ip_next <= (ip_next + offset_s);
                                                // ip_next <= 15;  // testing // entered here
    										end
    									end // EBPF_OP_JEQ_IMM

    									// EBPF_OP_JEQ_REG
    									EBPF_OP_JEQ_REG: begin
    										if (regs[dst] == regs[src]) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JEQ_REG

    									// EBPF_OP_JGT_IMM
    									EBPF_OP_JGT_IMM: begin
    										if (regs[dst] > immediate) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JGT_IMM

    									// EBPF_OP_JGT_REG
    									EBPF_OP_JGT_REG: begin
    										if (regs[dst] > regs[src]) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JGT_REG

    									// EBPF_OP_JGE_IMM
    									EBPF_OP_JGE_IMM: begin
    										if (regs[dst] >= immediate) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JGE_IMM

    									// EBPF_OP_JGE_REG
    									EBPF_OP_JGE_REG: begin
    										if (regs[dst] >= regs[src]) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JGE_REG

    									// EBPF_OP_JSET_IMM
    									EBPF_OP_JSET_IMM: begin
    										if (regs[dst] & immediate) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JSET_IMM

    									// EBPF_OP_JSET_REG
    									EBPF_OP_JSET_REG: begin
    										if (regs[dst] & regs[src]) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JSET_REG

    									// EBPF_OP_JNE_IMM
    									EBPF_OP_JNE_IMM: begin
    										if (regs[dst] != immediate) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JNE_IMM

    									// EBPF_OP_JNE_REG
    									EBPF_OP_JNE_REG: begin
    										if (regs[dst] != regs[src]) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JNE_REG

    									// EBPF_OP_JSGT_IMM
    									EBPF_OP_JSGT_IMM: begin
    										if (dst_reg_32_s > immediate_s) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JSGT_IMM

    									// EBPF_OP_JSGT_REG
    									EBPF_OP_JSGT_REG: begin
    										if (dst_reg_32_s > src_reg_32_s) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JSGT_REG

    									// EBPF_OP_JSGE_IMM
    									EBPF_OP_JSGE_IMM: begin
    										if (dst_reg_32_s >= immediate_s) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JSGE_IMM

    									// EBPF_OP_JSGE_REG
    									EBPF_OP_JSGE_REG: begin
    										if (dst_reg_32_s >= src_reg_32_s) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JSGE_REG

    									// EBPF_OP_EXIT
    									EBPF_OP_EXIT: begin
    										halt <= 1;
    									end // EBPF_OP_EXIT

    									// EBPF_OP_JLT_IMM
    									EBPF_OP_JLT_IMM: begin
    										// if (regs[dst] <= immediate) begin
                                                // error
                                            if (regs[dst] < immediate) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JLT_IMM

    									// EBPF_OP_JLT_REG
    									EBPF_OP_JLT_REG: begin
    										// if (regs[dst] <= regs[src]) begin
                                                // error
                                            if (regs[dst] < regs[src]) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JLT_REG

    									// EBPF_OP_JLE_IMM
    									EBPF_OP_JLE_IMM: begin
    										// if (regs[dst] < immediate) begin
                                                // error above
                                            if (regs[dst] <= immediate) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JLE_IMM

    									// EBPF_OP_JLE_REG
    									EBPF_OP_JLE_REG: begin
    										// if (regs[dst] < regs[src]) begin
                                                // error
                                            if (regs[dst] <= regs[src]) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JLE_REG

    									// EBPF_OP_JSLT_IMM
    									EBPF_OP_JSLT_IMM: begin
    										if (dst_reg_32_s < immediate_s) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JSLT_IMM

    									// EBPF_OP_JSLT_REG
    									EBPF_OP_JSLT_REG: begin
    										if (dst_reg_32_s < src_reg_32_s) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JSLT_REG

    									// EBPF_OP_JSLE_IMM
    									EBPF_OP_JSLE_IMM: begin
    										if (dst_reg_32_s <= immediate_s) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JSLE_IMM

    									// EBPF_OP_JSLE_REG
    									EBPF_OP_JSLE_REG: begin
    										if (dst_reg_32_s <= src_reg_32_s) begin
    											ip_next <= (ip_next + offset_s);
    										end
    									end // EBPF_OP_JSLE_REG

    									// default
    									default: begin
    										error <= 1;
    										halt <= 1;
                                            debug_byte2 <= 11;
    									end // default
    								endcase // opcode
    								ip <= ip_next;
    							end // default
    						endcase // opcode
    					end // OPC_JMP


    					// OPC_RES
    					OPC_RES: begin
    						error <= 1;
    						halt <= 1;
                            debug_byte2 <= 12;
    					end // OPC_RES


    					// OPC_ALU64
    					OPC_ALU64: begin
    						cpu_div64_ack <= 0;
                                // from migen file
                                    // OPC_ALU64: [
                                    //     div64_ack.eq(0),  
                                    // # equating to 0 before operation?.. is not line by line execution cx 
                                    // #its migen not python.. so what happens after that?, so first div64_ack is equated to 
                                    // # 0 first, then its value is checked
    						case (opcode)
    						
    							// EBPF_OP_DIV64_IMM
    							EBPF_OP_DIV64_IMM: begin
    								if (~cpu_div64_ack) begin
    									div64_dividend <= regs[dst];
    									div64_divisor <= immediate;
    									state_next <= STATE_DIV_PENDING;
    									div64_stb <= 1;
    								end else begin
    									regs[dst] <= div64_quotient;
    									ip_next <= ip_next + 1;
    									ip <= ip_next;
    									instruction <= pgm_dat_r;
                                        state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                        state_next_temp <= state_next;
    								end
    							end // EBPF_OP_DIV64_IMM

    							// EBPF_OP_DIV64_REG
    							EBPF_OP_DIV64_REG: begin
    								if (~cpu_div64_ack) begin
    									div64_dividend <= regs[dst];
    									div64_divisor <= regs[src];
    									state_next <= STATE_DIV_PENDING;
    									div64_stb <= 1;
    								end else begin
    									regs[dst] <= div64_quotient;
    									ip_next <= ip_next + 1;
    									ip <= ip_next;
    									instruction <= pgm_dat_r;
                                        state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                        state_next_temp <= state_next;
    								end
    							end // EBPF_OP_DIV64_REG

    							// EBPF_OP_MOD64_IMM
    							EBPF_OP_MOD64_IMM: begin
    								if (~cpu_div64_ack) begin
    									div64_dividend <= regs[dst];
    									div64_divisor <= immediate;
    									state_next <= STATE_DIV_PENDING;
    									div64_stb <= 1;
    								end else begin
    									regs[dst] <= div64_remainder;
    									ip_next <= ip_next + 1;
    									ip <= ip_next;
    									instruction <= pgm_dat_r;
                                        state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                        state_next_temp <= state_next;
    								end
    							end // EBPF_OP_MOD64_IMM

    							// EBPF_OP_MOD64_REG
    							EBPF_OP_MOD64_REG: begin
    								if (~cpu_div64_ack) begin
    									div64_dividend <= regs[dst];
    									div64_divisor <= regs[src];
    									state_next <= STATE_DIV_PENDING;
    									div64_stb <= 1;
    								end else begin
    									regs[dst] <= div64_remainder;
    									ip_next <= ip_next + 1;
    									ip <= ip_next;
    									instruction <= pgm_dat_r;
                                        state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                        state_next_temp <= state_next;
    								end
    							end // EBPF_OP_MOD64_REG

    							// EBPF_OP_ARSH64_IMM
    							EBPF_OP_ARSH64_IMM: begin
    								if (~arsh64_ack) begin
    									arsh64_value <= regs[dst];
    									arsh64_shift <= immediate;
    									arsh64_arith <= 1;
    									arsh64_left <= 0;
    									arsh64_stb <= 1;
    								end else begin
    									regs[dst] <= arsh64_out;
    									arsh64_stb <= 0;
    									ip_next <= ip_next + 1;
    									ip <= ip_next;
    									instruction <= pgm_dat_r;
                                        state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                        state_next_temp <= state_next;
    								end
    							end // EBPF_OP_ARSH64_IMM

    							// EBPF_OP_ARSH64_REG
    							EBPF_OP_ARSH64_REG: begin
    								if (~arsh64_ack) begin
    									arsh64_value <= regs[dst];
    									arsh64_shift <= regs[src];
    									arsh64_arith <= 1;
    									arsh64_left <= 0;
    									arsh64_stb <= 1;
    								end else begin
    									regs[dst] <= arsh64_out;
    									arsh64_stb <= 0;
    									ip_next <= ip_next + 1;
    									ip <= ip_next;
    									instruction <= pgm_dat_r;
                                        state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                        state_next_temp <= state_next;
    								end
    							end // EBPF_OP_ARSH64_REG

    							// EBPF_OP_LSH64_IMM
    							EBPF_OP_LSH64_IMM: begin
    								if (~arsh64_ack) begin
    									arsh64_value <= regs[dst];
    									arsh64_shift <= immediate;
    									arsh64_arith <= 0;
    									arsh64_left <= 1;
    									arsh64_stb <= 1;
    								end else begin
    									regs[dst] <= arsh64_out;
    									arsh64_stb <= 0;
    									ip_next <= ip_next + 1;
    									ip <= ip_next;
    									instruction <= pgm_dat_r;
                                        state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                        state_next_temp <= state_next;
    								end
    							end // EBPF_OP_LSH64_IMM

    							// EBPF_OP_LSH64_REG
    							EBPF_OP_LSH64_REG: begin
    								if (~arsh64_ack) begin
    									arsh64_value <= regs[dst];
    									arsh64_shift <= regs[src];
    									arsh64_arith <= 0;
    									arsh64_left <= 1;
    									arsh64_stb <= 1;
    								end else begin
    									regs[dst] <= arsh64_out;
    									arsh64_stb <= 0;
    									ip_next <= ip_next + 1;
    									ip <= ip_next;
    									instruction <= pgm_dat_r;
                                        state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                        state_next_temp <= state_next;
    								end
    							end // EBPF_OP_LSH64_REG

    							// EBPF_OP_RSH64_IMM
    							EBPF_OP_RSH64_IMM: begin
    								if (~arsh64_ack) begin
    									arsh64_value <= regs[dst];
    									arsh64_shift <= immediate;
    									arsh64_arith <= 0;
    									arsh64_left <= 0;
    									arsh64_stb <= 1;
    								end else begin
    									regs[dst] <= arsh64_out;
    									arsh64_stb <= 0;
    									ip_next <= ip_next + 1;
    									ip <= ip_next;
    									instruction <= pgm_dat_r;
                                        state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                        state_next_temp <= state_next;
    								end
    							end // EBPF_OP_RSH64_IMM

    							// EBPF_OP_RSH64_REG
    							EBPF_OP_RSH64_REG: begin
    								if (~arsh64_ack) begin
    									arsh64_value <= regs[dst];
    									arsh64_shift <= regs[src];
    									arsh64_arith <= 0;
    									arsh64_left <= 0;
    									arsh64_stb <= 1;
    								end else begin
    									regs[dst] <= arsh64_out;
    									arsh64_stb <= 0;
    									ip_next <= ip_next + 1;
    									ip <= ip_next;
    									instruction <= pgm_dat_r;
                                        state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                        state_next_temp <= state_next;
    								end
    							end // EBPF_OP_RSH64_REG

    							// default
    							default: begin
    								case (opcode)
    									// EBPF_OP_ADD64_IMM
    									EBPF_OP_ADD64_IMM: begin
    										regs[dst] <= (regs[dst] + immediate);
    									end // EBPF_OP_ADD64_IMM

    									// EBPF_OP_ADD64_REG
    									EBPF_OP_ADD64_REG: begin
    										regs[dst] <= (regs[dst] + regs[src]);
    									end // EBPF_OP_ADD64_REG

    									// EBPF_OP_SUB64_IMM
    									EBPF_OP_SUB64_IMM: begin
    										regs[dst] <= (regs[dst] - immediate);
    									end // EBPF_OP_SUB64_IMM

    									// EBPF_OP_SUB64_REG
    									EBPF_OP_SUB64_REG: begin
    										regs[dst] <= (regs[dst] - regs[src]);
    									end // EBPF_OP_SUB64_REG

    									// EBPF_OP_MUL64_IMM
    									EBPF_OP_MUL64_IMM: begin
    										regs[dst] <= (regs[dst] * immediate);
    									end // EBPF_OP_MUL64_IMM

    									// EBPF_OP_MUL64_REG
    									EBPF_OP_MUL64_REG: begin
    										regs[dst] <= (regs[dst] * regs[src]);
    									end // EBPF_OP_MUL64_REG

    									// EBPF_OP_OR64_IMM
    									EBPF_OP_OR64_IMM: begin
    										regs[dst] <= (regs[dst] | immediate);
    									end // EBPF_OP_OR64_IMM

    									// EBPF_OP_OR64_REG
    									EBPF_OP_OR64_REG: begin
    										regs[dst] <= (regs[dst] | regs[src]);
    									end // EBPF_OP_OR64_REG

    									// EBPF_OP_AND64_IMM
    									EBPF_OP_AND64_IMM: begin
    										regs[dst] <= (regs[dst] & immediate);
    									end // EBPF_OP_AND64_IMM

    									// EBPF_OP_AND64_REG
    									EBPF_OP_AND64_REG: begin
    										regs[dst] <= (regs[dst] & regs[src]);
    									end // EBPF_OP_AND64_REG

    									// EBPF_OP_NEG64
    									EBPF_OP_NEG64: begin
    										regs[dst] <= (-regs[src]);
    									end // EBPF_OP_NEG64

    									// EBPF_OP_XOR64_IMM
    									EBPF_OP_XOR64_IMM: begin
    										regs[dst] <= (regs[dst] ^ immediate);
    									end // EBPF_OP_XOR64_IMM

    									// EBPF_OP_XOR64_REG
    									EBPF_OP_XOR64_REG: begin
    										regs[dst] <= (regs[dst] ^ regs[src]);
    									end // EBPF_OP_XOR64_REG

    									// EBPF_OP_MOV64_IMM
    									EBPF_OP_MOV64_IMM: begin
    										regs[dst] <= immediate;
    									end // EBPF_OP_MOV64_IMM

    									// EBPF_OP_MOV64_REG
    									EBPF_OP_MOV64_REG: begin
    										regs[dst] <= regs[src];
    									end // EBPF_OP_MOV64_REG

    									// default
    									default: begin
    										error <= 1;
    										halt <= 1;
                                            debug_byte2 <= 13;
    									end // default
    								endcase // opcode
    								ip_next <= ip_next + 1;
    								ip <= ip_next;
    								instruction <= pgm_dat_r;
                                    state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                                    state_next_temp <= state_next;
    							end // default	
    						endcase // opcode
    					end // OPC_ALU64

    				endcase // opclass
    				cpu_data_ack <= 0;

    			end // STATE_DECODE


    			// STATE_DATA_FETCH
    			// Fetch from data memory
    			STATE_DATA_FETCH: begin
    				if (data_ack) begin
    					data_stb <= 0;
    					data_we <= 0;
    					state_next <= STATE_DECODE;
    					cpu_data_ack <= 1;
    				end
    				else begin
    					data_stb <= 1;
    				end
    			end // STATE_DATA_FETCH


    			// STATE_DIV_PENDING
    			// Exec math divide
    			STATE_DIV_PENDING: begin
    				if (div64_stb) begin
    					div64_stb <= 0;  // pulldown to 0 till divisoin is completed
    				end
    				else begin
    					if (div64_ack) begin
    						if (div64_err) begin
    							if ((opcode & 8'hf0) != EBPF_OP_MOD) begin
    								regs[dst] <= 8'h00;
    							end
    							error <= 1;
    							halt <= 1;
                                debug_byte2 <= 14;
    						end
    						else begin
    							state_next <= STATE_DECODE;
    							cpu_div64_ack <= 1;
    						end
    					end
    				end
    			end // STATE_DIV_PENDING


    			// STATE_CALL_PENDING
    			STATE_CALL_PENDING: begin
    				if (call_handler_ack) begin
                        call_handler_stb <= 0;
                        if (call_handler_err) begin
                            error <= 1;
                            halt <= 1;
                            debug_byte2 <= 15;
                        end
                        else begin
                        	regs[0] <= call_handler_ret;
                        	// state_next <= STATE_DECODE;  // transferred to state_next_temp due to 1 clk delay for fetching pgm memory
                        	ip_next <= ip_next + 1;
                        	ip <= ip_next;
                        	instruction <= pgm_dat_r;
                            state_next <= STATE_OP_FETCH_DELAY;  // 1 clk delay for fetching pgm memory
                            state_next_temp <= STATE_DECODE;
                        end
                    end
    			end // STATE_CALL_PENDING
    		endcase // state
        end  // else for if (halt) else
    end  // else for the if (rst) else
end // always block

// update state for next cycle
// always @(posedge clk) begin
// 	state<=state_next;
// end

endmodule