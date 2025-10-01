`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
// 
// Create Date: 06/13/2025 06:15:19 PM
// Design Name: 
// Module Name: sign_extend
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: Sign extension module. Take 12-bit long bits stream and use its
//              MSB to decide which sign occupies higher bits of 32-bit output.
// 
// Dependencies: rv32i_params.vh
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "../include/rv32i_params.vh"


module sign_extend(
    input  wire [24:0]            src, // span [24:0] for covering with the same hardware: I-Type, S-Type and U-Type instructions with immediate fields
                                       // occupying different parts of an instruction
    input  wire [2:0]             imm_src,
    output reg  [`DATA_WIDTH-1:0] imm_signed
    );
    
    always @(*) begin
        case (imm_src) 
            3'b000 : imm_signed = {{20{src[24]}}, src[24:13]};                           // I-Type
            3'b001 : imm_signed = {{20{src[24]}}, src[24:18], src[4:0]};                 // S-Type
            3'b010 : imm_signed = {{20{src[24]}}, src[0], src[23:18], src[4:1], 1'b0};   // B-Type
            3'b011 : imm_signed = {{12{src[24]}}, src[12:5], src[13], src[23:14], 1'b0}; // J-Type
            3'b100 : imm_signed = {src[24:5], 12'b000000000000};                         // U-Type
            default: imm_signed = 32'd0;
        endcase
    end
    
endmodule
