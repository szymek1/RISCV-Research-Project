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
// Description: testbench for program counter
// 
// Dependencies: rv32i_params.vh
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "../../include/rv32i_params.vh"


module pc_tb(

    );
    
    reg clk;
    reg rst;
    
    reg                    pc_select;
    reg                    pc_stall;
    reg  [`DATA_WIDTH-1:0] pc_in;
    wire [`DATA_WIDTH-1:0] pc_out;
    wire [`DATA_WIDTH-1:0] pc_plus_4;
    wire [`DATA_WIDTH-1:0] pc_next;
   /*
    task display_results;
        begin
            $display("Time=%0t | select=%b | pc_in=%h | pc_out=%h | pc_next=%h | stall=%b",
                     $time,
                     pc_select,
                     pc_in,
                     pc_out,
                     pc_next,
                     pc_stall);
        end
    endtask
    */
    task display_results;
        begin
            $display("Time=%0t | select=%b | pc_in=%h | pc_out=%h | pc+4=%h | stall=%b",
                     $time,
                     pc_select,
                     pc_in,
                     pc_out,
                     pc_plus_4,
                     pc_stall);
        end
    endtask
    
    pc uut(
        .clk(clk),
        .rst(rst),
        .stall(pc_stall),
        .pc_select(pc_select),
        .pc_in(pc_in),
        .pc_out(pc_out),
        .pc_plus_4(pc_plus_4)
        // .pc_next(pc_next)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // toggle clk every 5 time units
    end
    
    parameter BOOT_ADDR = `BOOT_ADDR;
    parameter PC_STEP   = `PC_STEP;
    
    integer cnt;
    initial begin
        // Reset
        rst       = 1'b1;
        pc_select = 1'b0;
        pc_in     = 32'h0;
        pc_stall  = 1'b1;

        // Test 1: Reset behavior
        #5;
        rst      = 1'b0; 
        pc_stall = 1'b0;
        display_results();

        // Test 2: Sequential increment
        #10;
        display_results();

        // Test 3: Branch from current PC (0x04) + offset 0x10 = 0x14
        pc_select = 1'b1;
        pc_in     = 32'h10;
        #10;
        pc_select = 1'b0;
        display_results();

        if (pc_out !== 32'h14)
            $display("Test 3 FAILED: PC not branched to 0x14");
        else
            $display("Test 3 PASSED: Branch successful");

        // Test 4: Check increment after branch
        #10;
        display_results();
        if (pc_out !== 32'h18)
            $display("Test 4 FAILED: PC not incremented correctly after branch");
        else
            $display("Test 4 PASSED: Increment after branch correct");

        // Test 5: Stall, check address holds
        pc_stall = 1'b1;
        #10;
        display_results();
        if (pc_out !== 32'h18)
            $display("Test 5 FAILED: PC changed during stall");
        else
            $display("Test 5 PASSED: Stall correctly implemented");
        pc_stall = 1'b0;

        // Test 6: Branch backward from 0x18 by -0x08 = 0x10
        pc_select = 1'b1;
        pc_in = -32'h08;
        #10;
        pc_select = 1'b0;
        display_results();
        if (pc_out !== 32'h10)
            $display("Test 6 FAILED: PC not branched back correctly");
        else
            $display("Test 6 PASSED: Branch backward successful");

        #10;
        display_results();

        $display("All tests completed");
        $finish;
    end
    
    
endmodule
