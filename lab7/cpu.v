
// Constants for the nsel possible values
`define RN 3'b100
`define RD 3'b010
`define RM 3'b001

module cpu(clk,
           reset,
           write_data,
           N,
           V,
           Z,
           w,
           mem_addr,
           mem_cmd,
           read_data);
  input clk, reset;
  output N, V, Z, w;
  // Do not change above this line.
  
  // instruction decoder stuff
  wire [15:0] instruction,sximm5, sximm8;
  wire [2:0] nsel,  opcode, readnum, writenum;
  wire [1:0] ALUop, op, shift;
  
  // datapath wires
  wire [3:0] vsel;
  wire [15:0] mdata;
  wire [8:0] PC;
  wire write, loada, loadb, loadc, loads, asel, bsel;
  
  //Lab7 FSM new stuff
  output [8:0] mem_addr;
  output [1:0] mem_cmd;
  output [15:0] write_data;
  input [15:0] read_data;
  wire load_pc, load_ir, reset_pc, addr_sel, m_cmd;
  wire load_addr;
  
  //Data Address declarations
  wire [8:0] dataAddressOut;
 
  //set to zero for lab6 only
  
  // Datapath instantiation with dot notation
  datapath DP(
  .clk(clk),
  .readnum(readnum),
  .vsel(vsel),
  .loada(loada),
  .loadb(loadb),
  .shift(shift),
  .asel(asel),
  .bsel(bsel),
  .ALUop(ALUop),
  .loadc(loadc),
  .loads(loads),
  .writenum(writenum),
  .write(write),
  .datapath_in(sximm8),
  .sximm5(sximm5),
  .mdata(read_data),
  .PC(PC),
  .Z_out(Z),
  .V_out(V),
  .N_out(N),
  .datapath_out(write_data));
  
  // Instruction register without dot notation
  regLoad #(16) instructionRegister(clk, load_ir, read_data, instruction);
  
  // Instruction decoder instantiation with dot notation
  instructionDecoder instructionDecoded(
  .nsel(nsel),
  .instruction(instruction),
  .ALUop(ALUop),
  .sximm5(sximm5),
  .sximm8(sximm8),
  .readnum(readnum),
  .writenum(writenum),
  .opcode(opcode),
  .op(op),
  .shift(shift));

  // Instantiates the datapath controller FSM using dot notation
  InstructionSM FSM(.clk(clk),
                     .reset(reset),
                    .w(w), 		//May also have to delete unsure
                     .nsel(nsel),
                     .loada(loada),
                     .loadb(loadb),
                     .loadc(loadc),
                     .loads(loads),
                     .vsel(vsel),
                     .write(write),
                     .opcode(opcode),
                     .op(op),
                     .asel(asel),
                    .bsel(bsel),      
                    .addr_sel(addr_sel),
                    .load_pc(load_pc),
                    .reset_pc(reset_pc),
                    .load_ir(load_ir),
                    .m_cmd(mem_cmd),
                    .load_addr(load_addr)
                   );
  
  //Instantiates entire Program Counter, which includes the adding and the mux
  ProgramCounter #(9) pc(clk, reset_pc, load_pc, PC);
  
  //Data Address vDFF
  regLoad #(9) dataAddress(clk, load_addr, write_data[8:0], dataAddressOut);
  
  //takes output of Program Counter and 0's and mux them based on addr_sel
  assign mem_addr = addr_sel ? PC : dataAddressOut;

  
endmodule
  
  
  module instructionDecoder(nsel, instruction, ALUop, sximm5, sximm8, readnum, writenum, opcode, op, shift);
    input [15:0] instruction;
    input[2:0] nsel;
    output [1:0] ALUop, op, shift;
    output[2:0] opcode, readnum, writenum;
    output[15:0] sximm5, sximm8;
    
    // Determines readnum based on which register is selected by nsel: Rd, Rn, or Rm
    Mux3 #(3) regNum(instruction[2:0], instruction[7:5], instruction[10:8], nsel, readnum);
    // Since writenum is the same as readnum, we assign them together
    assign writenum = readnum;
    // The ALU operation is bits 12 and 11 no matter what category of operation we're in, so we feed it directly into the ALU
    assign ALUop   = instruction[12:11];
    // The shift is set directly by bits 4 and 3 of the instruction
    assign shift   = instruction[4:3];
    // sximm5 is the 16 bit sign extended version of the first 5 bits of instruction
    assign sximm5  = {{11{instruction[4]}}, instruction[4:0]};
    // sximm8 is the 16 bit sign extended version of the first 8 bits of instruction
    assign sximm8  = {{8{instruction[7]}}, instruction[7:0]};
    // The opcode is the category of operation
    assign opcode  = instruction[15:13];
    // The op determines the operation within the category given by opcode
    assign op = instruction[12:11];
    
    
  endmodule
    
    // multiplexer 3 inputs, one-hot select, variable width input/output
    module Mux3(r0, r1, r2, sel, out);
      parameter n = 1;
      input [n-1:0] r0, r1, r2;
      input [2:0] sel;
      output [n-1:0] out;
      reg [n-1:0] out;
      
      // using basis from SS6 slide 21, always block for output of mux based on one-hot sel
      always @(*) begin
        case(sel) // case statement is based on the one-hot select signal
          3'b001: out  = r0;
          3'b010: out  = r1;
          3'b100: out  = r2;
          default: out = {n{1'bx}}; // default is a output of all "don't cares" for debugging purposes
        endcase
      end
    endmodule


//PROGRAM COUNTER 
module ProgramCounter(clk, reset_pc, load_pc, PC) ;
  parameter n=5 ;
  input reset_pc, clk ; // reset and clock
  output [n-1:0] PC ;
  input load_pc;
  wire [n-1:0] next_pc;

  assign next_pc = reset_pc ? 9'b0 : PC + 1'b1;

  vDFFPC #(n) counter(clk, load_pc, next_pc, PC) ;
endmodule

// FLIP FLOP MODULE FOR THE PC COUNTER 
module vDFFPC (clk, load_pc, next_pc, PC);
  parameter n = 1; // width
  input clk, load_pc; 
  input [n-1:0] next_pc;
  output reg [n-1:0] PC;
  
  always @(posedge clk) begin
      if (load_pc === 1)
        PC <= next_pc;
  end
endmodule
  
