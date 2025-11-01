`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
// 
// Create Date: 06/14/2025 07:39:41 PM
// Design Name: 
// Module Name: riscv_cpu
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: Main module assembling entire core
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


module riscv_cpu(
    input clk,
    input rst
    );
    
    // =====   Fetch stage   =====
    wire [`DATA_WIDTH-1:0]  pc_out;
    wire [`DATA_WIDTH-1:0]  pc_plus_4;       // used for returning from a jump
    wire                    branch;          // provided by control module- branch decoder
    wire [`INSTR_WIDTH-1:0] immediate;       // provided by sign_extend module
    reg  [`INSTR_WIDTH-1:0] pc_plus_sec_src; // provided by sequential block, which 
                                             // decodes second_add_src from control module

    pc PC(
        .clk(clk),
        .rst(rst),
        .stall(pc_stall),
        .pc_select(branch),
        .pc_in(pc_plus_sec_src),
        .pc_out(pc_out),
        .pc_plus_4(pc_plus_4)
    );
    
    wire [`DATA_WIDTH-1:0] instruction;
    wire [3:0]             i_w_byte_enb;
    bram32 I_MEM( // Instruction BRAM
        .clk(clk),
        .rst(rst),
        // Write ports inputs
        .w_addr(i_w_addr),
        .w_dat(i_w_dat),
        .w_enb(i_w_enb),
        .byte_enb(i_w_byte_enb),
        // Read ports inputs
        .r_addr(pc_out),
        .r_enb(i_r_enb),
        // Outputs
        .r_dat(instruction)
    );
    // =====   Fetch stage   =====
    // =====   Decode stage   =====
    wire                      alu_zero;
    wire                      alu_last_bit;
    wire [`OPCODE_WIDTH-1:0]  opcode;
    assign opcode =           instruction[6:0];
    
    wire [`FUNC3_WIDTH-1:0]   func3;
    assign func3 =            instruction[14:12];
    
    wire [`FUNC7_WIDTH-1:0]   func7;
    assign func7 = instruction[`DATA_WIDTH-1:25];
    
    // Control module outputs
    wire [2:0]                imm_src;
    wire                      mem_read;
    wire                      mem_2_reg;
    wire [3:0]                alu_ctrl;
    wire                      mem_write;
    wire                      alu_src;
    wire                      reg_write;
    wire [1:0]                wrt_back_src;
    wire [1:0]                second_add_src;
    
    control CONTROL(
        // .clk(clk),
        .rst(rst),
        .opcode(opcode),
        .func3(func3),
        .func7(func7),
        .alu_zero(alu_zero),
        .alu_last_bit(alu_last_bit),
        .branch(branch),
        .imm_src(imm_src),
        .mem_read(mem_read),
        .mem_2_reg(mem_2_reg),
        .alu_ctrl(alu_ctrl),
        .mem_write(mem_write),
        .alu_src(alu_src),
        .reg_write(reg_write),
        .wrt_back_src(wrt_back_src),
        .second_add_src(second_add_src)
    );
    
    // Register file
    wire [`REG_ADDR_WIDTH-1:0] rs1_addr;
    assign rs1_addr =          instruction[19:15];
    
    wire [`REG_ADDR_WIDTH-1:0] rs2_addr;
    assign rs2_addr =          instruction[24:20];
    
    wire                       rd_enbl;
    
    wire [`DATA_WIDTH-1:0]     rs1;
    wire [`DATA_WIDTH-1:0]     rs2;
    
    wire [`REG_ADDR_WIDTH-1:0] wrt_addr;
    assign wrt_addr =          instruction[11:7];
    reg [`DATA_WIDTH-1:0]      wrt_dat; // connect with data memory module
    wire [`DATA_WIDTH-1:0]     data_bram_output;

    wire [`DATA_WIDTH-1:0] mem_wb_data; // from byte_reader
    wire                   mem_valid;   // from byte_reader
    reg                    wb_valid;    // has to be set high after every write back operation
    
    // Block dedicated to deciding what should be the output to write back to register file.
    // It changes accordingly to a current instruction: reading from data BRAM, register-to-register
    // or saving pc before the jump.
    wire [`INSTR_WIDTH-1:0]    alu_results;
    reg  [`DATA_WIDTH-1:0]     wrt_back_data;
    always @(*) begin
        case (wrt_back_src)
            `MEMORY_READ   : begin
                wrt_back_data = mem_wb_data;
                wb_valid      = mem_valid;
            end
            `ALU_RESULTS   : begin
                wrt_back_data = alu_results;
                wb_valid      = 1'b1;
            end
            `PC_PLUS_4     : begin
                wrt_back_data = pc_plus_4;
                wb_valid      = 1'b1;
            end
            `U_TYPE_SEC_SRC: begin
                wrt_back_data = pc_plus_sec_src;
                wb_valid      = 1'b1;
            end
        endcase
    end
    
    // Block dedicated U-Type instruction handling.
    // Regfile will be updated with a value either:
    // lui  : immediate 20 bits shifted left by 12
    // auipc: immediate 20 bits shifted left by 12 + current pc
    // jalr : sign-extended 12-bit imm12 to the register rs1
    always @(*) begin
        case (second_add_src)
            `SEC_AS_LUI  : pc_plus_sec_src = immediate;                           // lui
            `SEC_AS_AUIPC: pc_plus_sec_src = pc_out + immediate;                  // auipc
            `SEC_AS_JALR : pc_plus_sec_src = (rs1 + immediate) & 32'hFFFFFFFE;    // jalr
            `SEC_AS_NONE : pc_plus_sec_src = 32'b0;                               // do nothing
        endcase
    end
    
    register_file REGFILE(
        .clk(clk),
        .rst(rst),
        .read_enable(rd_enbl),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rs1(rs1),
        .rs2(rs2),
        .write_enable(reg_write & wb_valid),
        .write_addr(wrt_addr),
        .write_data(wrt_back_data)                      
    );
    // =====   Decode stage   =====
    // =====   Execute stage   =====
    // Sign extension
    wire [24:0]                instr_imm;
    assign instr_imm =         instruction[`INSTR_WIDTH-1:7];
    
    sign_extend SIGN_EXTENSION(
        .src(instr_imm),
        .imm_src(imm_src),
        .imm_signed(immediate)
    );
    
    alu ALU(
        .alu_ctrl(alu_ctrl),  // provided by control module
        .alu_src(alu_src),    // provided by control module
        .src1(rs1),           // provided by regfile
        .src2(rs2),           // provided by regfile
        .sign_ext(immediate), // provided by sign_extend
        .results(alu_results),
        .zero(alu_zero),    
        .res_last_bit(alu_last_bit)               
    );

    wire [3:0]             byte_enb;
    wire [`DATA_WIDTH-1:0] mem_write_data;
    load_store_decoder LOAD_STORE_DECODER(
        .alu_result_addr(alu_results),
        .func3(func3),
        .reg_read(rs2),
        .byte_enb(byte_enb),
        .data(mem_write_data)
    );

    // =====   Execute stage   =====
    // =====   Memory stage   =====
    bram32 D_MEM( // Data BRAM
        .clk(clk),
        .rst(rst),
        // Write ports inputs
        .w_addr({alu_results[31:2], 2'b00}),
        .w_dat(mem_write_data),
        .w_enb(mem_write),
        .byte_enb(byte_enb),
        // Read ports inputs
        .r_addr(alu_results),
        .r_enb(mem_read),
        // Outputs
        .r_dat(data_bram_output)
    );

    byte_reader BYTE_READER(
        .mem_data(data_bram_output),
        .func3(func3),
        .byte_mask(byte_enb),
        .wb_data(mem_wb_data),
        .valid(mem_valid)
    );
    // =====   Memory stage   =====
    
endmodule
