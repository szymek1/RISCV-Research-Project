`ifndef RV32I_CONTROL_V
`define RV32I_CONTROL_V

// RV32I Processor Control Module Opcodes
// Main Control
`define OPCODE_WIDTH       7     // 7 bits of an instruction dedicated to an opcode
`define FUNC3_WIDTH        3
`define FUNC7_WIDTH        7

// Opcodes
`define R_TYPE_OP          7'b0110011
`define LD_TYPE_OP         7'b0000011
`define SD_TYPE_OP         7'b0100011
`define BEQ_TYPE_OP        7'b1100011
`define J_TYPE_OP          7'b1101111
`define J_TYPE_JALR_OP     7'b1100111
`define I_TYPE_ALU_OP      7'b0010011
`define U_TYPE_LUI_OP      7'b0110111
`define U_TYPE_AUIPC_OP    7'b0010111 

// ALUop
`define R_TYPE_ALU_OP      2'b10 // R Type instruction  
`define ALU_I_TYPE_OP      2'b10 // I Type ALU instruction  
`define LD_SW_TYPE_ALU_OP  2'b00 // I and S Type instruction
`define J_TYPE_ALU_OP      2'b11 // J Type instruction
`define BEQ_TYPE_ALU_OP    2'b01 // B Type instruction
`define U_TYPE_ALU_OP      2'b11 // U Type instruction

// ALU Control
`define ADD                4'b0010
`define SUBTRACT           4'b0110
`define ALU_AND            4'b0000
`define ALU_OR             4'b0001
`define ALU_XOR            4'b1000
`define ALU_SLTI_CMP       4'b0101
`define ALU_SLTIU_CMP      4'b0111
`define NOP                4'b1111
`define ALU_SLL            4'b0100
`define ALU_SRL            4'b0011
`define ALU_SRA            4'b1001

// Write back options
`define MEMORY_READ        2'b01
`define ALU_RESULTS        2'b00
`define PC_PLUS_4          2'b10
`define U_TYPE_SEC_SRC     2'b11

// Func3 field
`define F3_ADD_SUB         3'b000
`define F3_ALU_AND         3'b111
`define F3_ALU_OR          3'b110
`define F3_ALU_SLTI        3'b010
`define F3_ALU_SLTIU       3'b011
`define F3_ALU_XOR         3'b100
`define F3_SLL             3'b001
`define F3_SRL_SRA         3'b101
`define F3_JALR            3'b000
`define F3_BYTE            3'b000
`define F3_HALF_WORD       3'b001
`define F3_SW              3'b010
`define F3_LW              3'b010
`define F3_LBU             3'b100
`define F3_LHU             3'b101

// Func3 field- branch decoder
`define F3_BEQ             3'b000
`define F3_BNE             3'b001
`define F3_BLT             3'b100   
`define F3_BLTU            3'b110
`define F3_BGE             3'b101
`define F3_BGEU            3'b111

// Func7 field
`define F7_ADD_AND_OR      7'b0000000
`define F7_SUB             7'b0100000
`define F7_SLL_SRL         7'b0000000
`define F7_SRA             7'b0100000

// Second add source (assigned from control module)
`define SEC_AS_AUIPC       2'b00
`define SEC_AS_LUI         2'b01
`define SEC_AS_JALR        2'b10
`define SEC_AS_NONE        2'b11

`endif