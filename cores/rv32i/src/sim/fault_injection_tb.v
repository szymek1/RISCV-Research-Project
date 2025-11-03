`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: 
// 
// Create Date: 11/03/2025
// Design Name: 
// Module Name: fault_injection_tb
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: Comprehensive testbench for fault injection module. Tests all
//              fault injection capabilities including register file and memory
//              fault injection with various scenarios.
// 
// Dependencies: rv32i_params.vh
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "../include/rv32i_params.vh"

module fault_injection_tb();

    // Clock and reset
    reg clk;
    reg rst;
    
    // Fault injection signals
    reg        fault_enable;
    reg [31:0] fault_instruction;
    reg        fault_trigger;
    
    // Test variables
    reg [7:0]  expected_count;
    integer    test_count;
    integer    pass_count;
    
    // Fault injection outputs
    wire        regfile_fault_enable;
    wire [4:0]  regfile_target_reg;
    wire [4:0]  regfile_target_bit;
    wire        regfile_fault_type;
    wire        memory_fault_enable;
    wire [31:0] memory_target_addr;
    wire [4:0]  memory_target_bit;
    wire        memory_fault_type;
    wire        fault_active;
    wire [7:0]  fault_count;
    wire [3:0]  fault_component;

    // Instantiate the fault injection module
    fault_injection uut (
        .clk(clk),
        .rst(rst),
        .fault_enable(fault_enable),
        .fault_instruction(fault_instruction),
        .fault_trigger(fault_trigger),
        .regfile_fault_enable(regfile_fault_enable),
        .regfile_target_reg(regfile_target_reg),
        .regfile_target_bit(regfile_target_bit),
        .regfile_fault_type(regfile_fault_type),
        .memory_fault_enable(memory_fault_enable),
        .memory_target_addr(memory_target_addr),
        .memory_target_bit(memory_target_bit),
        .memory_fault_type(memory_fault_type),
        .fault_active(fault_active),
        .fault_count(fault_count),
        .fault_component(fault_component)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test stimulus
    initial begin
        $display("Starting Fault Injection Module Test");
        $display("=====================================");
        
        // Initialize
        test_count = 0;
        pass_count = 0;
        rst = 1;
        fault_enable = 0;
        fault_instruction = 32'h0;
        fault_trigger = 0;
        
        // Reset
        repeat(4) @(posedge clk);
        rst = 0;
        repeat(2) @(posedge clk);
        
        // Test 1: Register file fault injection - x5, bit 0
        $display("\n=== Test 1: Register file fault - x5, bit 0 ===");
        
        // Load fault instruction
        fault_instruction = 32'b0000_0000_00101_00000_00000000000000;
        fault_enable = 1;
        @(posedge clk);
        fault_enable = 0;
        @(posedge clk);
        
        // Trigger fault
        fault_trigger = 1;
        @(posedge clk);
        
        // Check outputs during the active cycle
        if (regfile_fault_enable && regfile_target_reg == 5'd5 && regfile_target_bit == 5'd0 && fault_active) begin
            $display("✓ PASS: Register file fault correctly triggered");
            $display("  Target register: x%d, Target bit: %d", regfile_target_reg, regfile_target_bit);
            $display("  Fault count: %d", fault_count);
            pass_count = pass_count + 1;
        end else begin
            $display("✗ FAIL: Register file fault not triggered correctly");
            $display("  Expected: reg=5, bit=0, enable=1");
            $display("  Actual: reg=%d, bit=%d, enable=%d, active=%d", regfile_target_reg, regfile_target_bit, regfile_fault_enable, fault_active);
        end
        
        fault_trigger = 0;
        @(posedge clk);
        test_count = test_count + 1;
        
        // Test 2: Register file fault injection - x15, bit 31
        $display("\n=== Test 2: Register file fault - x15, bit 31 ===");
        
        fault_instruction = 32'b0000_0000_01111_11111_00000000000000;
        fault_enable = 1;
        @(posedge clk);
        fault_enable = 0;
        @(posedge clk);
        
        fault_trigger = 1;
        @(posedge clk);
        
        if (regfile_fault_enable && regfile_target_reg == 5'd15 && regfile_target_bit == 5'd31 && fault_active) begin
            $display("✓ PASS: Register file fault x15, bit 31 correctly triggered");
            $display("  Fault count: %d", fault_count);
            pass_count = pass_count + 1;
        end else begin
            $display("✗ FAIL: Register file fault x15, bit 31 not triggered correctly");
            $display("  Actual: reg=%d, bit=%d, enable=%d, active=%d", regfile_target_reg, regfile_target_bit, regfile_fault_enable, fault_active);
        end
        
        fault_trigger = 0;
        @(posedge clk);
        test_count = test_count + 1;
        
        // Test 3: Memory fault injection - word 0, bit 8
        $display("\n=== Test 3: Memory fault - word 0, bit 8 ===");
        
        fault_instruction = 32'b0010_0000_00000_01000_00000000000000;
        fault_enable = 1;
        @(posedge clk);
        fault_enable = 0;
        @(posedge clk);
        
        fault_trigger = 1;
        @(posedge clk);
        
        if (memory_fault_enable && memory_target_addr == 32'h00000000 && memory_target_bit == 5'd8 && fault_active) begin
            $display("✓ PASS: Memory fault correctly triggered");
            $display("  Target address: 0x%h, Target bit: %d", memory_target_addr, memory_target_bit);
            $display("  Fault count: %d", fault_count);
            pass_count = pass_count + 1;
        end else begin
            $display("✗ FAIL: Memory fault not triggered correctly");
            $display("  Expected: addr=0x00000000, bit=8, enable=1");
            $display("  Actual: addr=0x%h, bit=%d, enable=%d, active=%d", memory_target_addr, memory_target_bit, memory_fault_enable, fault_active);
        end
        
        fault_trigger = 0;
        @(posedge clk);
        test_count = test_count + 1;
        
        // Test 4: Memory fault injection - word 10, bit 16
        $display("\n=== Test 4: Memory fault - word 10, bit 16 ===");
        
        fault_instruction = 32'b0010_0000_01010_10000_00000000000000;
        fault_enable = 1;
        @(posedge clk);
        fault_enable = 0;
        @(posedge clk);
        
        fault_trigger = 1;
        @(posedge clk);
        
        if (memory_fault_enable && memory_target_addr == 32'h00000028 && memory_target_bit == 5'd16 && fault_active) begin
            $display("✓ PASS: Memory fault word 10, bit 16 correctly triggered");
            $display("  Target address: 0x%h (word %d), Target bit: %d", memory_target_addr, memory_target_addr>>2, memory_target_bit);
            $display("  Fault count: %d", fault_count);
            pass_count = pass_count + 1;
        end else begin
            $display("✗ FAIL: Memory fault word 10, bit 16 not triggered correctly");
            $display("  Expected: addr=0x00000028, bit=16, enable=1");
            $display("  Actual: addr=0x%h, bit=%d, enable=%d, active=%d", memory_target_addr, memory_target_bit, memory_fault_enable, fault_active);
        end
        
        fault_trigger = 0;
        @(posedge clk);
        test_count = test_count + 1;
        
        // Test 5: Invalid component test
        $display("\n=== Test 5: Invalid component test ===");
        fault_instruction = 32'b1111_0000_00101_00000_00000000000000;
        fault_enable = 1;
        @(posedge clk);
        fault_enable = 0;
        @(posedge clk);
        
        fault_trigger = 1;
        @(posedge clk);
        
        if (!regfile_fault_enable && !memory_fault_enable && fault_component == 4'hF && fault_active) begin
            $display("✓ PASS: Invalid component correctly ignored");
            $display("  Fault component: 0x%h", fault_component);
            pass_count = pass_count + 1;
        end else begin
            $display("✗ FAIL: Invalid component not handled correctly");
            $display("  regfile_enable=%d, memory_enable=%d, component=0x%h, active=%d", 
                     regfile_fault_enable, memory_fault_enable, fault_component, fault_active);
        end
        
        fault_trigger = 0;
        @(posedge clk);
        test_count = test_count + 1;
        
        // Test 6: Fault count verification
        $display("\n=== Test 6: Fault count verification ===");
        expected_count = fault_count;
        
        fault_instruction = 32'b0000_0000_00001_00001_00000000000000; // x1, bit 1
        fault_enable = 1;
        @(posedge clk);
        fault_enable = 0;
        @(posedge clk);
        
        fault_trigger = 1;
        @(posedge clk);
        fault_trigger = 0;
        @(posedge clk);
        
        expected_count = expected_count + 1;
        if (fault_count == expected_count) begin
            $display("✓ PASS: Fault count correctly incremented to %d", fault_count);
            pass_count = pass_count + 1;
        end else begin
            $display("✗ FAIL: Fault count incorrect. Expected: %d, Actual: %d", expected_count, fault_count);
        end
        test_count = test_count + 1;
        
        // Test 7: Reset test
        $display("\n=== Test 7: Reset test ===");
        rst = 1;
        repeat(4) @(posedge clk);
        rst = 0;
        @(posedge clk);
        
        if (fault_count == 0 && !regfile_fault_enable && !memory_fault_enable && !fault_active) begin
            $display("✓ PASS: Reset correctly clears all signals");
            pass_count = pass_count + 1;
        end else begin
            $display("✗ FAIL: Reset did not clear all signals correctly");
            $display("  fault_count=%d, regfile_enable=%d, memory_enable=%d, fault_active=%d", 
                     fault_count, regfile_fault_enable, memory_fault_enable, fault_active);
        end
        test_count = test_count + 1;
        
        // Test 8: Fault active signal test
        $display("\n=== Test 8: Fault active signal test ===");
        
        fault_instruction = 32'b0000_0000_00010_00010_00000000000000; // x2, bit 2
        fault_enable = 1;
        @(posedge clk);
        fault_enable = 0;
        @(posedge clk);
        
        // Check that fault_active is not set before trigger
        if (!fault_active) begin
            $display("✓ PASS: Fault active correctly low before trigger");
            pass_count = pass_count + 1;
        end else begin
            $display("✗ FAIL: Fault active should be low before trigger");
        end
        test_count = test_count + 1;
        
        fault_trigger = 1;
        @(posedge clk);
        
        // Check that fault_active is set during trigger
        if (fault_active) begin
            $display("✓ PASS: Fault active correctly high during fault execution");
            pass_count = pass_count + 1;
        end else begin
            $display("✗ FAIL: Fault active should be high during fault execution");
        end
        test_count = test_count + 1;
        
        fault_trigger = 0;
        @(posedge clk);
        
        // Check that fault_active is cleared after trigger
        if (!fault_active) begin
            $display("✓ PASS: Fault active correctly cleared after trigger");
            pass_count = pass_count + 1;
        end else begin
            $display("✗ FAIL: Fault active should be cleared after trigger");
        end
        test_count = test_count + 1;
        
        // Final summary
        $display("\n=== Test Summary ===");
        $display("Tests passed: %d/%d", pass_count, test_count);
        $display("Final fault count: %d", fault_count);
        
        if (pass_count == test_count) begin
            $display("🎉 ALL TESTS PASSED! 🎉");
        end else begin
            $display("❌ Some tests failed. Check implementation.");
        end
        
        $display("All fault injection tests completed");
        
        repeat(10) @(posedge clk);
        $finish;
    end

endmodule
