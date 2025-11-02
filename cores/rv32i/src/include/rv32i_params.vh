`ifndef RV32I_PARAMS_V
`define RV32I_PARAMS_V

// RV32I Processor Parameters
// General
`define BOOT_ADDR         32'h0000_0000  // Boot address (start of instruction memory)
`define TRAP_VECTOR       32'h0000_1000  // Trap vector for exceptions (e.g., illegal instruction)

`define INSTR_WIDTH       32             // Instruction width in bits
`define NUM_REGISTERS     32             // Number of registers
`define REG_ADDR_WIDTH    5              // Register address width (32 registers)
`define DATA_WIDTH        32             // Data width for registers and memory
`define PC_STEP           32'h4          // PC increment for sequential fetch
`define BYTES_PER_WORD    4              // Each 32-bit word contains 4 bytes

// RAM size
`define I_BRAM_DEPTH      1024           // Number of words in RAM (instruction and data)
`define RAM_ADDR_WIDTH ($clog2(`I_BRAM_DEPTH) + $clog2(`BYTES_PER_WORD))

// DATA_DIR points to the location of the data folder.
// Since in Vivado xsim, relative paths are interpreted relative to its
// "xsim.dir" rather than the file's location, DATA_DIR needs to be set using a
// -define directive in xvlog (part of simulate.tcl).
`ifndef DATA_DIR
`define DATA_DIR "../../data/"
`endif

`endif