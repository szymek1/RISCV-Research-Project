`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ISAE
// Engineer: Szymon Bogus
// 
// Create Date: 06/14/2025 07:39:41 PM
// Design Name: 
// Module Name: riscv_cpu
// Project Name: rv32i_sc
// Target Devices: Zybo Z7-20
// Tool Versions: 
// Description: Main module assembling entire core
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


module riscv_cpu(
    input clk,
    input rst,

    input pc_stall,

    // connections to instruction RAM
    output [`RAM_ADDR_WIDTH-1:0] i_r_addr,
    output                       i_r_enb,
    input  [`DATA_WIDTH-1:0]     i_r_dat,

    // connections to data RAM
    output [`RAM_ADDR_WIDTH-1:0] d_w_addr,
    output [`DATA_WIDTH-1:0]     d_w_dat,
    output                       d_w_enb,
    output [3:0]                 d_w_byte_enb,
    output [`RAM_ADDR_WIDTH-1:0] d_r_addr,
    output                       d_r_enb,
    input  [`DATA_WIDTH-1:0]     d_r_dat,

    // connections to SOC Control Module
    output [`DATA_WIDTH-1:0]     cm_read_regfile_dat,
    input                        cm_cpu_stop,                // stops an entire core to perform read/write activity
    input                        cm_regfile_we,
    input  [`REG_ADDR_WIDTH-1:0] cm_read_write_regfile_addr, // used for both activities by the external module
    input  [`DATA_WIDTH-1:0]     cm_write_regfile_dat
);

    // =====   CPU Control   =====
    // =====   start/stop    =====
    // When the SOC Control Module wants to allow Fault Injection Module
    // to inject faults or when the SOC Control Module wants to dump the
    // register file it needs to stop the core to avoid operating on the register file
    // while the core itself is using it
    wire gated_clk;
    assign gated_clk = clk & ~cm_cpu_stop;

    // =====   Fetch stage   =====
    reg  [`DATA_WIDTH-1:0]     pc;
    wire [`DATA_WIDTH-1:0]     pc_next;
    wire [`DATA_WIDTH-1:0]     pc_plus_4;
    wire                       pc_select;
    wire [`DATA_WIDTH-1:0]     immediate;

    wire [`DATA_WIDTH-1:0]     alu_result;
    wire                       take_branch;

    wire                       is_jump;
    wire                       is_jalr;
    wire                       is_branch;

    always @(posedge gated_clk or posedge rst) begin
        if (rst == 1'b1) begin
            pc <= `BOOT_ADDR;
        end else if (!pc_stall) begin
            pc <= pc_next;
        end
    end

    assign pc_plus_4 = pc + 32'd4;
    assign pc_select = is_jump | (is_branch & take_branch);
    assign pc_next = pc_select ? (is_jalr ? rs1 : pc) + immediate : pc_plus_4;

    // instruction RAM wiring
    wire [`DATA_WIDTH-1:0]     instruction;
    assign i_r_addr          = pc[`RAM_ADDR_WIDTH-1:0];
    assign i_r_enb           = 1'b1; // always enable reading
    assign instruction       = i_r_dat;

    // =====   Fetch stage    =====
    // =====   Decode stage   =====

    // Control module outputs
    wire [1:0]                 wrt_back_src;
    wire [1:0]                 second_add_src;

    wire [`FUNC3_WIDTH-1:0]    func3;
    wire [`REG_ADDR_WIDTH-1:0] rs1_addr;
    wire [`REG_ADDR_WIDTH-1:0] rs2_addr;
    wire [`REG_ADDR_WIDTH-1:0] rd_addr;
    wire                       alu_src1_is_pc;
    wire                       alu_src2_is_imm;
    wire                       use_mem;
    wire                       mem_write;
    wire                       do_write_back;
    wire [`ALU_CTRL_WIDTH-1:0] alu_ctrl;

    instruction_decode DECODE(
        .instr(instruction),
        .func3(func3),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(rd_addr),
        .imm(immediate),
        .alu_src1_is_pc(alu_src1_is_pc),
        .alu_src2_is_imm(alu_src2_is_imm),
        .use_mem(use_mem),
        .mem_write(mem_write),
        .is_branch(is_branch),
        .is_jump(is_jump),
        .is_jalr(is_jalr),
        .do_write_back(do_write_back),
        .alu_ctrl(alu_ctrl)
    );

    // Register file

    wire [`DATA_WIDTH-1:0]     rs1;
    wire [`DATA_WIDTH-1:0]     rf_rs1_out;
    wire [`DATA_WIDTH-1:0]     rs2;

    reg  [`DATA_WIDTH-1:0]     write_back_data;

    // In case SOC Control Module wants to
    // - read register file: it will use rs1_addr and rs1 fields given cm_cpu_stop == 1
    // - write register file: it will use write_enable, write_addr, write_data fields given cm_cpu_stop == 1
    // This module is unaffected by gating done to the input clock signal as it has to operate
    // even when the rest of the clock is put to halt
    register_file REGFILE(
        .clk(clk), // this is the only module which receives the clock signal regardless cm_cpu_stop flag
        .rst(rst), 
        .read_enable(1'b1),
        .rs1_addr(!cm_cpu_stop   ? rs1_addr        : cm_read_write_regfile_addr),
        .rs2_addr(rs2_addr),
        .rs1(rf_rs1_out),
        .rs2(rs2),
        .write_enable((!cm_cpu_stop && do_write_back) || (cm_cpu_stop && cm_regfile_we)), // if CPU is supposed to freeze in the middle of ADD/LW signal 
                                                                                          // do_write_back will remain HIGH in case we only have here 
                                                                                          // do_write_back || (cm_cpu_stop && cm_regfile_we)- 
                                                                                          // this will overwrite the register that soc_control is trying to read. 
                                                                                          // The current approach makes sure to ignore do_write_back when the CPU is stopped
        .write_addr(!cm_cpu_stop ? rd_addr         : cm_read_write_regfile_addr),
        .write_data(!cm_cpu_stop ? write_back_data : cm_write_regfile_dat)
    );

    assign rs1                 = rf_rs1_out;
    assign cm_read_regfile_dat = rf_rs1_out;

    wire [`DATA_WIDTH-1:0]     mem_wb_data; // from byte_reader
    wire                       mem_valid;   // from byte_reader

    // =====   Decode stage   =====
    // =====   Execute stage   =====

    alu ALU(
        .alu_ctrl(alu_ctrl),
        .src1(alu_src1_is_pc  ? pc        : rs1),
        .src2(alu_src2_is_imm ? immediate : rs2),
        .result(alu_result),
        .take_branch(take_branch)
    );

    wire [3:0]             byte_enb;
    wire [`DATA_WIDTH-1:0] mem_write_data;
    load_store_decoder LOAD_STORE_DECODER(
        .alu_result_addr(alu_result),
        .func3(func3),
        .reg_read(rs2),
        .byte_enb(byte_enb),
        .data(mem_write_data)
    );

    // =====   Execute stage   =====
    // =====   Memory stage   =====

    // data RAM wiring
    assign d_w_addr          = {alu_result[`RAM_ADDR_WIDTH-1:2], 2'b00};
    assign d_w_dat           = mem_write_data;
    assign d_w_enb           = use_mem & mem_write;
    assign d_w_byte_enb      = byte_enb; // from load store decoder
    assign d_r_addr          = alu_result[`RAM_ADDR_WIDTH-1:0];
    assign d_r_enb           = use_mem & !mem_write;

    byte_reader BYTE_READER(
        .mem_data(d_r_dat),
        .func3(func3),
        .byte_mask(byte_enb),
        .wb_data(mem_wb_data),
        .valid(mem_valid)
    );
    // =====   Memory stage   =====
    // =====   Write back stage   =====

    assign write_back_data = is_jump ? pc_plus_4 : use_mem ? mem_wb_data : alu_result;

    // =====   Write back stage   =====

endmodule
