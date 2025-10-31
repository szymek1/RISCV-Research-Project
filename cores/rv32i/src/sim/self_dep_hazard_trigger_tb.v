`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
// 
// Create Date: 06/18/2025 07:02:37 PM
// Design Name: 
// Module Name: self_dep_hazard_trigger_tb
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: Testbench triggering self dependency hazard like lw x10, 4(x10). It implements cpu mpdule.
// 
// Dependencies: rv32i_params.vh, rv32i_control.vh
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "../include/rv32i_params.vh"
`include "../include/rv32i_control.vh"


module self_dep_hazard_trigger_tb(

    );
    
    reg clk;
    reg rst;
    
    // PC inputs
    reg pc_stall;
    
    // Instruction BRAM inputs
    // Write port inputs
    reg  [9:0]             i_w_addr;
    reg  [`DATA_WIDTH-1:0] i_w_dat;
    reg                    i_w_enb;
    // Read port inputs
    reg                    i_r_enb;
    // Data BRAM inputs
    // Write port inputs
    // Later after initial loading of the memory the control for write: address, data, enable
    // will be transfered to control module
    reg  [9:0]             d_w_addr;
    reg  [`DATA_WIDTH-1:0] d_w_dat;
    reg                    d_w_enb;
    
    // =====   Fetch stage   =====
    wire [`DATA_WIDTH-1:0] pc_out;
    pc PC_uut(
        .clk(clk),
        .rst(rst),
        .stall(pc_stall),
        .pc_select(1'b0),
        .pc_in(`BOOT_ADDR),
        .pc_out(pc_out)
    );
    
    wire [`DATA_WIDTH-1:0] instruction;
    bram32 I_MEM_uut( // Instruction BRAM
        .clk(clk),
        .rst(rst),
        // Write ports inputs
        .w_addr(i_w_addr),
        .w_dat(i_w_dat),
        .w_enb(i_w_enb),
        // Read ports inputs
        .r_addr(pc_out),
        .r_enb(i_r_enb),
        // Outputs
        .r_dat(instruction)
    );
    
    // =====   Fetch stage   =====
    // =====   Decode stage   =====
    wire [`OPCODE_WIDTH-1:0]  opcode;
    assign opcode =           instruction[6:0];
    
    wire [`FUNC3_WIDTH-1:0]   func3;
    assign func3 =            instruction[14:12];
    
    wire [`FUNC7_WIDTH-1:0]   func7;
    assign func7 = instruction[`DATA_WIDTH-1:25];
    
    // Control module outputs
    wire                      branch;
    wire [1:0]                imm_src;
    wire                      mem_read;
    wire                      mem_2_reg;
    wire [3:0]                alu_ctrl;
    wire                      mem_write;
    wire                      alu_src;
    wire                      reg_write;
    
    control CONTROL_uut(
        // .clk(clk),
        .rst(rst),
        .opcode(opcode),
        .func3(func3),
        .func7(func7),
        .branch(branch),
        .imm_src(imm_src), 
        .mem_read(mem_read),
        .mem_2_reg(mem_2_reg),
        .alu_ctrl(alu_ctrl),
        .mem_write(mem_write),
        .alu_src(alu_src),
        .reg_write(reg_write)
    );
    
    // Register file
    wire [`REG_ADDR_WIDTH-1:0] rs1_addr;
    assign rs1_addr =          instruction[19:15];
    
    wire [`REG_ADDR_WIDTH-1:0] rs2_addr;
    assign rs2_addr =          instruction[24:20];
    
    reg                        rd_enbl;
    
    wire [`DATA_WIDTH-1:0]     rs1;
    wire [`DATA_WIDTH-1:0]     rs2;
    
    wire [`REG_ADDR_WIDTH-1:0] wrt_addr;
    assign wrt_addr =          instruction[11:7];
    reg [`DATA_WIDTH-1:0]      wrt_dat;  // Connect with data memory module
    // reg                     wrt_enbl; // Replaced in the cpu by reg_wire from control module
    wire [`DATA_WIDTH-1:0]     data_bram_output;
   
    wire [`INSTR_WIDTH-1:0]    alu_results;
    register_file REGFILE_uut(
        .clk(clk),
        .rst(rst),
        .read_enable(rd_enbl),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rs1(rs1),
        .rs2(rs2),
        .write_enable(reg_write),
        .write_addr(wrt_addr),
        .write_data(!mem_2_reg ? alu_results: data_bram_output) // Write data source is decided based on
                                                                // mem_2_reg flag which specifies whether the instruction is
                                                                // operates on registers only or utilizes data BRAM
    );
    // =====   Decode stage   =====
    // =====   Execute stage   =====
    // Sign extension
    // wire [11:0]                instr_imm;
    wire [24:0]                instr_imm;
    assign instr_imm =         instruction[`INSTR_WIDTH-1:7];
    
    wire [`INSTR_WIDTH-1:0]    immediate;
    
    sign_extend SIGN_EXTENSION(
        .src(instr_imm),
        .imm_src(imm_src),
        .imm_signed(immediate)
    );
    
    
    alu ALU_uut(
        .alu_ctrl(alu_ctrl),  // provided by control module
        .alu_src(alu_src),    // provided by control module
        .src1(rs1),           // provided by regfile
        .src2(rs2),           // provided by regfile
        .sign_ext(immediate), // provided by sign_extend
        .results(alu_results),
        .zero()               // not yet implemented
    );
    // =====   Execute stage   =====
    // =====   Memory stage   =====
    reg d_bram_init_done;
    // Debug signals
    reg  [9:0]  debug_addr;
    wire [31:0] debug_data;
    bram32 D_MEM_uut( // Data BRAM
        .clk(clk),
        .rst(rst),
        // Write ports inputs
        // this change is required as we load the data intially through
        // the testbench
        .w_addr(d_bram_init_done ? alu_results : d_w_addr),
        .w_dat(d_bram_init_done  ? rs2         : d_w_dat),
        .w_enb(d_bram_init_done  ? mem_write   : d_w_enb),
        // Read ports inputs
        .r_addr(alu_results),
        .r_enb(mem_read), 
        // Outputs
        .r_dat(data_bram_output),
        // Debug read port
        .debug_addr(debug_addr),
        .debug_data(debug_data)
    );
    // =====   Memory stage   =====
    // =================================
    // =====   Testbench related   =====
    
    task display_results;
        begin
            $display("Time=%0t | pc=%h |\n instr=%h | op=%b | r_reg=%b |\n rs1_addr=%h | rs2_addr=%h |\n rs1=%h | rs2=%h |\n d_bram_out=%h",
                     $time,
                     pc_out,
                     instruction,
                     opcode,
                     rd_enbl,
                     rs1_addr,
                     rs2_addr,
                     rs1,
                     rs2,
                     data_bram_output);
        end
    endtask
    
    // Program will be stored here before loading to the instruction BRAM
    reg [`DATA_WIDTH-1:0] init_mem_instr [0:`I_BRAM_DEPTH-1];
    
    // Data will be stored here before loading to the data BRAM
    reg [`DATA_WIDTH-1:0] init_mem_data [0:`I_BRAM_DEPTH-1];
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end
    
    integer inst_numb;
    integer data_numb;
    integer i_inst;
    integer i_data;
    initial begin
        inst_numb = 3; 
        data_numb = 10; 
        
        // Reset
        rst              = 1'b1;
        pc_stall         = 1'b1;
        i_w_addr         = 10'b0;
        i_w_dat          = 32'h0;
        i_w_enb          = 1'b0;
        i_r_enb          = 1'b0;
        d_w_addr         = 10'h0;
        d_w_dat          = 32'h0;
        d_w_enb          = 1'b0;
        rd_enbl          = 1'b0;
        wrt_dat          = 32'h0;
        d_bram_init_done = 1'b0;
        #10;
        
        // Loading data into data BRAM
        $readmemh("self_dep_test_data.hex", init_mem_data);
        // Loading program into instruction BRAM
        $readmemh("self_dep_test.new.hex", init_mem_instr);
        
        // Deassert reset and initialize data BRAM
        rst = 1'b0; 
        #10; 
        
        // Write .hex contents to data BRAM via Port A
        $display("Loading data BRAM...");
        for (i_data = 0; i_data < data_numb; i_data = i_data + 1) begin 
            d_w_addr = i_data * 4;
            // d_w_addr = i_data;
            d_w_dat = init_mem_data[i_data];
            d_w_enb = 1'b1; 
            #10;           
            d_w_enb = 1'b0; 
            $display("Initialized address %h with instruction %h", d_w_addr, d_w_dat);
        end
        
        d_bram_init_done = 1'b1; // from now one control module dictates reads and wrties to data BRAM
        #10;
        
        // Write .hex contents to data BRAM via Port A
        #10;
        $display("Loading instruction BRAM...");
        for (i_inst = 0; i_inst < inst_numb; i_inst = i_inst + 1) begin 
            i_w_addr = i_inst * 4; // 4-byte aligned addresses (0x0, 0x4, 0x8, 0xC)
            i_w_dat = init_mem_instr[i_inst];
            i_w_enb = 1'b1; 
            #10;           
            i_w_enb = 1'b0; 
            $display("Initialized address %h with instruction %h", i_w_addr, i_w_dat);
        end
        
        // Execute program
        $display("Executing program...");
        rd_enbl  = 1'b1;
        i_r_enb  = 1'b1;
        pc_stall = 1'b0;
        #5;
        for (i_inst = 0; i_inst < inst_numb; i_inst = i_inst + 1) begin
            display_results();
            #10;
        end
        
        // Verify results
        $display("Verifying results...");
        if (REGFILE_uut.registers[10] == 32'h00000014) begin
            $display("x10 (registers[10]) = %h, matches expected", REGFILE_uut.registers[10]);
        end else begin
            $display("x10 (registers[10]) = %h, expected 00000014", REGFILE_uut.registers[10]);
        end
        
        
        $display("All tests completed");
        $finish;
    end
    
endmodule
