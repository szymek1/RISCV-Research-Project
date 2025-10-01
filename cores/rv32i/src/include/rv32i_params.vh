`ifndef RV32I_PARAMS_V
`define RV32I_PARAMS_V

// RV32I Processor Parameters
// General
`define BOOT_ADDR         32'h0000_0000  // Boot address (start of instruction memory)
`define TRAP_VECTOR       32'h0000_1000  // Trap vector for exceptions (e.g., illegal instruction)
`define INSTR_WIDTH       32             // Instruction width in bits
`define REG_ADDR_WIDTH    5              // Register address width (32 registers)
`define DATA_WIDTH        32             // Data width for registers and memory
`define PC_STEP           32'h4          // PC increment for sequential fetch
`define I_BRAM_DEPTH      1024           // Instruction BRAM depth
`define BYTES_PER_WORD    4              // Each 32-bit word contains 4 bytes

// Testbench
// relative paths for hex files
`define RISCV_PROGRAMS    "../../../data/"

`endif