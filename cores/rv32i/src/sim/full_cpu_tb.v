`timescale 1ns / 1ps

`include "../include/rv32i_params.vh"
`include "../include/rv32i_control.vh"

module full_cpu_tb();

    reg clk;
    reg rst;
    reg pc_stall;

    wire [`RAM_ADDR_WIDTH-1:0] i_r_addr;
    wire                       i_r_enb;
    wire [`DATA_WIDTH-1:0]     i_r_dat;

    // connections to data RAM
    wire [`RAM_ADDR_WIDTH-1:0] d_w_addr;
    wire [`DATA_WIDTH-1:0]     d_w_dat;
    wire                       d_w_enb;
    wire [3:0]                 d_w_byte_enb;
    wire [`RAM_ADDR_WIDTH-1:0] d_r_addr;
    wire                       d_r_enb;
    wire [`DATA_WIDTH-1:0]     d_r_dat;


    // Instruction RAM
    bram32 i_mem(
        .clk(clk),
        .rst(rst),
        .w_addr(12'b0),
        .w_dat(32'b0),
        .w_enb(1'b0),
        .byte_enb(4'b0),
        .r_addr(i_r_addr),
        .r_enb(i_r_enb),
        .r_dat(i_r_dat),
        .debug_addr(12'b0)
    );
    // Data RAM
    bram32 d_mem(
        .clk(clk),
        .rst(rst),
        .w_addr(d_w_addr),
        .w_dat(d_w_dat),
        .w_enb(d_w_enb),
        .byte_enb(d_w_byte_enb),
        .r_addr(d_r_addr),
        .r_enb(d_r_enb),
        .r_dat(d_r_dat),
        .debug_addr(12'b0)
    );

    // CPU
    riscv_cpu cpu(
        .clk(clk),
        .rst(rst),
        .pc_stall(pc_stall),
        .i_r_addr(i_r_addr),
        .i_r_enb(i_r_enb),
        .i_r_dat(i_r_dat),
        .d_w_addr(d_w_addr),
        .d_w_dat(d_w_dat),
        .d_w_enb(d_w_enb),
        .d_w_byte_enb(d_w_byte_enb),
        .d_r_addr(d_r_addr),
        .d_r_enb(d_r_enb),
        .d_r_dat(d_r_dat)
    );

    task automatic display_results;
        begin
            $display("Time=%0t | pc=%h |\n instr=%h | op=%b | r_reg=%b |\n rs1_addr=%h | rs2_addr=%h |\n rs1=%h | rs2=%h |\n d_bram_out=%h",
                     $time,
                     cpu.pc_out,
                     cpu.instruction,
                     cpu.opcode,
                     cpu.rd_enbl,
                     cpu.rs1_addr,
                     cpu.rs2_addr,
                     cpu.rs1,
                     cpu.rs2,
                     cpu.data_bram_output);
        end
    endtask

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    integer inst_numb;
    integer data_numb;
    integer i_inst;
    integer i_data;
    initial begin
        $dumpfile("full_cpu_tb.vcd");
        $dumpvars(0, full_cpu_tb);


        inst_numb = 16;
        data_numb = 3;

        // Reset
        rst              = 1'b1;
        pc_stall         = 1'b1;
        // i_w_addr         = 10'b0;
        // i_w_dat          = 32'h0;
        // i_w_enb          = 1'b0;
        // i_r_enb          = 1'b0;
        // d_w_addr         = 10'h0;
        // d_w_dat          = 32'h0;
        // d_w_enb          = 1'b0;
        // rd_enbl          = 1'b0;
        // wrt_dat          = 32'h0;
        // d_bram_init_done = 1'b0;
        #10;

        // Loading data into data BRAM
        $readmemh({`RISCV_PROGRAMS, "b_type/bltu_bge_bgeu_instructions_test_data.hex"}, d_mem.mem);
        // Loading program into instruction BRAM
        $readmemh({`RISCV_PROGRAMS, "b_type/bltu_bge_bgeu_instructions_test.new.hex"}, i_mem.mem);

        // De-assert reset and initialize data BRAM
        rst = 1'b0;
        #10;

        // Execute program
        $display("Executing program...");
        // rd_enbl  = 1'b1;
        // i_r_enb  = 1'b1;
        pc_stall = 1'b0;
        #5;
        for (i_inst = 0; i_inst < inst_numb; i_inst = i_inst + 1) begin
            display_results();
            #10;
        end

        // Verify results
        $display("Verifying results...");
        if (cpu.REGFILE.registers[5] == 32'h00000005) begin
            $display("x5 (registers[5]) = %h, matches expected", cpu.REGFILE.registers[5]);
        end else begin
            $display("x5 (registers[5]) = %h, expected 00000005", cpu.REGFILE.registers[5]);
        end
        if (cpu.REGFILE.registers[6] == 32'hFFFFFFFF) begin
            $display("x6 (registers[6]) = %h, matches expected", cpu.REGFILE.registers[6]);
        end else begin
            $display("x6 (registers[6]) = %h, expected FFFFFFFF", cpu.REGFILE.registers[6]);
        end
        if (cpu.REGFILE.registers[7] == 32'h00000008) begin 
            $display("x7 (registers[7]) = %h, matches expected", cpu.REGFILE.registers[7]);
        end else begin
            $display("x7 (registers[7]) = %h, expected 00000008", cpu.REGFILE.registers[7]);
        end
        if (cpu.REGFILE.registers[8] == 32'h0000000A) begin 
            $display("x8 (registers[8]) = %h, matches expected", cpu.REGFILE.registers[8]);
        end else begin
            $display("x8 (registers[8]) = %h, expected 0000000A", cpu.REGFILE.registers[8]);
        end
        if (cpu.REGFILE.registers[9] == 32'h0000000C) begin 
            $display("x9 (registers[9]) = %h, matches expected", cpu.REGFILE.registers[9]);
        end else begin
            $display("x9 (registers[9]) = %h, expected 0000000C", cpu.REGFILE.registers[9]);
        end

        if (d_mem.mem[0] == 32'h00000008) begin 
            $display("mem[0x0] = %h, matches expected", d_mem.mem[0]);
        end else begin
            $display("mem[0x0] = %h, expected 00000008", d_mem.mem[0]);
        end
        if (d_mem.mem[1] == 32'h0000000A) begin 
            $display("mem[0x4] = %h, matches expected", d_mem.mem[1]);
        end else begin
            $display("mem[0x4] = %h, expected 0000000A", d_mem.mem[1]);
        end
        if (d_mem.mem[2] == 32'h0000000C) begin 
            $display("mem[0x8] = %h, matches expected", d_mem.mem[2]);
        end else begin
            $display("mem[0x8] = %h, expected 0000000C", d_mem.mem[2]);
        end

        $display("All tests completed");
        $finish;
    end

endmodule
