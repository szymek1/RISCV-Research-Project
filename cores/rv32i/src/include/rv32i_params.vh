`ifndef RV32I_PARAMS_VH
`define RV32I_PARAMS_VH

// RV32I Processor Parameters
// General
`define BOOT_ADDR 32'h0000_1000  // Boot address (start of instruction memory)
`define TRAP_VECTOR 32'h0000_1000  // Trap vector for exceptions (e.g., illegal instruction)

`define INSTR_WIDTH 32             // Instruction width in bits
`define NUM_REGISTERS 32             // Number of registers
`define REG_ADDR_WIDTH 5              // Register address width (32 registers)
`define DATA_WIDTH 32             // Data width for registers and memory
`define PC_STEP 32'h4          // PC increment for sequential fetch
`define BYTES_PER_WORD 4              // Each 32-bit word contains 4 bytes

`endif
