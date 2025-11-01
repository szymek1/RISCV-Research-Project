`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
// 
// Create Date: 06/13/2025 07:44:19 PM
// Design Name: 
// Module Name: control
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: Control module
// 
// Dependencies: rv32i_params.vh, rv32i_control.vh
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "../include/rv32i_params.vh"
`include "../include/rv32i_control.vh"


module control(
    // input                            clk,
    input                            rst,
    input  wire [`OPCODE_WIDTH-1:0]  opcode,
    input  wire [`FUNC3_WIDTH-1:0]   func3,
    input  wire [`FUNC7_WIDTH-1:0]   func7,
    input  wire                      alu_zero,              // input from ALU indicating whether beq/bne is taken 
    input  wire                      alu_last_bit,          // input from ALU indicating that results LSB equals to 1 
    output wire                      branch,                // if high then branch/jump
    output reg  [2:0]                imm_src,               // defines if immediate bits occupy [31:20] or are separated
    output reg                       mem_read,
    output reg                       mem_2_reg,
    output reg  [3:0]                alu_ctrl,
    output reg                       mem_write,
    output reg                       alu_src,
    output reg                       reg_write,
    output reg  [1:0]                wrt_back_src,
    output reg  [1:0]                second_add_src        // decide what to add to immediate:
                                                           // 2'b00: lui; 2'b01: auipc; 2'b10: rs1 + imm (for jalr)
    );
    
    /*
    TODO: allow for full clock synchronization, probably during switching to a pipelined version
          where intermediate registers will need to handle 1 clock delays.
    */
    reg [1:0] alu_op;
    reg is_branch;
    reg is_jump;
    always @(posedge rst) begin // posedge clk or posedge rst
        if (rst) begin
            mem_read              <= 1'b0;
            mem_2_reg             <= 1'b0;
            reg_write             <= 1'b0;
            is_branch             <= 1'b0;
            is_jump               <= 1'b0;
            imm_src               <= 3'b111; // do nothing
            mem_write             <= 1'b0;
            alu_src               <= 1'b0;
            alu_op                <= 2'b11; // Default ALU op
            second_add_src        <= `SEC_AS_NONE;
            wrt_back_src          <= 2'bxx;
        end 
        /*
        else begin
            case (opcode) 
            
            // `R_TYPE_OP: begin
            // end
            
            
            `LD_TYPE_OP: begin
                mem_read  = 1'b1;
                mem_2_reg = 1'b1;
                mem_write = 1'b0;
                alu_src   = 1'b1;
                reg_write = 1'b1; 
                alu_op    = `LD_SW_TYPE_ALU_OP;  
            end
            
            
            // `SD_TYPE_OP: begin
            // end
            
            
            
            // `BEQ_TYPE_OP: begin
            // end
            
            default: begin
                mem_read  = 1'b0;
                mem_2_reg = 1'b0;
                mem_write = 1'b0;
                alu_src   = 1'b0;
                reg_write = 1'b0;
            end
        endcase
        end
        */
    end

    // Opcode decoder
    always @(*) begin
        case (opcode) 
            
            // R-Type (add, sub, and, or)
            `R_TYPE_OP: begin
                is_branch             = 1'b0;
                is_jump               = 1'b0;
                imm_src               = 3'b111; // do nothing
                mem_read              = 1'b0;
                mem_2_reg             = 1'b0;
                mem_write             = 1'b0;
                alu_src               = 1'b0;
                reg_write             = 1'b1; 
                second_add_src        = `SEC_AS_NONE;
                wrt_back_src          = `ALU_RESULTS;
                alu_op                = `R_TYPE_ALU_OP;
            end
            
            // I-Type ALU (addi)
            `I_TYPE_ALU_OP: begin
                is_branch             = 1'b0;
                is_jump               = 1'b0;
                imm_src               = 3'b000; 
                mem_read              = 1'b0;
                mem_2_reg             = 1'b0;
                mem_write             = 1'b0;
                alu_src               = 1'b1;
                 
                // Invalidation of register write operation
                if (func3 == `F3_SLL) begin
                    reg_write = (func7 == `F7_SLL_SRL) ? 1'b1 : 1'b0;
                end else if (func3 == `F3_SRL_SRA) begin
                    reg_write = (func7 == `F7_SLL_SRL 
                               | func7 == `F7_SRA)     ? 1'b1 : 1'b0;
                end else begin
                    reg_write         = 1'b1;
                end

                second_add_src        = `SEC_AS_NONE;
                wrt_back_src          = `ALU_RESULTS;
                alu_op                = `ALU_I_TYPE_OP;
            end
            
            // I-Type (lw)
            `LD_TYPE_OP: begin
                is_branch             = 1'b0;
                is_jump               = 1'b0;
                imm_src               = 3'b000;
                mem_read              = 1'b1;
                mem_2_reg             = 1'b1;
                mem_write             = 1'b0;
                alu_src               = 1'b1;
                reg_write             = 1'b1; 
                second_add_src        = `SEC_AS_NONE;
                wrt_back_src          = `MEMORY_READ;
                alu_op                = `LD_SW_TYPE_ALU_OP;  
            end
            
            // S-Type (sd)
            `SD_TYPE_OP: begin
                is_branch             = 1'b0;
                is_jump               = 1'b0;
                imm_src               = 3'b001;
                mem_read              = 1'b0;
                mem_2_reg             = 1'b0;
                mem_write             = 1'b1;
                alu_src               = 1'b1;
                reg_write             = 1'b0; 
                second_add_src        = `SEC_AS_NONE;
                wrt_back_src          = 2'bxx;
                alu_op                = `LD_SW_TYPE_ALU_OP;
            end
            
            // B-Type (beq, blt, bltu, bge, bgeu, bnq)
            `BEQ_TYPE_OP: begin
                is_branch             = 1'b1;
                is_jump               = 1'b0;
                imm_src               = 3'b010;
                mem_read              = 1'b0;
                mem_2_reg             = 1'b0;
                mem_write             = 1'b0;
                alu_src               = 1'b0;
                reg_write             = 1'b0; 
                second_add_src        = `SEC_AS_AUIPC;
                wrt_back_src          = 2'bxx;
                alu_op                = `BEQ_TYPE_ALU_OP;
            end
            
            // J-Type (jal, jalr)
            `J_TYPE_OP, `J_TYPE_JALR_OP: begin
                is_branch             = 1'b0;
                is_jump               = 1'b1;
                mem_read              = 1'b0;
                mem_2_reg             = 1'b0;
                mem_write             = 1'b0;
                if (opcode[3] == 1'b1) begin
                    // jal
                    alu_src               = 1'b0;
                    second_add_src        = `SEC_AS_AUIPC;
                    imm_src               = 3'b011;
                    alu_op                = `J_TYPE_ALU_OP;
                end else begin
                    // jalr
                    alu_src               = 1'b1;
                    second_add_src        = `SEC_AS_JALR;
                    imm_src               = 3'b000;
                    alu_op                = `J_TYPE_ALU_OP;
                end
                
                reg_write             = 1'b1; 
                wrt_back_src           = `PC_PLUS_4;
            end
            
            // U-Type (lui, auipc)
            `U_TYPE_LUI_OP, `U_TYPE_AUIPC_OP: begin
                is_branch             = 1'b0;
                is_jump               = 1'b0;
                imm_src               = 3'b100;
                mem_read              = 1'b0;
                mem_2_reg             = 1'b0;
                mem_write             = 1'b0;
                alu_src               = 1'b1;
                reg_write             = 1'b1;
                if (opcode[5] == 1'b1) begin
                    second_add_src        = `SEC_AS_LUI;   // lui
                end else begin
                    second_add_src        = `SEC_AS_AUIPC; // auipc
                end
                wrt_back_src           = `U_TYPE_SEC_SRC;
                alu_op                 = `U_TYPE_ALU_OP;
            end
            
            default: begin
                is_branch             = 1'b0;
                is_jump               = 1'b0;
                imm_src               = 3'b111; // do nothing
                mem_read              = 1'b0;
                mem_2_reg             = 1'b0;
                mem_write             = 1'b0;
                alu_src               = 1'b0;
                reg_write             = 1'b0;
                second_add_src        = `SEC_AS_NONE;
                wrt_back_src          = 2'bxx;
            end
        endcase
    end

    // ALUop decoder
    always @(*) begin
        case(alu_op)
            
            `R_TYPE_ALU_OP, `ALU_I_TYPE_OP: begin
                case (func3)
                    `F3_ADD_SUB: begin
                        case (opcode) // Select the right ALU operation: add and addi belong to different types
                            `R_TYPE_OP    : alu_ctrl = (func7 == `F7_SUB) ? `SUBTRACT : `ADD; // R-Type
                            `I_TYPE_ALU_OP: alu_ctrl = `ADD;                                  // I-Type ALU
                        endcase
                    end
                    
                    `F3_ALU_XOR  : alu_ctrl = `ALU_XOR;
                    `F3_ALU_SLTIU: alu_ctrl = `ALU_SLTIU_CMP;
                    `F3_ALU_SLTI : alu_ctrl = `ALU_SLTI_CMP;
                    `F3_ALU_AND  : alu_ctrl = `ALU_AND;
                    `F3_ALU_OR   : alu_ctrl = `ALU_OR;
                    `F3_SLL      : alu_ctrl = `ALU_SLL;
                    `F3_SRL_SRA  : begin
                        if (func7 == `F7_SLL_SRL) begin
                            alu_ctrl = `ALU_SRL;
                        end else if (func7 == `F7_SRA) begin
                            alu_ctrl = `ALU_SRA;
                        end
                    end
                    
                    default     : alu_ctrl = `NOP; // all the rest for now
                endcase
            end
            
            `LD_SW_TYPE_ALU_OP: alu_ctrl = `ADD;
           
            // `BEQ_TYPE_ALU_OP  : alu_ctrl = `SUBTRACT;
            `BEQ_TYPE_ALU_OP  : begin
                case (func3)
                    `F3_BEQ, `F3_BNE  : alu_ctrl = `SUBTRACT;
                    `F3_BLT, `F3_BGE  : alu_ctrl = `ALU_SLTI_CMP;
                    `F3_BLTU, `F3_BGEU: alu_ctrl = `ALU_SLTIU_CMP;
                endcase
            end
            
            `J_TYPE_ALU_OP    : alu_ctrl = `NOP;
            
            `U_TYPE_ALU_OP    : alu_ctrl = `NOP;
             
            default           : alu_ctrl = `NOP;
        endcase
    end
    
    // Branch decoder
    reg branch_taken;
    always @(*) begin
        case (func3)
            `F3_BEQ : branch_taken = is_branch & alu_zero;
            `F3_BNE : branch_taken = is_branch & ~alu_zero;
            `F3_BLT : branch_taken = is_branch & alu_last_bit;
            `F3_BLTU: branch_taken = is_branch & alu_last_bit;
            `F3_BGE : branch_taken = is_branch & ~alu_last_bit;
            `F3_BGEU: branch_taken = is_branch & ~alu_last_bit;
            default : branch_taken = 1'b0; // all the rest for now
        endcase
    end
    
    assign branch = branch_taken | is_jump;
    
endmodule
