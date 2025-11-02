`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
// 
// Create Date: 06/19/2025 11:59:19 AM
// Design Name: 
// Module Name: sign_extend_tb
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: Testbench for sign extender module.
// 
// Dependencies: rv32i_params.vh
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "../../include/rv32i_params.vh"


module sign_extend_tb(

    );
    
    reg [`INSTR_WIDTH-1:0] instruction;
    wire [24:0] instr_imm;
    reg [2:0] imm_src;
    wire [31:0] imm_signed;
    
    // Assign instr_imm from instruction
    assign instr_imm = instruction[`INSTR_WIDTH-1:7];

    sign_extend uut (
        .src(instr_imm),
        .imm_src(imm_src),
        .imm_signed(imm_signed)
    );

    reg clk;
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end


    initial begin
        // Initialize inputs
        instruction = 32'b0;
        imm_src = 3'b0;

        // Test Case 1: I-Type (Positive Immediate, e.g., 0x123)
        #10;
        instruction = 32'b00010010001100000000000010010011; // addi x1, x0, 0x123
        imm_src     = 3'b000;                               // I-Type
        #10;
        if (imm_signed !== 32'h00000123) $display("Error: I-Type (0x123) expected 0x00000123, got 0x%h", imm_signed);

        // Test Case 2: I-Type (Zero Immediate)
        #10;
        instruction = 32'b00000000000000000000000010010011; // addi x1, x0, 0
        imm_src     = 3'b000;                               // I-Type
        #10;
        if (imm_signed !== 32'h00000000) $display("Error: I-Type (0) expected 0x00000000, got 0x%h", imm_signed);

        // Test Case 3: S-Type (Positive Offset, e.g., 0x123)
        #10;
        instruction = 32'b00010010001000000010000110100011; // sw x2, 0x123(x0)
        imm_src     = 3'b001;                               // S-Type
        #10;
        if (imm_signed !== 32'h00000123) $display("Error: S-Type (0x123) expected 0x00000123, got 0x%h", imm_signed);

        // Test Case 4: B-Type (Positive Offset, e.g., 0x100)
        #10;
        instruction = 32'b00010000000000000000000001100011; // beq x0, x0, 0x100
        imm_src     = 3'b010;                               // B-Type
        #10;
        if (imm_signed !== 32'h00000100) $display("Error: B-Type (0x100) expected 0x00000100, got 0x%h", imm_signed);

        // Test Case 5: J-Type (Positive Offset, e.g., 0x1000)
        #10;
        instruction = 32'b00000000000000000001000001101111; // jal x0, 0x1000
        imm_src     = 3'b011;                               // J-Type
        #10;
        if (imm_signed !== 32'h00001000) $display("Error: J-Type (0x1000) expected 0x00001000, got 0x%h", imm_signed);

        // Test Case 6: I-Type (Negative Offset, e.g., -0x100)
        #10;
        instruction = 32'b11110000000000000000000010010011; // addi x1, x0, -0x100
        imm_src     = 3'b000;                               // I-Type
        #10;
        if (imm_signed !== -32'h100) $display("Error: I-Type (-0x100) expected -0x100, got 0x%h", imm_signed);
        
        // Test Cas 7: U-Type
        #10;
        instruction = 32'b00000000001000000000000100110111; // lui x2, 512
        imm_src     = 3'b100;
        #10;
        if (imm_signed !== 32'h200000) $display("Error: U-Type (0x200) expected 200000, got 0x%h", imm_signed);

        #10;
        $display("Sign extend testbench completed.");
        $finish;
    end

    // Monitor for real-time debugging
    initial begin
        $monitor("Time=%0t | src=%b | imm_src=%b | imm_signed=0x%h",
                 $time, instruction, imm_src, imm_signed);
    end
    
endmodule
