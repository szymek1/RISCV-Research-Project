`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
// 
// Create Date: 06/13/2025 05:19:21 PM
// Design Name: 
// Module Name: alu
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: ALU with IGNORED overflow detection.
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


module alu(
    input  wire [3:0]              alu_ctrl,    // 2-bit long alu opcode provided by the main control module
    input  wire                    alu_src,     // 1-bit indicating if the second source comes from the regfile or sign_extend module
    input  wire [`INSTR_WIDTH-1:0] src1,        // 1st source (from regfile)
    input  wire [`INSTR_WIDTH-1:0] src2,        // 2nd source (from regfile)
    input  wire [`INSTR_WIDTH-1:0] sign_ext,    // signe_extend module input (selected if alu_src is high) 
    output reg  [`INSTR_WIDTH-1:0] results,  
    output wire                    zero,        // comparison results (for branch evaluation)
    output wire                    res_last_bit // set to 1, if the LSB of the result is 1
    // Debug outputs
    // output wire [4:0]              shamt
    );
    
    wire [`INSTR_WIDTH-1:0] src2_internal = alu_src ? sign_ext : src2;
    wire [4:0]              shamt         = src2_internal[4:0];

    // For debug purposes
    // assign shamt = src2_internal[4:0];
    always @(*) begin
         case (alu_ctrl)            
            `ADD          : results = src1 + src2_internal;
            `SUBTRACT     : results = src1 - src2_internal;
            `ALU_AND      : results = src1 & src2_internal;
            `ALU_OR       : results = src1 | src2_internal;
            `ALU_XOR      : results = src1 ^ src2_internal;
            `ALU_SLTI_CMP : results = {31'b0, $signed(src1) < $signed(src2_internal)};
            `ALU_SLTIU_CMP: results = {31'b0, src1 < src2_internal};
            `ALU_SLL      : results = src1 << shamt;
            `ALU_SRL      : results = src1 >> shamt;
            `ALU_SRA      : results = $signed(src1) >>> shamt;
            default       : results = 32'h0;
         endcase
    end
    
    assign zero         = (results == 32'h0) ? 1'b1 : 1'b0; // set high if zero
    assign res_last_bit = results[0];
    
endmodule
