`ifndef RV32I_CONTROL_V
`define RV32I_CONTROL_V

// RV32I Processor Control Module Opcodes
// Main Control

// Opcodes
// For all 32 bit instructions: instr[1:0] = 2'b11
`define OPCODE_WIDTH       7     // 7 bits of an instruction dedicated to an opcode
`define OPCODE_LOAD        7'b0000011 // I Type
`define OPCODE_OP_IMM      7'b0010011 // I Type
`define OPCODE_AUIPC       7'b0010111 // U Type
`define OPCODE_STORE       7'b0100011 // S Type
`define OPCODE_OP          7'b0110011 // R Type
`define OPCODE_LUI         7'b0110111 // U Type
`define OPCODE_BRANCH      7'b1100011 // B Type
`define OPCODE_JALR        7'b1100111 // I Type
`define OPCODE_JAL         7'b1101111 // J Type

// Func3 field
`define FUNC3_WIDTH        3
// OP / OP-IMM
`define F3_ADD_SUB         3'b000
`define F3_SLL             3'b001
`define F3_SLTI            3'b010
`define F3_SLTIU           3'b011
`define F3_XOR             3'b100
`define F3_SRL_SRA         3'b101
`define F3_OR              3'b110
`define F3_AND             3'b111
// JALR
`define F3_JALR            3'b000
// LOAD / STORE
`define F3_BYTE            3'b000
`define F3_HALF_WORD       3'b001
`define F3_WORD            3'b010
`define F3_BYTE_U          3'b100
`define F3_HALF_WORD_U     3'b101
// BRANCH
`define F3_BEQ             3'b000
`define F3_BNE             3'b001
`define F3_BLT             3'b100
`define F3_BGE             3'b101
`define F3_BLTU            3'b110
`define F3_BGEU            3'b111

// Func7 field
`define FUNC7_WIDTH        7
`define F7_ADD_AND_OR      7'b0000000
`define F7_SUB             7'b0100000
`define F7_SLL_SRL         7'b0000000
`define F7_SRA             7'b0100000

// Instruction type (used inside the decoder)
`define INSTR_TYPE_WIDTH   3
`define INSTR_TYPE_INVALID 3'b000
`define INSTR_TYPE_R       3'b001
`define INSTR_TYPE_I       3'b010
`define INSTR_TYPE_S       3'b011
`define INSTR_TYPE_B       3'b100
`define INSTR_TYPE_U       3'b101
`define INSTR_TYPE_J       3'b110

// ALU Control
// (chosen so that the lower 3 bits match Func3 for OP and OP-IMM)
// for OP, OP-IMM: {0, func7[5], func3}
// for BRANCH:     {1, 0,        func3}
// MISC:           {1, 1,        xxx}
`define ALU_CTRL_WIDTH     5
`define ALU_CTRL_ADD       {1'b0, 1'b0, `F3_ADD_SUB}
`define ALU_CTRL_NOP       5'b11111

`endif
