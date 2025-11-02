`timescale 1ns / 1ps

`include "../include/rv32i_params.vh"
`include "../include/rv32i_control.vh"

module full_cpu();

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

    string data_folder;
    reg [`DATA_WIDTH-1:0] expected_registers [1:`NUM_REGISTERS-1];
    reg [`DATA_WIDTH-1:0] expected_memory    [`RAM_SIZE_WORDS];

    // temporary variables
    reg [`DATA_WIDTH-1:0] pc_last;
    integer total_steps;
    integer reg_id;
    integer mem_addr;
    integer found_error;
    reg [`DATA_WIDTH-1:0] value;
    reg [`DATA_WIDTH-1:0] expected_value;

    initial begin
        $dumpfile("full_cpu_tb.vcd");
        $dumpvars(0, full_cpu);
        $dumpvars(0, expected_memory[0]);
        $dumpvars(0, cpu.REGFILE.registers[5]);
        $dumpvars(0, cpu.REGFILE.registers[6]);
        for (reg_id = 1 ; reg_id < `NUM_REGISTERS; reg_id = reg_id + 1) begin
            expected_registers[reg_id] = 32'b0;
        end
        for (mem_addr = 0 ; mem_addr < `RAM_SIZE_WORDS; mem_addr = mem_addr + 1) begin
            expected_memory[mem_addr] = 32'b0;
        end

        // Reset
        rst              = 1'b1;
        pc_stall         = 1'b1;
        #10;

        #10
        $value$plusargs ("data=%s", data_folder);
        $display("Loading data from %s", data_folder);
        $readmemh({data_folder, "/memory.hex"}, d_mem.mem);
        $readmemh({data_folder, "/program.hex"}, i_mem.mem);
        $readmemh({data_folder, "/expected_registers.hex"}, expected_registers);
        $readmemh({data_folder, "/expected_memory.hex"}, expected_memory);

        // De-assert reset
        rst = 1'b0;
        #10;

        // Execute program
        $display("Executing program...");
        pc_stall = 1'b0;
        #5;
        pc_last = -1;
        total_steps = 0;
        while (cpu.pc_out != pc_last && total_steps < 1000) begin
            display_results();
            pc_last = cpu.pc_out;
            total_steps = total_steps + 1;
            #10;
        end

        found_error = 0;
        if (total_steps >= 1000) begin
            $display("[ERROR] Exceeded allowed number of cycles");
            found_error = 1;
        end

        $display("Verifying results...");
        #1;
        for (reg_id = 1 ; reg_id < `NUM_REGISTERS; reg_id = reg_id + 1) begin
            value = cpu.REGFILE.registers[reg_id];
            expected_value = expected_registers[reg_id];
            if (value == expected_value) begin
                $display("[INFO]  registers[%d] = 0x%h, matches expected",
                    reg_id, value);
            end else begin
                found_error = 1;
                $display("[ERROR] registers[%d] = 0x%h, expected 0x%h",
                    reg_id, value, expected_value);
            end
        end
        for (mem_addr = 0 ; mem_addr < `RAM_SIZE_WORDS; mem_addr = mem_addr + 1) begin
            value = d_mem.mem[mem_addr];
            expected_value = expected_memory[mem_addr];
            if (value == expected_value) begin
                // only print unexpected values since memory is quite large
                // $display("[INFO]  mem[0x%h] = 0x%h, matches expected",
                //     mem_addr * `BYTES_PER_WORD, value);
            end else begin
                found_error = 1;
                $display("[ERROR] mem[0x%h] = 0x%h, expected 0x%h",
                    mem_addr * `BYTES_PER_WORD, value, expected_value);
            end
        end

        if (found_error == 0) begin
            $display("No error found");
        end else begin
            $display("Found errors (see output above)");
        end

        $display("All tests completed");
        $finish;
    end

endmodule
