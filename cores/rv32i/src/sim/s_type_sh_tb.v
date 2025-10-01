`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
// 
// Create Date: 09/27/2025
// Design Name: 
// Module Name: s_type_sh_tb
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: Testbench for store half-word (sh) instruction. It implements cpu mpdule.
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


module s_type_sh_tb(

    );
    
    reg clk;
    reg rst;
    
    // PC inputs
    reg pc_stall;
    
    // Instruction BRAM inputs
    // Write port inputs
    reg  [11:0]             i_w_addr;
    reg  [`DATA_WIDTH-1:0]  i_w_dat;
    reg                     i_w_enb;
    reg [3:0]               i_w_byte_enb;
    // Read port inputs
    reg                     i_r_enb;
    // Data BRAM inputs
    // Write port inputs
    // Later after initial loading of the memory the control for write: address, data, enable
    // will be transfered to control module
    reg  [11:0]             d_w_addr;
    reg  [`DATA_WIDTH-1:0]  d_w_dat;
    reg                     d_w_enb;
    reg  [3:0]              d_w_byte_enb;
    
    // =====   Fetch stage   =====
    wire [`DATA_WIDTH-1:0]  pc_out;
    wire [`DATA_WIDTH-1:0]  pc_plus_4; // used for returning from a jump
    wire                    branch;    // provided by control module- branch decoder
    wire [`INSTR_WIDTH-1:0] immediate; // provided by sign_extend module
    reg  [`INSTR_WIDTH-1:0] pc_plus_sec_src; // provided by sequentail block, which 
                                             // decodes second_add_src from control module

    pc PC_uut(
        .clk(clk),
        .rst(rst),
        .stall(pc_stall),
        .pc_select(branch),
        .pc_in(pc_plus_sec_src),
        .pc_out(pc_out),
        .pc_plus_4(pc_plus_4)
    );
    
    wire [`DATA_WIDTH-1:0] instruction;
    bram32 I_MEM_uut( // Instruction BRAM
        .clk(clk),
        .rst(rst),
        // Write ports inputs
        .w_addr(i_w_addr),
        .w_dat(i_w_dat),
        .w_enb(i_w_enb),
        .byte_enb(i_w_byte_enb),
        // Read ports inputs
        .r_addr(pc_out),
        .r_enb(i_r_enb),
        // Outputs
        .r_dat(instruction)
    );
    // =====   Fetch stage   =====
    // =====   Decode stage   =====
    wire                      alu_zero;
    wire                      alu_last_bit;
    wire [`OPCODE_WIDTH-1:0]  opcode;
    assign opcode =           instruction[6:0];
    
    wire [`FUNC3_WIDTH-1:0]   func3;
    assign func3 =            instruction[14:12];
    
    wire [`FUNC7_WIDTH-1:0]   func7;
    assign func7 = instruction[`DATA_WIDTH-1:25];
    
    // Control module outputs
    wire [2:0]                imm_src;
    wire                      mem_read;
    wire                      mem_2_reg;
    wire [3:0]                alu_ctrl;
    wire                      mem_write;
    wire                      alu_src;
    wire                      reg_write;
    wire [1:0]                wrt_back_src;
    wire [1:0]                second_add_src;
    
    control CONTROL_uut(
        // .clk(clk),
        .rst(rst),
        .opcode(opcode),
        .func3(func3),
        .func7(func7),
        .alu_zero(alu_zero),
        .alu_last_bit(alu_last_bit),
        .branch(branch),
        .imm_src(imm_src),
        .mem_read(mem_read),
        .mem_2_reg(mem_2_reg),
        .alu_ctrl(alu_ctrl),
        .mem_write(mem_write),
        .alu_src(alu_src),
        .reg_write(reg_write),
        .wrt_back_src(wrt_back_src),
        .second_add_src(second_add_src)
    );
    
    // Register file
    wire [`REG_ADDR_WIDTH-1:0] rs1_addr;
    assign rs1_addr =          instruction[19:15];
    
    wire [`REG_ADDR_WIDTH-1:0] rs2_addr;
    assign rs2_addr =          instruction[24:20];
    
    reg                       rd_enbl;
    
    wire [`DATA_WIDTH-1:0]     rs1;
    wire [`DATA_WIDTH-1:0]     rs2;
    
    wire [`REG_ADDR_WIDTH-1:0] wrt_addr;
    assign wrt_addr =          instruction[11:7];
    reg [`DATA_WIDTH-1:0]      wrt_dat; // connect with data memory module
    wire [`DATA_WIDTH-1:0]     data_bram_output;

    wire [`DATA_WIDTH-1:0] mem_wb_data; // from byte_reader
    wire                   mem_valid;   // from byte_reader
    reg                    wb_valid;    // has to be set high after every write back operation
    
    // Block dedicated to deciding what should be the output to write back to register file.
    // It changes accordingly to a current instruction: reading from data BRAM, register-to-tegister
    // or saving pc before the jump.
    wire [`INSTR_WIDTH-1:0]    alu_results;
    reg  [`DATA_WIDTH-1:0]     wrt_back_data;
    always @(*) begin
        case (wrt_back_src)
            `MEMORY_READ   : begin
                wrt_back_data = mem_wb_data;
                wb_valid      = mem_valid;
            end
            `ALU_RESULTS   : begin
                wrt_back_data = alu_results;
                wb_valid      = 1'b1;
            end
            `PC_PLUS_4     : begin
                wrt_back_data = pc_plus_4;
                wb_valid      = 1'b1;
            end
            `U_TYPE_SEC_SRC: begin
                wrt_back_data = pc_plus_sec_src;
                wb_valid      = 1'b1;
            end
        endcase
    end
    
    // Block dedicated U-Type instruction handling.
    // Regfile will be updated with a value either:
    // lui  : immediate 20 bits shited left by 12
    // auipc: immediate 20 bits shited left by 12 + current pc
    // jalr : sign-extended 12-bit imm12 to the register rs1
    always @(*) begin
        case (second_add_src)
            `SEC_AS_LUI  : pc_plus_sec_src = immediate;          // lui
            `SEC_AS_AUIPC: pc_plus_sec_src = pc_out + immediate; // auipc
            `SEC_AS_JALR : pc_plus_sec_src = pc_out + rs1;       // jalr
            `SEC_AS_NONE : pc_plus_sec_src = 32'b0;              // do nothing
        endcase
    end
    
    register_file REGFILE_uut(
        .clk(clk),
        .rst(rst),
        .read_enable(rd_enbl),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rs1(rs1),
        .rs2(rs2),
        .write_enable(reg_write & wb_valid),
        .write_addr(wrt_addr),
        .write_data(wrt_back_data)                      
    );
    // =====   Decode stage   =====
    // =====   Execute stage   =====
    // Sign extension
    wire [24:0]                instr_imm;
    assign instr_imm =         instruction[`INSTR_WIDTH-1:7];
    
    sign_extend SIGN_EXTENSION_uut(
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
        .zero(alu_zero),
        .res_last_bit(alu_last_bit)               
    );

    wire [3:0]             byte_enb;
    wire [`DATA_WIDTH-1:0] mem_write_data;
    load_store_decoder LOAD_STORE_DECODER(
        .alu_result_addr(alu_results),
        .func3(func3),
        .reg_read(rs2),
        .byte_enb(byte_enb),
        .data(mem_write_data)
    );

    // =====   Execute stage   =====
    // =====   Memory stage   =====
    reg d_bram_init_done;
    // Debug signals
    reg  [11:0]  debug_addr;
    wire [31:0] debug_data;
    bram32 D_MEM_uut( // Data BRAM
        .clk(clk),
        .rst(rst),
        // Write ports inputs
        // this change is required as we load the data intially through
        // the testbench
        .w_addr(d_bram_init_done   ? {alu_results[31:2], 2'b00}: d_w_addr),
        .w_dat(d_bram_init_done    ? mem_write_data            : d_w_dat),
        .w_enb(d_bram_init_done    ? mem_write                 : d_w_enb),
        .byte_enb(d_bram_init_done ? byte_enb                  : d_w_byte_enb),
        // Read ports inputs
        .r_addr(alu_results),
        .r_enb(mem_read), 
        // Outputs
        .r_dat(data_bram_output),
        // Debug read port
        .debug_addr(debug_addr),
        .debug_data(debug_data)
    );

    byte_reader BYTE_READER_uut(
        .mem_data(data_bram_output),
        .func3(func3),
        .byte_mask(byte_enb),
        .wb_data(mem_wb_data),
        .valid(mem_valid)
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
        inst_numb = 9; 
        data_numb = 8; 
        
        // Reset
        rst              = 1'b1;
        pc_stall         = 1'b1;
        i_w_addr         = 12'b0;
        i_w_dat          = 32'h0;
        i_w_enb          = 1'b0;
        i_w_byte_enb     = 4'b0000;
        i_r_enb          = 1'b0;
        d_w_addr         = 12'h0;
        d_w_dat          = 32'h0;
        d_w_enb          = 1'b0;
        d_w_byte_enb     = 4'b0000;
        rd_enbl          = 1'b0;
        wrt_dat          = 32'h0;
        d_bram_init_done = 1'b0;
        #10;
        
        // Loading data into data BRAM
        $readmemh({`RISCV_PROGRAMS, "s_type/sh_instruction_test_data.hex"}, init_mem_data);
        // Loading program into instruction BRAM
        $readmemh({`RISCV_PROGRAMS, "s_type/sh_instruction_test.new.hex"}, init_mem_instr);
        
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
            d_w_byte_enb = 4'b1111;
            #10;           
            d_w_enb = 1'b0; 
            d_w_byte_enb = 4'b1111;
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
            i_w_byte_enb = 4'b1111;
            #10;           
            i_w_enb = 1'b0; 
            i_w_byte_enb = 4'b0000;
            $display("Initialized address %h with instruction %h", i_w_addr, i_w_dat);
        end
        
        // Execute program
        $display("Executing program...");
        rd_enbl  = 1'b1;
        i_r_enb  = 1'b1;
        pc_stall = 1'b0;
        #5;
        for (i_inst = 0; i_inst < inst_numb + 4; i_inst = i_inst + 1) begin
            display_results();
            #10;
        end
        
        // Verify results
        $display("Verifying results...");
        if (REGFILE_uut.registers[5] == 32'h0000ABCD) begin
            $display("x5 (registers[5]) = %h, matches expected", REGFILE_uut.registers[5]);
        end else begin
            $display("x5 (registers[5]) = %h, expected 0x0000ABCD", REGFILE_uut.registers[5]);
        end
        if (REGFILE_uut.registers[6] == 32'h00001234) begin
            $display("x6 (registers[6]) = %h, matches expected", REGFILE_uut.registers[6]);
        end else begin
            $display("x6 (registers[6]) = %h, expected 0x00001234", REGFILE_uut.registers[6]);
        end
        if (REGFILE_uut.registers[7] == 32'h0000EF01) begin
            $display("x7 (registers[7]) = %h, matches expected", REGFILE_uut.registers[7]);
        end else begin
            $display("x7 (registers[7]) = %h, expected 0x0000EF01", REGFILE_uut.registers[7]);
        end
        debug_addr = {10'h4, 2'b00}; // 0x10
        #1;
        if (debug_data[15:0] == 16'hABCD) begin
            $display("mem[0x10:0x11] = %h, matches expected", debug_data[15:0]);
        end else begin
            $display("mem[0x10:0x11] = %h, expected 0xABCD", debug_data[15:0]);
        end
        debug_addr = {10'h4, 2'b10}; // 0x12
        #1;
        if (debug_data[31:16] == 16'h1234) begin
            $display("mem[0x12:0x13] = %h, matches expected", debug_data[31:16]);
        end else begin
            $display("mem[0x12:0x13] = %h, expected 0x1234", debug_data[31:16]);
        end
        debug_addr = {10'h5, 2'b00}; // 0x14
        #1;
        if (debug_data[15:0] == 16'hABCD) begin
            $display("mem[0x14:0x15] = %h, matches expected", debug_data[15:0]);
        end else begin
            $display("mem[0x14:0x15] = %h, expected 0xABCD", debug_data[15:0]);
        end
        debug_addr = {10'h6, 2'b00}; // 0x18
        #1;
        if (debug_data[15:0] == 16'hEF01) begin
            $display("mem[0x18:0x19] = %h, matches expected", debug_data[15:0]);
        end else begin
            $display("mem[0x18:0x19] = %h, expected 0xEF01", debug_data[15:0]);
        end
        debug_addr = {10'h7, 2'b00}; // 0x1C
        #1;
        if (debug_data == 32'h0000EF01) begin
            $display("mem[0x1C:0x1F] = %h, matches expected", debug_data);
        end else begin
            $display("mem[0x1C:0x1F] = %h, expected 0x0000EF01", debug_data);
        end
        
        $display("All tests completed");
        $finish;
    end
    
endmodule
