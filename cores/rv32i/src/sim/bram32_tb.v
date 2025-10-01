`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
// 
// Create Date: 06/08/2025 08:25:11 PM
// Design Name: 
// Module Name: bram32_tb
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: Testbench for instruction BRAM
// 
// Dependencies: rv32i_params.vh
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "../include/rv32i_params.vh"


module bram32_tb(

    );
    
    reg clk;
    reg rst;
    
    // Write ports inputs
    reg  [9:0]             w_addr;
    reg  [`DATA_WIDTH-1:0] w_dat;
    reg                    w_enb;
    
    // Read port inputs
    reg  [9:0]             r_addr;
    reg                    r_enb;
    
    // Outputs
    wire [`DATA_WIDTH-1:0] instruction;
    
    task display_results;
        begin
            $display("Time=%0t | w_enb=%b | r_enb=%b | w_addr=%h | r_addr=%h | instr=%h",
                     $time,
                     w_enb,
                     r_enb,
                     w_addr,
                     r_addr,
                     instruction);
        end
    endtask
    
    bram32 uut(
        .clk(clk),
        .rst(rst),
        // Write ports inputs
        .w_addr(w_addr),
        .w_dat(w_dat),
        .w_enb(w_enb),
        // Read ports inputs
        .r_addr(r_addr),
        .r_enb(r_enb),
        // Outputs
        .r_dat(instruction)
    );
    
    // Program will be stored here before loading to the BRAM
    reg [`DATA_WIDTH-1:0] init_mem [0:`I_BRAM_DEPTH-1];
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end
    
    integer inst_numb;
    integer i;
    initial begin
        inst_numb = 4;
    
        // Reset
        rst    = 1'b1;
        w_addr = 10'h0;
        w_dat  = 32'h0;
        w_enb  = 1'b0;
        r_enb  = 1'b0;
        r_addr = 32'h0;
        
        // Load .hex file into init_mem
        $readmemh("add_registers.new.hex", init_mem);
        
        // Deassert reset and initialize BRAM
        rst = 1'b0; 
        #10; 
        
        // Write .hex contents to BRAM via Port A
        for (i = 0; i < inst_numb; i = i + 1) begin 
            w_addr = i; 
            w_dat = init_mem[i];
            w_enb = 1'b1; 
            #10;           
            w_enb = 1'b0; 
            $display("Initialized address %h with instruction %h", w_addr, w_dat);
        end
        
        // Test 1: Read consecutive values of BRAM and compare to init_mem
        w_enb = 1'b0;
        r_enb = 1'b1;
        #10;
        
        for (i = 0; i < inst_numb; i = i + 1) begin
            r_addr = i;
            #10;
            display_results();
            if (instruction == init_mem[i]) begin
                $display("Test PASSED- correct memory values");
            end else begin
                $display("Test FAILED- expected instr=%h, got %h", init_mem[i], instruction);
            end
        end
    
        $display("All tests finished");
        $finish;
    end
    
endmodule
