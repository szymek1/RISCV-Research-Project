`timescale 1ns / 1ps

`include "../../include/rv32i_params.vh"

module instruction_decode_tb();

    reg [`INSTR_WIDTH-1:0] instruction;

    wire [31:0] immediate;

    instruction_decode dut (
        .instr(instruction),
        .imm(immediate)
    );

    initial begin
        // Initialize inputs
        instruction = 32'b0;

        // Test Case 1: I-Type (Positive Immediate, e.g., 0x123)
        #10;
        instruction = 32'b00010010001100000000000010010011; // addi x1, x0, 0x123
        #10;
        if (immediate !== 32'h00000123)
            $display("[ERROR] I-Type (0x123) expected 0x00000123, got 0x%h", immediate);

        // Test Case 2: I-Type (Zero Immediate)
        #10;
        instruction = 32'b00000000000000000000000010010011; // addi x1, x0, 0
        #10;
        if (immediate !== 32'h00000000)
            $display("[ERROR] I-Type (0) expected 0x00000000, got 0x%h", immediate);

        // Test Case 3: S-Type (Positive Offset, e.g., 0x123)
        #10;
        instruction = 32'b00010010001000000010000110100011; // sw x2, 0x123(x0)
        #10;
        if (immediate !== 32'h00000123)
            $display("[ERROR] S-Type (0x123) expected 0x00000123, got 0x%h", immediate);

        // Test Case 4: B-Type (Positive Offset, e.g., 0x100)
        #10;
        instruction = 32'b00010000000000000000000001100011; // beq x0, x0, 0x100
        #10;
        if (immediate !== 32'h00000100)
            $display("[ERROR] B-Type (0x100) expected 0x00000100, got 0x%h", immediate);

        // Test Case 5: J-Type (Positive Offset, e.g., 0x1000)
        #10;
        instruction = 32'b00000000000000000001000001101111; // jal x0, 0x1000
        #10;
        if (immediate !== 32'h00001000)
            $display("[ERROR] J-Type (0x1000) expected 0x00001000, got 0x%h", immediate);

        // Test Case 6: I-Type (Negative Offset, e.g., -0x100)
        #10;
        instruction = 32'b11110000000000000000000010010011; // addi x1, x0, -0x100
        #10;
        if (immediate !== -32'h100)
            $display("[ERROR] I-Type (-0x100) expected -0x100, got 0x%h", immediate);

        // Test Case 7: U-Type
        #10;
        instruction = 32'b00000000001000000000000100110111; // lui x2, 512
        #10;
        if (immediate !== 32'h200000)
            $display("[ERROR] U-Type (0x200) expected 200000, got 0x%h", immediate);

        #10;
        $display("Instruction decode testbench completed.");
        $finish;
    end

endmodule
