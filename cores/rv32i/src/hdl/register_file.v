`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
// 
// Create Date: 05/26/2025 11:21:05 PM
// Design Name: 
// Module Name: register_file
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: Register file holding 32 general use registers.
//              RISC-V is byte-addressed: in order to store 32x32-bit registers we need an array, each byte is addressed.
//              Next register begins +4 bytes w.r.t the previous one.
// 
// Dependencies: rv32i_params.vh
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "../include/rv32i_params.vh"


module register_file (
    input CLK,
    input RSTn,

    // READ
    input read_enable,
    input wire [`REG_ADDR_WIDTH-1:0] rs1_addr,
    input wire [`REG_ADDR_WIDTH-1:0] rs2_addr,
    output reg [`DATA_WIDTH-1:0] rs1,  // carries value that has been read with rs1_addr
    output reg [`DATA_WIDTH-1:0] rs2,  // carries value that has been read with rs2_addr

    // WRITE
    input wire                       write_enable,
    input wire [`REG_ADDR_WIDTH-1:0] write_addr,    // specifies which register to write to
    input wire [    `DATA_WIDTH-1:0] write_data     // value to write

);

    reg [`DATA_WIDTH-1:0] registers [1:`NUM_REGISTERS-1]; // skipping x0, which is hard-wired to 32'b0

    // WRITE: clk and rst are the control signals
    integer reg_id;
    always @(posedge CLK or negedge RSTn) begin
        if (!RSTn) begin
            // Looping only until 31st register as x0 is always 0x0
            // therefore skipping reg_id=0 (not defined in the array)
            for (reg_id = 1; reg_id < `NUM_REGISTERS; reg_id = reg_id + 1) begin
                registers[reg_id] <= 32'b0;
            end
            rs1 <= 32'h0;
            rs2 <= 32'h0;
        end else if (write_enable == 1'b1 && write_addr != 5'b0) begin
            registers[write_addr] <= write_data;
        end
    end

    always @(*) begin
        if (read_enable) begin
            // Regfile read- forwarding is broken for instructions like lw x10, 12(x10); it causes a deadlock
            // which I cannot solve for now
            rs1 = (rs1_addr == 0) ? 32'h0 : registers[rs1_addr];
            rs2 = (rs2_addr == 0) ? 32'h0 : registers[rs2_addr];
        end else begin
            rs1 = 32'h0;
            rs2 = 32'h0;
        end
    end

endmodule
