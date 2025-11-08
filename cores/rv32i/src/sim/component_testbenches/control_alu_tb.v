`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
// 
// Create Date: 06/14/2025 06:39:48 PM
// Design Name: 
// Module Name: control_alu_tb
// Project Name: rv32i_sc
// Target Devices: Zyboo Z7-20
// Tool Versions: 
// Description: Testbench integrating control module with ALU
// 
// Dependencies: rv32i_params.vh, rv32i_control.vh
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "../../include/rv32i_params.vh"
`include "../../include/rv32i_control.vh"


module control_alu_tb(

    );
    
    // Control inputs
    reg [`OPCODE_WIDTH-1:0]  opcode;
    // Currently no implementation provided for both func3 and func7
    // reg [`FUNC3_WIDTH-1:0]   func3;
    // reg [`FUNC7_WIDTH-1:0]   func7
    
    // Control outputs
    wire       branch;
    wire       mem_read;
    wire       mem_2_reg;
    wire [3:0] alu_ctrl;
    wire       mem_write;
    wire       alu_src;
    wire       reg_write;
    
    // Sign extend inputs
    reg [11:0] imm_src;
    
    // Sign extend outputs
    wire [`DATA_WIDTH-1:0] src_sign_ext;
    
    // ALU inputs
    // alu_ctrl provided by control module
    // alu_src provided by control module
    reg [`INSTR_WIDTH-1:0] src1;
    reg [`INSTR_WIDTH-1:0] src2;
    
    // ALU outputs
    wire [`INSTR_WIDTH-1:0] alu_results;
    
    control CONTROL_uut(
        .opcode(opcode),
        .func3(),
        .func7(),
        .branch(branch),
        .mem_read(mem_read),
        .mem_2_reg(mem_2_reg),
        .alu_ctrl(alu_ctrl),
        .mem_write(mem_write),
        .alu_src(alu_src),
        .reg_write(reg_write)
    );
    
    sign_extend SIGN_EXTENSION_uut(
        .src(imm_src),
        .imm_signed(src_sign_ext)
    );
    
    alu ALU_uut(
        .alu_ctrl(alu_ctrl),
        .alu_src(alu_src),
        .src1(src1),
        .src2(src2),
        .sign_ext(src_sign_ext),
        .results(alu_results),
        .zero()
    );
    
    task display_results;
        begin
            $display("Time=%0t | ctrl=%b | src=%b | src1=%h | src2=%h \n| sign_ext=%b \n| results=%h",
                     $time,
                     alu_ctrl,
                     alu_src,
                     src1,
                     src2,
                     src_sign_ext,
                     alu_results);
        end
    endtask
    
    initial begin
        // Initialize signals
        opcode = 7'b1111111;
        src1 = 32'h0;
        src2 = 32'h0;
        imm_src = 12'h0;

        // Test 1: Reset state
        #10;
        display_results();
        if (alu_results == 32'h0) begin
            $display("Test 1.1 PASSED");
        end else begin
            $display("Test 1.1 FAILED: expected %h, got %h", 32'h0, alu_results);
        end
        if (branch == 1'b0) begin
            $display("Test 1.2 PASSED");
        end else begin
            $display("Test 1.2 FAILED: expected %b, got %b", 1'b0, branch);
        end
        if (mem_read == 1'b0) begin
            $display("Test 1.3 PASSED");
        end else begin
            $display("Test 1.3 FAILED: expected %b, got %b", 1'b0, mem_read);
        end
        if (mem_2_reg == 1'b0) begin
            $display("Test 1.4 PASSED");
        end else begin
            $display("Test 1.4 FAILED: expected %b, got %b", 1'b0, mem_2_reg);
        end
        if (mem_write == 1'b0) begin
            $display("Test 1.5 PASSED");
        end else begin
            $display("Test 1.5 FAILED: expected %b, got %b", 1'b0, mem_write);
        end
        if (alu_src == 1'b0) begin
            $display("Test 1.6 PASSED");
        end else begin
            $display("Test 1.6 FAILED: expected %b, got %b", 1'b0, alu_src);
        end
        if (reg_write == 1'b0) begin
            $display("Test 1.7 PASSED");
        end else begin
            $display("Test 1.7 FAILED: expected %b, got %b", 1'b0, reg_write);
        end

        // Test 2: Sign extension with positive immediate
        #10;
        imm_src  = 12'h07ff;            // +2047
        opcode = `OPCODE_LOAD;
        src1     = 32'h1000;           // Base address
        #10;
        display_results();
        if (alu_results == (32'h1000 + {{20{imm_src[11]}}, imm_src})) begin
            $display("Test 2.1 PASSED");
        end else begin
            $display("Test 2.1 FAILED: expected %h, got %h", (32'h1000 + {{20{imm_src[11]}}, imm_src}), alu_results);
        end
        if (branch == 1'b0) begin
            $display("Test 2.2 PASSED");
        end else begin
            $display("Test 2.2 FAILED: expected %b, got %b", 1'b0, branch);
        end
        if (mem_read == 1'b1) begin
            $display("Test 2.3 PASSED");
        end else begin
            $display("Test 2.3 FAILED: expected %b, got %b", 1'b0, mem_read);
        end
        if (mem_2_reg == 1'b1) begin
            $display("Test 2.4 PASSED");
        end else begin
            $display("Test 2.4 FAILED: expected %b, got %b", 1'b0, mem_2_reg);
        end
        if (mem_write == 1'b0) begin
            $display("Test 2.5 PASSED");
        end else begin
            $display("Test 2.5 FAILED: expected %b, got %b", 1'b0, mem_write);
        end
        if (alu_src == 1'b1) begin
            $display("Test 2.6 PASSED");
        end else begin
            $display("Test 2.6 FAILED: expected %b, got %b", 1'b0, alu_src);
        end
        if (reg_write == 1'b1) begin
            $display("Test 2.7 PASSED");
        end else begin
            $display("Test 2.7 FAILED: expected %b, got %b", 1'b0, reg_write);
        end

        // Test 3: Sign extension with negative immediate
        #10;
        imm_src = 12'hf800;     // -2048
        src1    = 32'h2000;    // Base address
        #10;
        display_results();
        if (alu_results == (32'h2000 + {{20{imm_src[11]}}, imm_src})) begin
            $display("Test 3 PASSED");
        end else begin
            $display("Test 3 FAILED: expected %h, got %h", (32'h2000 + {{20{imm_src[11]}}, imm_src}), alu_results);
        end

        $finish;
        $display("All tests completed");
    end
    
endmodule
