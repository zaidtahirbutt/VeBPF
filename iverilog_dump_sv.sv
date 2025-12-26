module iverilog_dump_sv # 
(

parameter WIDTH_OF_STRING = 8192,
parameter STRING_SIZE = 255,
parameter MAX_REGS = 11,
parameter TEST_NUMBER = 19,
parameter VEBPF_SIM = 0

)(
input clk
);

logic [WIDTH_OF_STRING-1:0] my_string = 0;
logic debug_flag = 0;
logic debug_flag2 = 0;

string myString = "HELLO.fst";
integer xyz;

integer idx;
initial begin
  
  debug_flag2 = 0;

end

generate
  if(VEBPF_SIM) begin 
    always_comb
    begin
      if (debug_flag) 
      begin  
        $sformat(myString, "%0s", my_string);
        $dumpfile(myString);
        // whole cpu.v nets to be dumped in sim waveform
        $dumpvars(0, cpu);  
        for (idx = 0; idx < 16; idx = idx + 1) begin
          $dumpvars(0, cpu.pgm.mem[idx]);
        end
        for (idx = 0; idx < 16; idx = idx + 1) begin
          $dumpvars(0, cpu.data_mem.mem[idx]);
        end
        for (idx = 0; idx < MAX_REGS; idx = idx + 1) begin
          $dumpvars(0, cpu.regs[idx]);
        end
      end
    end
  end
endgenerate

endmodule
