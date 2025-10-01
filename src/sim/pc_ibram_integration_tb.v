`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
// 
// Create Date: 06/11/2025 03:53:02 PM
// Design Name: 
// Module Name: pc_ibram_integration_tb
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: Testbench for integrating PC with instruction BRAM
// 
// Dependencies: rv32i_params.vh
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "../include/rv32i_params.vh"


module pc_ibram_integration_tb(

    );
    
    // Shared inputs
    reg clk;
    reg rst;
    
    // PC inputs
    reg                     pc_stall;
    // pc_select and pc_in are right now skipped as no jump control has been implemented yet
    // while the functionality itself to jump has been tested in PC dedicated testbench
    
    // PC outputs
    wire [`DATA_WIDTH-1:0] pc_out;
    
    // BRAM inputs
    // Write ports inputs
    reg  [9:0]             w_addr;
    reg  [`DATA_WIDTH-1:0] w_dat;
    reg                    w_enb;
    
    // Read port inputs
    // reg  [9:0]             r_addr; // pc output is used instead
    reg                    r_enb;
    
    // BRAM outputs
    wire [`DATA_WIDTH-1:0] instruction;
    
    task display_results;
        begin
            $display("Time=%0t | w_enb=%b | r_enb=%b | w_addr=%h | pc=%h | instr=%h",
                     $time,
                     w_enb,
                     r_enb,
                     w_addr,
                     pc_out,
                     instruction);
        end
    endtask
    
    pc PC(
        .clk(clk),
        .rst(rst),
        .stall(pc_stall),
        .pc_select(1'b0),
        .pc_in(`BOOT_ADDR),
        .pc_out(pc_out),
        .pc_next()
    );
    
    bram32 I_MEM(
        .clk(clk),
        .rst(rst),
        // Write ports inputs
        .w_addr(w_addr),
        .w_dat(w_dat),
        .w_enb(w_enb),
        // Read ports inputs
        .r_addr(pc_out),
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
        rst       = 1'b1;
        w_addr    = 10'h0;
        w_dat     = 32'h0;
        w_enb     = 1'b0;
        r_enb     = 1'b0;
        pc_stall  = 1'b1;
        #10;
        
        // Load .hex file into init_mem
        $readmemh("add_registers.new.hex", init_mem);
        
        // Deassert reset and initialize BRAM
        rst = 1'b0; 
        #10; 
        
        // Write .hex contents to BRAM via Port A
        for (i = 0; i < inst_numb; i = i + 1) begin 
            w_addr = i * 4; // 4-byte aligned addresses (0x0, 0x4, 0x8, 0xC)
            w_dat = init_mem[i];
            w_enb = 1'b1; 
            #10;           
            w_enb = 1'b0; 
            $display("Initialized address %h with instruction %h", w_addr, w_dat);
        end
        
        // Test 1: Read instructions according to the current pc value
        w_enb    = 1'b0;
        r_enb    = 1'b1;
        pc_stall = 1'b0;
        #5;
        
        for (i = 0; i < inst_numb; i = i + 1) begin
            display_results();
            if (instruction == init_mem[i]) begin
                $display("Test PASSED- correct memory values");
            end else begin
                $display("Test FAILED- expected instr=%h, got %h", init_mem[i], instruction);
            end
            #10;
        end
    
        $display("All tests completed");
        $finish;
    end
    
endmodule
