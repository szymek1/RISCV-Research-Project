`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
// 
// Create Date: 06/13/2025 06:19:41 PM
// Design Name: 
// Module Name: alu_sign_extend_tb
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: Testbench integrating alu module with sign extension module.
//              This testbench currently assumes that only load/store operations are
//              supported.
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


module alu_sign_extend_tb(

    );
    
    // ALU inputs
    reg  [3:0]              alu_ctrl;
    reg                     alu_src;
    reg  [`INSTR_WIDTH-1:0] src1;
    reg  [`INSTR_WIDTH-1:0] src2;
    wire [`INSTR_WIDTH-1:0] src_sign_ext; // Provided by sign_extend
    
    // ALU outputs
    wire [`INSTR_WIDTH-1:0] alu_results;
    
    // Sign extension inputs
    reg [24:0]              src;          // 25-bit source for I-type, S-type, U-type
    reg [2:0]               imm_src;      // Selector for immediate type
    
    // Sign extension outputs
    // Already included in ALU inputs

    sign_extend SIGN_EXTENSION_uut(
        .src(src),
        .imm_src(imm_src),
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
            $display("Time=%0t | ctrl=%b | src=%b | src1=%h | src2=%h \n| sign_ext=%h | imm_src=%b \n| results=%h",
                     $time,
                     alu_ctrl,
                     alu_src,
                     src1,
                     src2,
                     src_sign_ext,
                     imm_src,
                     alu_results);
        end
    endtask
    
    initial begin
        // Initialize signals
        alu_ctrl = `NOP;
        alu_src  = 1'b0;
        src1     = 32'h0;
        src2     = 32'h0;
        src      = 25'h0;
        imm_src  = 3'b111;

        // Test 1: Reset state
        #10;
        display_results();
        if (alu_results == 32'h0) begin
            $display("Test 1 PASSED: Reset state");
        end else begin
            $display("Test 1 FAILED: expected %h, got %h", 32'h0, alu_results);
        end

        // Test 2: I-type positive immediate (lw-like)
        #10;
        src      = 25'h000007ff; // I-type immediate 2047 (bits 24:13)
        imm_src  = 3'b000;       // I-type
        alu_ctrl = `ADD;
        alu_src  = 1'b1;        // Use sign_ext
        src1     = 32'h1000;    // Base address
        #10;
        display_results();
        if (alu_results == (32'h1000 + {{20{src[24]}}, src[24:13]})) begin
            $display("Test 2 PASSED: I-type positive immediate");
        end else begin
            $display("Test 2 FAILED: expected %h, got %h", (32'h1000 + {{20{src[24]}}, src[24:13]}), alu_results);
        end

        // Test 3: I-type negative immediate (lw-like)
        #10;
        src     = 25'hfff80000; // I-type immediate -2048 (bits 24:13)
        imm_src = 3'b000;       // I-type
        src1    = 32'h2000;     // Base address
        #10;
        display_results();
        if (alu_results == (32'h2000 + {{20{src[24]}}, src[24:13]})) begin
            $display("Test 3 PASSED: I-type negative immediate");
        end else begin
            $display("Test 3 FAILED: expected %h, got %h", (32'h2000 + {{20{src[24]}}, src[24:13]}), alu_results);
        end

        // Test 4: S-type positive immediate (sw-like)
        #10;
        src     = 25'h00070005; // S-type immediate 5 (bits 24:18=0, bits 4:0=5)
        imm_src = 3'b001;       // S-type
        src1    = 32'h3000;     // Base address
        #10;
        display_results();
        if (alu_results == (32'h3000 + {{20{src[24]}}, {src[24:18], src[4:0]}})) begin
            $display("Test 4 PASSED: S-type positive immediate");
        end else begin
            $display("Test 4 FAILED: expected %h, got %h", (32'h3000 + {{20{src[24]}}, {src[24:18], src[4:0]}}), alu_results);
        end

        // Test 5: S-type negative immediate (sw-like)
        #10;
        src     = 25'hff700005; // S-type immediate -5 (bits 24:18=0xff7, bits 4:0=5)
        imm_src = 3'b001;       // S-type
        src1    = 32'h4000;     // Base address
        #10;
        display_results();
        if (alu_results == (32'h4000 + {{20{src[24]}}, {src[24:18], src[4:0]}})) begin
            $display("Test 5 PASSED: S-type negative immediate");
        end else begin
            $display("Test 5 FAILED: expected %h, got %h", (32'h4000 + {{20{src[24]}}, {src[24:18], src[4:0]}}), alu_results);
        end

        // Test 6: Use regfile source (alu_src = 0)
        #10;
        alu_src = 1'b0;         // Use src2
        src2    = 32'h0fff;     // Offset from regfile
        src1    = 32'h5000;     // Base address
        #10;
        display_results();
        if (alu_results == (src1 + src2)) begin
            $display("Test 6 PASSED: Regfile source");
        end else begin
            $display("Test 6 FAILED: expected %h, got %h", (src1 + src2), alu_results);
        end

        // Test 7: Invalid control (default case)
        #10;
        alu_ctrl = `NOP;
        #10;
        display_results();
        if (alu_results == 32'h0) begin
            $display("Test 7 PASSED: Invalid control");
        end else begin
            $display("Test 7 FAILED: expected %h, got %h", 32'h0, alu_results);
        end

        #10;
        $display("All tests completed");
        $finish;
    end
    
endmodule
