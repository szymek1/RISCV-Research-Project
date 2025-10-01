`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
// 
// Create Date: 05/27/2025 05:13:17 PM
// Design Name: 
// Module Name: pc
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: 32-bit program counter for RV32I
// 
// Dependencies: rv32i_params.vh
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "../include/rv32i_params.vh"


module pc( 
    input                         clk,
    input                         rst,
    input  wire                   stall,
    input  wire                   pc_select, // 0-> PC=PC+4 | 1-> PC=pc_in
    input  wire [`DATA_WIDTH-1:0] pc_in,     // sign_extend immediate output
    output wire [`DATA_WIDTH-1:0] pc_out,
    output wire [`DATA_WIDTH-1:0] pc_plus_4
);
    reg   [`DATA_WIDTH-1:0] curr_pc;
    wire  [`DATA_WIDTH-1:0] pc_4;      // regular +4 increment
    wire  [`DATA_WIDTH-1:0] pc_target; // branch/jump target
    reg   [`DATA_WIDTH-1:0] pc_next;   // registered next PC value

    // assign pc_target = curr_pc + pc_in;
    assign pc_target = pc_in;
    assign pc_4      = curr_pc + `PC_STEP;
    always @(posedge clk or posedge rst) begin
        if (rst == 1'b1) begin
            curr_pc <= `BOOT_ADDR;
        end else if (!rst && !stall) begin
            curr_pc <= pc_next;
        end
    end
    
    always @(*) begin
        case (pc_select)
            1'b1   : pc_next = pc_target;
            default: pc_next = pc_4;
        endcase
    end
    
    assign pc_out    = curr_pc;
    assign pc_plus_4 = pc_4;

endmodule

